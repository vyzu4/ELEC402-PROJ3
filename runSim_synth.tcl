set TOP_LEVEL "mkMultBuff"
set TB_NAME ${TOP_LEVEL}_SYNsim_TB

set SDF_FOLDER "/ubc/ece/home/ss/grads/avilash/Projects/elec402-intro-to-vlsi/multiplier-module/syn/outputs"

# Starting the simulator
vsim -default_radix unsigned -voptargs=+acc -sdfnoerror -sdfmax /$TB_NAME/$TOP_LEVEL=$SDF_FOLDER/${TOP_LEVEL}_v0_map.sdf -l $TB_NAME.sim.log work.${TB_NAME} 

# Open the vcd file to write the waveforms to
vcd file ${TOP_LEVEL}.vcd
# Add the signals to be logged for activity factor
vcd add /$TB_NAME/${TOP_LEVEL}/*

# Add the waves to the Wave viewer
add wave -label CLK -position insertpoint sim:/$TB_NAME/$TOP_LEVEL/CLK

add wave -divider inferface_mult
add wave -label EN_mult -position insertpoint sim:/$TB_NAME/$TOP_LEVEL/EN_mult
add wave -label RDY_mult -position insertpoint sim:/$TB_NAME/$TOP_LEVEL/RDY_mult

add wave -divider interface_writeMem
add wave -label EN_writeMem -position insertpoint sim:/$TB_NAME/$TOP_LEVEL/EN_writeMem
add wave -label writeMem_addr -position insertpoint sim:/$TB_NAME/$TOP_LEVEL/writeMem_addr

add wave -divider interface_blockRead
add wave -label EN_blockRead -position insertpoint sim:/$TB_NAME/$TOP_LEVEL/EN_blockRead

add wave -divider interface_readMem
add wave -label EN_readMem -position insertpoint sim:/$TB_NAME/$TOP_LEVEL/EN_readMem
add wave -label readmem_addr -position insertpoint sim:/$TB_NAME/$TOP_LEVEL/readMem_addr

add wave -divider interface_memVal
add wave -label VALID_memVal -position insertpoint sim:/$TB_NAME/$TOP_LEVEL/VALID_memVal

#run -all
