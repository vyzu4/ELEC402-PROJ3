#!/bin/tcsh -f
source /CMC/scripts/synopsys.syn.2022.12.csh

set TOP_LEVEL = "multiplier_v2_800_map"

# SET TIMESTAMPS FROM THE MODELSIM SIMS

# Timestamp selected for multiplication operations
# vcd2saif -i /ubc/ece/home/ugrads/v/vzhu03/ELEC402/projects/${TOP_LEVEL}.vcd -o /ubc/ece/home/ugrads/v/vzhu03/ELEC402/foo/vcd_saif_power/outputs/${TOP_LEVEL}_mult.saif -time 57500 243900
vcd2saif -i /ubc/ece/home/ugrads/v/vzhu03/ELEC402/projects/${TOP_LEVEL}.vcd -o /ubc/ece/home/ugrads/v/vzhu03/ELEC402/foo/vcd_saif_power/outputs/${TOP_LEVEL}_mult.saif -time 21220 102480

# Timestamp selected for readout operations
# vcd2saif -i /ubc/ece/home/ugrads/v/vzhu03/ELEC402/projects/${TOP_LEVEL}.vcd -o /ubc/ece/home/ugrads/v/vzhu03/ELEC402/foo/vcd_saif_power/outputs/${TOP_LEVEL}_read.saif -time 263460 442700
vcd2saif -i /ubc/ece/home/ugrads/v/vzhu03/ELEC402/projects/${TOP_LEVEL}.vcd -o /ubc/ece/home/ugrads/v/vzhu03/ELEC402/foo/vcd_saif_power/outputs/${TOP_LEVEL}_read.saif -time 191520 275400
