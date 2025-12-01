set TOP_LEVEL "mkMACBuff"
set TB_NAME ${TOP_LEVEL}_PNRsim_TB

set SDF_FOLDER "FILL THIS"

# Starting the simulator
vsim -default_radix unsigned -voptargs=+acc -sdfnoerror -sdfmax /$TB_NAME/$TOP_LEVEL=$SDF_FOLDER/${TOP_LEVEL}_pnr.sdf -l $TB_NAME.sim.log work.${TB_NAME} 

# Open the vcd file to write the waveforms to
vcd file ${TOP_LEVEL}.vcd
# Add the signals to be logged for activity factor
vcd add /$TB_NAME/${TOP_LEVEL}/*

# Add the waves to the Wave viewer
add wave -label CLK -position insertpoint sim:/$TB_NAME/$TOP_LEVEL/CLK

# FILL THIS WITH WAVES TO VIEW

#run -all
