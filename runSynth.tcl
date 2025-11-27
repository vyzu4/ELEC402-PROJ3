# defining lib folder
set LIB_FOLDER /ubc/ece/data/cmc2/kits/GPDK45/gsclib045_all_v4.4/gsclib045/timing

# define source folder with unsynthesized sv code
set SOURCE_FOLDER /ubc/ece/home/ugrads/v/vzhu03/ELEC402/ELEC402-PROJ3

# define which run contraint to use in counter_constraints.tcl
set RUN_NAME v2_500

# tell tool (genus) where to find lib
set_db lib_search_path [concat [get_db lib_search_path] $SOURCE_FOLDER $LIB_FOLDER ]

# set active lib
set_db library "slow_vdd1v0_basicCells.lib"

# set top level module
set TOP_LEVEL dnn_accelerator

# read sv file
read_hdl -sv $SOURCE_FOLDER/${TOP_LEVEL}.sv

# convert to gate level netlist
elaborate

# checking for unresolved modules (missing libs)
check_design -unresolved

# create clk
# create_clock [get_ports {clk}] -name clk -period 1.25 -waveform {0 0.625}

# source the constraint file
# source /ubc/ece/home/ugrads/v/vzhu03/ELEC402/ELEC402-PROJ3/counter_constraints.tcl

# synthesis commands 
synthesize -to_generic -effort high
synthesize -to_mapped -effort high -no_incr
synthesize -to_mapped -effort high -incr
insert_tiehilo_cells

source /ubc/ece/home/ugrads/v/vzhu03/ELEC402/ELEC402-PROJ3/counter_constraints.tcl

# exporting output files
report_area > ./synthesis/reports/${TOP_LEVEL}_${RUN_NAME}_area.rpt
report_gates > ./synthesis/reports/${TOP_LEVEL}_${RUN_NAME}_gates.rpt
report_timing > ./synthesis/reports/${TOP_LEVEL}_${RUN_NAME}_timing.rpt
report_power > ./synthesis/reports/${TOP_LEVEL}_${RUN_NAME}_power.rpt
write_hdl -mapped > ./synthesis/outputs/${TOP_LEVEL}_${RUN_NAME}_map.sv
write_sdc > ./synthesis/outputs/${TOP_LEVEL}_${RUN_NAME}_map.sdc
write_sdf > ./synthesis/outputs/${TOP_LEVEL}_${RUN_NAME}_map.sdf
write_db -to ./synthesis/chkpts/${TOP_LEVEL}_synth_${RUN_NAME}.dat

report_qor > ./synthesis/reports/${RUN_NAME}_qor.rpt
