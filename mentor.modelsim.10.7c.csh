#!/usr/bin/env tcsh

if( $?CMC_HOME == 0) then
	setenv CMC_HOME /CMC
endif

source $CMC_HOME/scripts/mentor.2017.12.csh

setenv MTI_BYPASS_SC_PLATFORM_CHECK 1

# Mentor ModelSim
setenv CMC_MNT_VSIM_ARCH $CMC_MNT_ARCH2
setenv CMC_MNT_VSIM_HOME ${CMC_MNT_HOME}/modelsim.10.7c/modeltech

setenv PATH ${CMC_MNT_VSIM_HOME}/bin:${PATH}
