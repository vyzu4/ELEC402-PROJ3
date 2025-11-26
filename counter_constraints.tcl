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
if { $RUN_NAME == "v2_400" } {
	set clk_pin clk 
	set rstn_pin reset

	set clk_period 2
	set eighths [ expr $clk_period / 8.0 ]
	set sixteenths [ expr $clk_period / 16.0 ] 
	
	set inputs_no_clk_rstn [remove_from_collection [all_inputs] [get_ports "$clk_pin $rstn_pin"]]

	create_clock [get_ports $clk_pin] -name $clk_pin -period $clk_period

	set_driving_cell -lib_cell DFFX1 -input_transition_rise [expr 1 * $eighths] -input_transition_fall [expr 1 * $eighths] $inputs_no_clk_rstn [all_inputs]

	set_load [expr [load_of [get_lib_pins */NAND2X4/A]] * 4] [all_outputs]
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
