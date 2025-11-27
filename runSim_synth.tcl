set TOP_LEVEL "dnn_accelerator"
set TB_NAME ${TOP_LEVEL}_tb

set SDF_FOLDER "/ubc/ece/home/ugrads/v/vzhu03/ELEC402/synthesis/outputs"

# Starting the simulator
vsim -default_radix unsigned -voptargs=+acc -sdfnoerror -sdfmax /$TB_NAME/$TOP_LEVEL=$SDF_FOLDER/${TOP_LEVEL}_dut.sdf -l $TB_NAME.sim.log work.${TB_NAME} 

# Open the vcd file to write the waveforms to
vcd file ${TOP_LEVEL}.vcd
# Add the signals to be logged for activity factor
vcd add /$TB_NAME/${TOP_LEVEL}/*
