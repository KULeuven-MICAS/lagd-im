# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>
# Basic defines for simulation

if { [info exists ::env(TEST_PATH)] } {
    set TEST_PATH $::env(TEST_PATH)
} else {
    puts "ERROR: TEST_PATH not defined"
    quit
}

if { [info exists ::env(WORK_DIR)] } {
    set WORK_DIR $::env(WORK_DIR)
} else {
    set WORK_DIR "${TEST_PATH}/vsim-runs"
}

if { [info exists ::env(HDL_FILE_LIST)] } {
    set HDL_FILE_LIST $::env(HDL_FILE_LIST)
} else {
    set HDL_FILE_LIST "${TEST_PATH}/hdl_file_list.tcl"
}
if { ![file exists $HDL_FILE_LIST] } {
    puts "ERROR: HDL_FILE_LIST not defined"
    quit
}

if { [info exists ::env(SIM_NAME)] } {
    set SIM_NAME $::env(SIM_NAME)
} else {
    puts "ERROR: SIMNAME not defined"
    quit
}

if { [info exists ::env(DEFINES)] } {
    # Add +define+ prefix to each define
    # Example: SYN=0 DBG=1 becomes +define+SYN=0 +define+DBG=1
    set defs [split $::env(DEFINES)]
    set DEFINES [join [lmap def $defs { format "+define+%s" $def } ] " "]
} else {
    set DEFINES ""
}

if { [info exists ::env(VCD_FILE)] } {
    set VCD_FILE $::env(VCD_FILE)
} else {
    set VCD_FILE "${WORK_DIR}/tb_${SIM_NAME}.vcd"
}

if { [info exists ::env(DBG)] } {
    set DBG $::env(DBG)
    # If DBG is set, we add it to the DEFINES
    if { ${DBG} >= 1 } {
        set DEFINES "${DEFINES} +define+DBG=${DBG} +define+VCD_FILE=\"${VCD_FILE}\""
    }
} else {
    set DBG 0
}

if { [info exists ::env(PARAMS)] } {
    set pars [split $::env(PARAMS)]
    set PARAMS [join [lmap def $pars { format "+g+%s" $def } ] " "]
} else {
    set PARAMS ""
}

if { ![file exists ::env(VLOG_FLAGS)] } {
    set VLOG_FLAGS ""
} else {
    set VLOG_FLAGS $::env(VLOG_FLAGS)
}

if { ![file exists ::env(VOPT_ARGS)] } {
    set VOPT_ARGS ""
} else {
    set VOPT_ARGS $::env(VOPT_ARGS)
}

if { ![file exists ::env(VSIM_FLAGS)] } {
    set VSIM_FLAGS ""
} else {
    set VSIM_FLAGS $::env(VSIM_FLAGS)
}

set WLIB "${WORK_DIR}/work/work_${SIM_NAME}"

puts "--------------------------------------------------------------------------------"
puts "Defines loaded"
puts "TEST_PATH: ${TEST_PATH}"
puts "WORK_DIR: ${WORK_DIR}"
puts "HDL_FILE_LIST: ${HDL_FILE_LIST}"
puts "SIM_NAME: ${SIM_NAME}"
puts "DBG: ${DBG}"
puts "VCD_FILE: ${VCD_FILE}"
puts "DEFINES: ${DEFINES}"
puts "WLIB: ${WLIB}"
puts "VLOG_FLAGS: ${VLOG_FLAGS}"
puts "VOPT_ARGS: ${VOPT_ARGS}"
puts "VSIM_FLAGS: ${VSIM_FLAGS}"
puts "--------------------------------------------------------------------------------"