# NOTE: This script can be modified for different atomic structures, 
# units, etc. See in.elastic for more info.
#

# Define the finite deformation size. Try several values of this
# variable to verify that results do not depend on it.
variable up equal 1.0e-6
 
# Define the amount of random jiggle for atoms
# This prevents atoms from staying on saddle points
variable atomjiggle equal 1.0e-5

# Uncomment one of these blocks, depending on what units
# you are using in LAMMPS and for output

# metal units, elastic constants in eV/A^3
#units		metal
#variable cfac equal 6.2414e-7
#variable cunits string eV/A^3

# metal units, elastic constants in GPa
units		metal
variable cfac equal 1.0e-4
variable cunits string GPa

# real units, elastic constants in GPa
#units		real
#variable cfac equal 1.01325e-4
#variable cunits string GPa

# Define minimization parameters
variable etol equal 0
variable ftol equal 0
variable maxiter equal 1000
variable maxeval equal 1000
variable dmax equal 1.0e-2

box tilt large
read_data out-rocksalt-V09Nb09Ta09Cr09Mo09W09C50.data
replicate 1 1 1

# Need to set mass to something, just to satisfy LAMMPS
mass 1 50.9415 # V
mass 2 92.90638 # Nb
mass 3 180.94788 # Ta
mass 4 51.9961 # Cr
mass 5 95.94 # Mo
mass 6 183.84 # W
mass 7 12.011 # C
#include scale.in
change_box all triclinic

