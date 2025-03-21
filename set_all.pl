#!/usr/bin/perl
use strict;
use warnings;
use File::Basename;
use File::Copy;
use File::Path qw(rmtree make_path);

# 設定資料夾與模板
my $structure_dir = "structure";  # 結構檔案所在目錄
my $all_dir = "all";  # 存放所有結構的資料夾
my $template_dir = ".";  # 其他模板檔案所在目錄
my $deepmd_path = "/home/jsp1/AlP/dp_train_new/dp_train/graph01/graph-compress01.pb";  # 這裡替換為您的 deepmd 模型路徑
my $rcut = 9.0;  # 這裡替換為您的 deepmd 模型的 rcut
# **如果 all/ 資料夾已存在，則刪除並重新建立**
if (-d $all_dir) {
    print "刪除舊的 $all_dir 資料夾...\n";
    rmtree($all_dir) or die "無法刪除 $all_dir: $!";
}
make_path($all_dir) or die "無法建立 $all_dir: $!";

# 獲取所有 .data 結構檔案
opendir(my $dh, $structure_dir) or die "無法開啟目錄: $!";
my @data_files = grep { /\.data$/ } readdir($dh);
closedir($dh);

# 定義要複製的模板檔案（不包含 init.mod，因為要特別處理）
my @template_files = ("displace.mod", "elasticTemplate.in", "potential.mod", "Tension.sh", "restart.equil");

foreach my $data_file (@data_files) {
    my $structure_name = basename($data_file, ".data");
    my $structure_path = "$structure_dir/$data_file";
    my $target_dir = "$all_dir/$structure_name";  # 放入 "all" 目錄內
    #get replicate values
    # Variables to store the differences
    my ($lx, $ly, $lz);

    # Use grep and process the file
    open(my $fh, '<', "$structure_dir/$data_file") or die "Cannot open file $structure_dir/$data_file: $!";
    while (my $line = <$fh>) {
        chomp($line);
        if ($line =~ /xlo xhi/) {
            $lx = (split ' ', $line)[1] - (split ' ', $line)[0]; # Calculate xhi - xlo
        }
        elsif ($line =~ /ylo yhi/) {
            $ly = (split ' ', $line)[1] - (split ' ', $line)[0]; # Calculate yhi - ylo
        }
        elsif ($line =~ /zlo zhi/) {
            $lz = (split ' ', $line)[1] - (split ' ', $line)[0]; # Calculate zhi - zlo
        }
    }
    close($fh);

    # Print the calculated values
    my $repx = int($lx/$rcut);
    my $repy = int($ly/$rcut);
    my $repz = int($lz/$rcut);
    for my $i (1..10){
        if(int($lx*$i/$rcut) >= 1.0){
            $repx = $i;
            last;
        }
    }
    for my $i (1..10){
        if(int($ly*$i/$rcut) >= 1.0){
            $repy = $i;
            last;
        }
    }
    for my $i (1..10){
        if(int($lz*$i/$rcut) >= 1.0){
            $repz = $i;
            last;
        }
    }    
   

    print "***replicate x y z for $structure_dir/$data_file\n";
    print "repx = $repx\n";
    print "repy = $repy\n";
    print "repz = $repz\n\n";
    
    # 建立新資料夾
    make_path($target_dir) unless -d $target_dir;

    # 複製 `.data` 檔案（保留 `structure` 內的原檔案）
    copy($structure_path, "$target_dir/$data_file") or die "複製 $data_file 失敗: $!";

    # 複製其他模板檔案
    foreach my $template (@template_files) {
        copy("$template_dir/$template", "$target_dir/$template") or die "複製 $template 失敗: $!";
    }

    # 讀取 `.data` 檔案的 `Masses` 區塊
    my %masses;
    open(my $dfh, "<", $structure_path) or die "無法打開 $structure_path: $!";
    my $reading_masses = 0;
    my $empty_line_seen = 0;

    while (<$dfh>) {
        chomp;
        if (/^\s*Masses\s*$/) {
            $reading_masses = 1;
            next;
        }
        if ($reading_masses && /^\s*$/) {  # 第一個空行不影響讀取
            $empty_line_seen = 1;
            next;
        }
        if ($reading_masses && $empty_line_seen && /^\s*$/) {  # 遇到第二個空行才停止
            last;
        }
        if ($reading_masses && /^\s*(\d+)\s+([\d.]+)\s+#\s*(\S+)/) {
            $masses{$1} = "$2 # $3";
        }
    }
    close($dfh);

    # 確保 `Masses` 不為空
    if (scalar keys %masses == 0) {
        die "錯誤: 在 $data_file 中找不到有效的 Masses 區塊！請檢查檔案格式。\n";
    }

    # 複製並修改 `init.mod`
    my $init_template = "$template_dir/init.mod";
    my $init_target = "$target_dir/init.mod";

    open(my $ifh, "<", $init_template) or die "無法打開 $init_template: $!";
    open(my $ofh, ">", $init_target) or die "無法寫入 $init_target: $!";
    
    my $mass_replaced = 0;
    while (<$ifh>) {
        if (/^mass\s+\d+\s+[\d.]+\s+#/) {
            if (!$mass_replaced) {
                # 替換整個 mass 設定
                foreach my $id (sort { $a <=> $b } keys %masses) {
                    print $ofh "mass $id $masses{$id}\n";
                }
                $mass_replaced = 1;  # 確保只寫入一次
            }
        } else {
            print $ofh $_;
        }
    }

    close($ifh);
    close($ofh);

    # 修改 `init.mod` 內的 `read_data` 行
    system("sed -i 's|read_data .*|read_data $data_file|' $init_target");
    system("sed -i 's|replicate .*|replicate $repx $repy $repz|' $init_target");

    # 修改 `potential.mod` 內的 `pair_style deepmd` 行
    my $potential_mod = "$target_dir/potential.mod";
    system("sed -i 's|pair_style deepmd .*|pair_style deepmd $deepmd_path|' $potential_mod");

    # 修改 `Tension.sh` 內的 `#SBATCH --output`
    my $tension_sh = "$target_dir/Tension.sh";
    system("sed -i 's|#SBATCH --output=Tension_.*\\.out|#SBATCH --output=Tension_$structure_name.out|' $tension_sh");

    # 修改 `Tension.sh` 內的 `#SBATCH --job-name`
    system("sed -i 's|#SBATCH --job-name=Tension_.*-2|#SBATCH --job-name=Tension_$structure_name|' $tension_sh");

}


print "所有結構已成功設置完成！\n";
