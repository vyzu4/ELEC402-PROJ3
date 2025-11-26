# For extracting sdf we start from the finished synthesis checkpoint.
# !!! Saif file should be present.

set TOP_LEVEL "multiplier_v2_800_map"
set TB_NAME "fsm_tb"
# Read the scale/units from the .saif file.
read_saif -instance $TB_NAME/$TOP_LEVEL -scale 1 /ubc/ece/home/ugrads/v/vzhu03/ELEC402/foo/vcd_saif_power/outputs/${TOP_LEVEL}_mult.saif

report_power > /ubc/ece/home/ugrads/v/vzhu03/ELEC402/foo/vcd_saif_power/reports/${TOP_LEVEL}_${RUN_NAME}_annotated_power_mult_400.rpt

# Read the scale/units from the .saif file.
read_saif -instance $TB_NAME/$TOP_LEVEL -scale 1 /ubc/ece/home/ugrads/v/vzhu03/ELEC402/foo/vcd_saif_power/outputs/${TOP_LEVEL}_read.saif

report_power > /ubc/ece/home/ugrads/v/vzhu03/ELEC402/foo/vcd_saif_power/reports/${TOP_LEVEL}_${RUN_NAME}_annotated_power_read_400.rpt
