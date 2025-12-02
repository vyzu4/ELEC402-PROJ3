# 0) Prep - a) folders to point to the synthesis outputs
set PNR_OUT_FOLDER /ubc/ece/home/ugrads/v/vzhu03/ELEC402/pnr/output/
set SYNTH_OUT_FOLDER /ubc/ece/home/ugrads/v/vzhu03/ELEC402/synthesis/outputs/

# 0) Prep - b) library timing, lef folders
set LIB_FOLDER /ubc/ece/data/cmc2/kits/GPDK45/gsclib045_all_v4.4/gsclib045/timing
set RCTECH_FOLDER /ubc/ece/data/cmc2/kits/GPDK45/gsclib045_all_v4.4/gsclib045/qrc/qx
set LEF_FOLDER /ubc/ece/data/cmc2/kits/GPDK45/gsclib045_all_v4.4/gsclib045/lef

# 0) Prep - c) specifiers for the design, versioning etc
set TOP_LEVEL "dnn_accelerator"
set RUN_NAME "v2_500"

setMultiCpuUsage -localCpu 1
setDesignMode -process 45 -node "unspecified"

#################################################################################
# 1) Design import 
set init_lef_file [list "$LEF_FOLDER/gsclib045_tech.lef" "$LEF_FOLDER/gsclib045_macro.lef"]

set init_verilog [list "$SYNTH_OUT_FOLDER/${TOP_LEVEL}_${RUN_NAME}_map.sv"]
set init_top_cell dnn_accelerator

set init_pwr_net "VDD"
set init_gnd_net "VSS"

#THIS FILE MUST BE IN SAME DIR AS INNOVUS RUN
set init_mmmc_file "MMMC.tcl" 
# set init_mmmc_file '/ubc/ece/home/ugrads/v/vzhu03/ELEC402/ELEC402-PROJ3/MMMC.tcl'

init_design

#################################################################################
# 2) Floorplanning, power distribution network, and pin placement

# 2a) Floorplanning
setFPlanMode -snapDieGrid manufacturing
setFPlanMode -snapCoreGrid manufacturing

# Floorplan -> args for -r flag -- {aspect ratio, utilization, margins on [Left Bottom Right Top]
floorPlan -site CoreSite -r 1 0.75 8 8 8 8

# 2b) connecting the global power nets to the power nets on gates/tie-hi or tie-lo
globalNetConnect VDD -type pgpin -pin VDD -instanceBasename * -hierarchicalInstance {}
globalNetConnect VDD -type tiehi -instanceBasename * -hierarchicalInstance {}
globalNetConnect VSS -type pgpin -pin VSS -instanceBasename * -hierarchicalInstance {}
globalNetConnect VSS -type tielo -instanceBasename * -hierarchicalInstance {}

# 2c) Adding the power ring
setAddRingMode -ring_target default -extend_over_row 0 -ignore_rows 0 -avoid_short 0 -skip_crossing_trunks "none" -stacked_via_top_layer "Metal11" -stacked_via_bottom_layer "Metal1" -via_using_exact_crossover_size 1 -orthogonal_only true -skip_via_on_pin {  standardcell } -skip_via_on_wire_shape {  noshape }

addRing -nets [list "VDD" "VSS"] -type core_rings -follow "core" -layer {top "Metal7" bottom "Metal7" left "Metal8" right "Metal8"} -width {top 1.8 bottom 1.8 left 1.8 right 1.8} -spacing {top 0.45 bottom 0.45 left 0.45 right 0.45} -offset {top 1.8 bottom 1.8 left 1.8 right 1.8} -center 0 -threshold 0 -jog_distance 0 -snap_wire_center_to_grid "None"

# 2d) sroute for making the horizontal power tracks
setSrouteMode -viaConnectToShape { noshape }

sroute -connect { blockPin padPin padRing corePin floatingStripe } -layerChangeRange { Metal1(1) Metal8(8) } -blockPinTarget { nearestTarget } -padPinPortConnect { allPort oneGeom } -padPinTarget { nearestTarget } -corePinTarget { firstAfterRowEnd } -floatingStripeTarget { blockring padring ring stripe ringpin blockpin followpin } -allowJogging 1 -crossoverViaLayerRange { Metal1(1) Metal11(11) } -nets { VDD VSS } -allowLayerChange 1 -blockPin useLef -targetViaLayerRange { Metal1(1) Metal11(11) }

# 2e) Adding power stripes 
setAddStripeMode -ignore_block_check false -break_at none -route_over_rows_only false -rows_without_stripes_only false -extend_to_closest_target none -stop_at_last_wire_for_area false -partial_set_thru_domain false -ignore_nondefault_domains false -trim_antenna_back_to_shape none -spacing_type edge_to_edge -spacing_from_block 0 -stripe_min_length stripe_width -stacked_via_top_layer Metal11 -stacked_via_bottom_layer Metal1 -via_using_exact_crossover_size false -split_vias false -orthogonal_only true -allow_jog { padcore_ring  block_ring } -skip_via_on_pin { standardcell } -skip_via_on_wire_shape { noshape }

addStripe -nets [list "VDD" "VSS"] -layer "Metal8" -direction vertical -width 0 -spacing 0.45 -number_of_sets 4 -start_from left -start_offset 3 -switch_layer_over_obs false -max_same_layer_jog_length 2 -padcore_ring_top_layer_limit Metal11 -padcore_ring_bottom_layer_limit Metal1 -block_ring_top_layer_limit Metal11 -block_ring_bottom_layer_limit Metal1 -use_wire_group 0 -snap_wire_center_to_grid None


# 2f) Pin placement
setPinAssignMode -pinEditInBatch true

set all_inputs [get_db [get_db ports -if .direction==in] .name]
editPin -snap MGRID -fixOverlap 1 -spreadDirection clockwise -side Left -layer 3 -spreadType range -start 0 50.0 -end 0 175 -pin $all_inputs

set all_outputs [get_db [get_db ports -if .direction==out] .name]
set memVal_outputs [get_db ports *memVal_data*]

foreach item $memVal_outputs {
	puts $item
	set idx [lsearch -exact $all_outputs [get_db $item .name]]
	if {$idx >= 0} {
		set all_outputs [lreplace $all_outputs $idx $idx]
	}
}

# NOTE: The command below spreads all the wires on the Right edge of the floorplan
#editPin -snap MGRID -fixOverlap 1 -spreadDirection clockwise -side Right -layer 3 -spreadType range -start 0 10.0 -end 0 65.0 -pin {CLK RST_N EN_blockRead EN_mult RDY_mult EN_readMem EN_writeMem writeMem_addr* memVal_data* mult_input* readMem_addr* RDY_blockRead VALID_memVal readMem_val* writeMem_val* }

editPin -snap MGRID -fixOverlap 1 -spreadDirection clockwise -side Left -layer 3 -spreadType range -start 0 2.0 -end 0 32.0 -pin {VALID_memVal memVal_data*}

editPin -snap MGRID -fixOverlap 1 -spreadDirection clockwise -side Left -layer 3 -spreadType range -start 0 34.0 -end 0 36.0 -pin {clk rst_n}

editPin -snap MGRID -fixOverlap 1 -spreadDirection clockwise -side Left -layer 3 -spreadType range -start 0 38.0 -end 0 40.0 -pin {EN_blockRead RDY_blockRead}

editPin -pinWidth 0.08 -pinDepth 0.25 -snap MGRID -fixOverlap 1 -spreadDirection counterclockwise -side Right -layer 3 -spreadType range -start 81.645 10 -end 81.645 35 -pin {EN_readMem readMem_addr* readMem_val*}

setPinAssignMode -pinEditInBatch false

# This will show pre-place timing
timeDesign -reportOnly -prePlace -slackReports -numPaths 5 -prefix "${TOP_LEVEL}_prePlace" -outDir reports
report_timing -nworst 5 > ./reports/${TOP_LEVEL}_prePlace.rpt

# Saving design after floorplanning
saveDesign chkpts/${TOP_LEVEL}_prePlace

#################################################################################
# 3) Placement

# 3a) first place opt iteration
createBasicPathGroups -expanded 

setPlaceMode -place_detail_use_check_drc true
set_dont_use [get_lib_cells *BUFX2* ] true

place_opt_design

# 3b) Fixing any overlaps on the cells and fixing fanouts

addTieHiLo -cell {TIEHI TIELO} -prefix LTIE

setOptMode -fixFanoutLoad true
optDesign -preCTS
optDesign -preCTS -incr

# This will show post-place/pre-CTS timing
timeDesign -reportOnly -preCTS -slackReports -numPaths 5 -prefix "${TOP_LEVEL}_preCTS" -outDir reports
report_timing -nworst 5 > ./reports/${TOP_LEVEL}_preCTS.rpt

# Saving design after placement
saveDesign chkpts/${TOP_LEVEL}_preCTS

#################################################################################
# 4) Clock Tree Synthesis
reset_ccopt_config

set OUTPUTS_FOLDER /ubc/ece/home/ugrads/v/vzhu03/ELEC402/synthesis/outputs

update_constraint_mode -name cmFunc -sdc_files "$OUTPUTS_FOLDER/${TOP_LEVEL}_v2_500_map.sdc"

# 4a) Setting the clock tree root, period
# NOTE: To list all ccopt_properties, use - get_ccopt_property -help *
set_ccopt_property cts_is_sdc_clock_root -pin clk true
create_ccopt_clock_tree -name clk -source clk -no_skew_group
set_ccopt_property clock_period -pin clk [lindex [get_db clocks .period] 0]

# 4b) Set params for cts
set_ccopt_property max_fanout 4
set_ccopt_property target_max_trans 0.25
set_ccopt_property buffer_cells {CLKBUFX2 CLKBUFX3 CLKBUFX4 CLKBUFX8 CLKBUFX12 CLKBUFX16}

create_route_type -name CLKRouteType -top_preferred_layer Metal7 -bottom_preferred_layer Metal4 
set_ccopt_property route_type CLKRouteType

# 4c) Skew group to balance non generated clock:CLK in timing_config:cmFunc 
create_ccopt_skew_group -name clk/cmFunc -sources clk -auto_sinks
set_ccopt_property include_source_latency -skew_group clk/cmFunc true
set_ccopt_property extracted_from_clock_name -skew_group clk/cmFunc clk
set_ccopt_property extracted_from_constraint_mode_name -skew_group clk/cmFunc cmFunc
set_ccopt_property extracted_from_delay_corners -skew_group clk/cmFunc {dc_lsMax_rcWorst dc_lsMin_rcBest}

# 4c) Check convergence and make clock tree
check_ccopt_clock_tree_convergence
ccopt_design -cts
# NOTE - Use 'report_ccopt_clock_trees' to report specifications of the clock tree.

optDesign -postCTS
optDesign -postCTS -hold 

# This will show post-CTS timing
timeDesign -reportOnly -postCTS -slackReports -numPaths 5 -prefix "${TOP_LEVEL}_postCTS" -outDir reports
timeDesign -reportOnly -postCTS -hold -slackReports -numPaths 5 -prefix "${TOP_LEVEL}_postCTS_hold" -outDir reports
report_timing -nworst 5 > ./reports/${TOP_LEVEL}_postCTS.rpt

# Saving design after CTS
saveDesign chkpts/${TOP_LEVEL}_postCTS

#################################################################################
# 5) Routing

# 5a) Initial detail route
setNanoRouteMode -routeInsertAntennaDiode 1 -routeAntennaCellName "ANTENNA"
setNanoRouteMode -routeWithTimingDriven 1 -routeWithSiDriven 1
setNanoRouteMode -drouteAutoStop 0 -drouteEndIteration 1
setNanoRouteMode -routeTopRoutingLayer 11

routeDesign -globalDetail -viaOpt -wireOpt

# 5b) optimizing for post route
setAnalysisMode -analysisType onChipVariation -cppr both
optDesign -postRoute -setup -hold 

# This will show post-route timing
timeDesign -reportOnly -postRoute -slackReports -numPaths 5 -prefix "${TOP_LEVEL}_postRoute" -outDir reports
timeDesign -reportOnly -postRoute -hold -slackReports -numPaths 5 -prefix "${TOP_LEVEL}_postRoute_hold" -outDir reports
report_timing -nworst 5 > ./reports/${TOP_LEVEL}_postRoute.rpt

# Saving design after routing
saveDesign chkpts/${TOP_LEVEL}_postRoute

return
#################################################################################
# 6) Fixing DRCs

# 6a) Making gaps 2x column by moving stdcells around
addFillerGap 0.4 -effort high
checkFiller -reportGap 0.2

# 6b) Adding filler cells
addFiller -cell {DECAP8 DECAP10} -prefix FILLER1 -doDRC -fitGap
addFiller -cell {DECAP2 DECAP3} -prefix FILLER2 -doDRC -fitGap
# NOTE - Use the deleteFiller command to remove fillers

# 6c) First ecoRoute to connect the displaced nets, then ecoRoute only to fix DRCs
ecoRoute
verify_drc
ecoRoute -fix_drc

# This will show final timing
timeDesign -reportOnly -postRoute -slackReports -numPaths 5 -prefix "${TOP_LEVEL}_final" -outDir reports
report_timing -nworst 5 > ./reports/${TOP_LEVEL}_final.rpt

# Saving design after finish
saveDesign chkpts/${TOP_LEVEL}_final

#################################################################################
# 7) Outputs

# At this point both drc and connectivity should be clean
verify_drc
verify_connectivity
checkFiller -reportGap 0.2
checkFiller -reportGap 0.4

saveNetlist "$PNR_OUT_FOLDER/${TOP_LEVEL}_pnr.v" -excludeLeafCell

timeDesign -postRoute -reportOnly
write_sdf -max_view av_lsMax_rcWorst_cmFunc -typ_view av_lsMax_rcWorst_cmFunc -recompute_delay_calc -edges noedge -splitsetuphold -remashold -splitrecrem -min_period_edges both "$PNR_OUT_FOLDER/${TOP_LEVEL}_pnr.sdf"

