# This script sets the timing corners for place and route in innnovus.
# This script to be run from inside the runPNR.tcl. Check the variable values in that script.

create_library_set -name lsMax -timing [list $LIB_FOLDER/slow_vdd1v0_basicCells.lib]
create_library_set -name lsMin -timing [list $LIB_FOLDER/fast_vdd1v2_basicCells.lib]

create_rc_corner -name rcWorst -qx_tech_file "$RCTECH_FOLDER/gpdk045.tch" \
	-preRoute_res 1.2 -preRoute_cap 1.2 -preRoute_clkres 1.2 -preRoute_clkcap 1.2 \
   	-postRoute_res 1.2 -postRoute_cap 1.2 -postRoute_clkres 1.2 -postRoute_clkcap 1.2 \
	-postRoute_xcap 1.2 
create_rc_corner -name rcBest -qx_tech_file "$RCTECH_FOLDER/gpdk045.tch" \
	-preRoute_res 0.8 -preRoute_cap 0.8 -preRoute_clkres 0.8 -preRoute_clkcap 0.8 \
   	-postRoute_res 0.8 -postRoute_cap 0.8 -postRoute_clkres 0.8 -postRoute_clkcap 0.8 \
	-postRoute_xcap 0.8 

create_delay_corner -name dc_lsMax_rcWorst -library_set lsMax -rc_corner rcWorst
create_delay_corner -name dc_lsMin_rcBest -library_set lsMin -rc_corner rcBest

create_constraint_mode -name cmFunc -sdc_files [list "$SYNTH_OUT_FOLDER/${TOP_LEVEL}_${RUN_NAME}_map.sdc"]

create_analysis_view -name av_lsMax_rcWorst_cmFunc -constraint_mode cmFunc -delay_corner dc_lsMax_rcWorst
create_analysis_view -name av_lsMin_rcBest_cmFunc  -constraint_mode cmFunc -delay_corner dc_lsMin_rcBest

set_analysis_view -setup [list av_lsMax_rcWorst_cmFunc] -hold [list av_lsMin_rcBest_cmFunc]

