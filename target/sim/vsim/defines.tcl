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

if { [info exists ::env(DBG)] } {
    set DBG [expr { $::env(DBG) == 1 }]
    # If DBG is set, we add it to the DEFINES
    if { $DBG == 1 } {
        set DEFINES "${DEFINES} +define+DBG=1"
    }
} else {
    set DBG 0
}

set WLIB "${TEST_PATH}/work/work_${SIM_NAME}"

puts "--------------------------------------------------------------------------------"
puts "Defines loaded"
puts "TEST_PATH: ${TEST_PATH}"
puts "HDL_FILE_LIST: ${HDL_FILE_LIST}"
puts "SIM_NAME: ${SIM_NAME}"
puts "DBG: ${DBG}"
puts "DEFINES: ${DEFINES}"
puts "WLIB: ${WLIB}"
puts "--------------------------------------------------------------------------------"