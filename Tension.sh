#!/bin/sh
#sed_anchor01
#SBATCH --output=Tension_AlP_mp-8880.out
#SBATCH --job-name=Tension_AlP_mp-8880
#SBATCH --nodes=1
##SBATCH --cpus-per-task=8
#SBATCH --partition=All  
##SBATCH --ntasks-per-node=16
##SBATCH --reservation=GPU_test
##SBATCH --exclude=node15,node19

hostname
if [ -f /opt/anaconda3/bin/activate ]; then
    
    source /opt/anaconda3/bin/activate deepmd-cpu-v3
    export LD_LIBRARY_PATH=/opt/deepmd-cpu-v3/lib:/opt/deepmd-cpu-v3/lib/deepmd_lmp:$LD_LIBRARY_PATH
    export PATH=/opt/deepmd-cpu-v3/bin:$PATH

elif [ -f /opt/miniconda3/bin/activate ]; then
    source /opt/miniconda3/bin/activate deepmd-cpu-v3
    export LD_LIBRARY_PATH=/opt/deepmd-cpu-v3/lib:/opt/deepmd-cpu-v3/lib/deepmd_lmp:$LD_LIBRARY_PATH
    export PATH=/opt/deepmd-cpu-v3/bin:$PATH
else
    echo "Error: Neither /opt/anaconda3/bin/activate nor /opt/miniconda3/bin/activate found."
    exit 1  # Exit the script if neither exists
fi

node=1
threads=$(nproc)
processors=$(nproc)
np=$(($node*$processors/$threads))

export OMP_NUM_THREADS=$processors
export TF_INTRA_OP_PARALLELISM_THREADS=$processors
#mpi could make the node shutdown, but sed in lmp_label.pl will amend it.
# echo "Done" > lmp_done.txt
mpirun -n $np lmp -in ./elasticTemplate.in
