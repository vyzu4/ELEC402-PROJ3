# v0 constraints
if { $RUN_NAME == "v0" } {
#	create_clock [get_ports {clk}] -name clk -period 100 -waveform {0 50}
	create_clock [get_ports {clk}] -name clk -period 1.25 -waveform {0 0.625}
}

# v1 constraints
if { $RUN_NAME == "v1" } {
	create_clock [get_ports {clk}] -name clk -period 2 -waveform {0 1}
}

# v2 constraints
if { $RUN_NAME == "v2_500" } {
	set clk_pin CLK 
	set rstn_pin RST_N

	set clk_period 2
	set eighths [ expr $clk_period / 8.0 ]
	set sixteenths [ expr $clk_period / 16.0 ] 
	
	set inputs_no_clk_rstn [remove_from_collection [all_inputs] [get_ports "$clk_pin $rstn_pin"]]

	create_clock [get_ports $clk_pin] -name $clk_pin -period $clk_period

	set_driving_cell -lib_cell DFFQX1 -input_transition_rise [expr 1 * $eighths] -input_transition_fall [expr 1 * $eighths] $inputs_no_clk_rstn

	set_load [expr [load_of [get_lib_pins */NAND2X4/A]] * 4] [all_outputs]
	
	#set input and output transitions
	set_input_delay -clock CLK [expr $clk_period/4.0] $inputs_no_clk_rstn
	set_output_delay -clock CLK [expr $clk_period/4.0] [all_outputs]

	#set clock latency and uncertainties
	set_clock_latency -early -late -source 0.250 [get_ports CLK]
	set_clock_uncertainty 0.250 [get_ports CLK]

	#set max_fanout of all inputs to 4
	set_max_fanout 4.0 $inputs_no_clk_rstn

	#disable functional path through SI pins
	#set_db use_scan_seqs_for_non_dft false
	
	#prevent genus from using scan FF to save area since there are no DFT logic in the design
	set_dont_use [get_lib_cells *SDFF*] true
}

# v3 constraints 
if { $RUN_NAME == "v3" } {
	set clk_pin clk 
	set rstn_pin reset

	set clk_period 2
	set eighths [ expr $clk_period / 8.0 ]
	set sixteenths [ expr $clk_period / 16.0 ] 
	
	set inputs_no_clk_rstn [remove_from_collection [all_inputs] [get_ports "$clk_pin $rstn_pin"]]

	create_clock [get_ports $clk_pin] -name $clk_pin -period $clk_period
	
	set_driving_cell -lib_cell DFFX1 -input_transition_rise [expr 1 * $eighths] -input_transition_fall [expr 1 * $eighths] $inputs_no_clk_rstn

	set_load [expr [load_of [get_lib_pins */NAND2X4/A]] * 4] [all_outputs]

	# constraints for input -> flop, flop -> output

	create_clock -period $clk_period -name io_virtual_clk
	set_input_delay -max [ expr 6 * $eighths ] -clock io_virtual_clk -add_delay $inputs_no_clk_rstn
	set_output_delay -max [ expr 6 * $eighths ] -clock io_virtual_clk -add_delay [all_outputs]
	
	#set_false_path -from io_virtual_clk -to $clk_pin
	#set_false_path -from $clk_pin -to io_virtual_clk
}

# v4 constraints
if { $RUN_NAME == "v4" } {
	set clk_pin clk 
	set rstn_pin reset

	set clk_period 1
	set eighths [ expr $clk_period / 8.0 ]
	set sixteenths [ expr $clk_period / 16.0 ] 
	
	set inputs_no_clk_rstn [remove_from_collection [all_inputs] [get_ports "$clk_pin $rstn_pin"]]

	create_clock [get_ports $clk_pin] -name $clk_pin -period $clk_period
	
	set_driving_cell -lib_cell DFFX1 -input_transition_rise [expr 1 * $eighths] -input_transition_fall [expr 1 * $eighths] $inputs_no_clk_rstn

	set_load [expr [load_of [get_lib_pins */NAND2X4/A]] * 4] [all_outputs]

	# constraints for input -> flop, flop -> output

	create_clock -period $clk_period -name io_virtual_clk
	set_input_delay -max [ expr 6 * $eighths ] -clock io_virtual_clk -add_delay $inputs_no_clk_rstn
	set_output_delay -max [ expr 6 * $eighths ] -clock io_virtual_clk -add_delay [all_outputs]
	
	#set_false_path -from io_virtual_clk -to $clk_pin
	#set_false_path -from $clk_pin -to io_virtual_clk
}
