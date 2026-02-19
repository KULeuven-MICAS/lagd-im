# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

set PROJECT_ROOT [exec realpath ../..]
set HDL_PATH ./

if { [info exists ::env(NETLIST_PATH)] && $::env(NETLIST_PATH) ne "" } {
    puts "INFO tb/hdl_file_list.tcl: NETLIST_PATH is set to $::env(NETLIST_PATH)"
    set HDL_FILES [ list $::env(NETLIST_PATH) ]
    set BENDER_SCRIPT ./pkg_bender_list.tcl
    set SKIP_TECH_FLIST 1
} else {
    set HDL_FILES [ list ]
    set BENDER_SCRIPT ./bender_list.tcl
    set SKIP_TECH_FLIST 0
}

source ${BENDER_SCRIPT}

lappend HDL_FILES {*}[ list \
    ${HDL_PATH}/tb_lagd_chip.sv \
]

set INCLUDE_DIRS [ list \
    ${PROJECT_ROOT}/hw/rtl/include \
    ${PROJECT_ROOT}/hw/tb/include \
]

if { [info exists ::env(USE_TECH_MODELS)] && $::env(USE_TECH_MODELS) == "1" } {
    set TECH_SIM_FLIST ${PROJECT_ROOT}/target/syn/tech/tsmc7ff/lagd_tech_sim_flist.tcl
    if { [file exists $TECH_SIM_FLIST] } {
        source $TECH_SIM_FLIST
    } else {
        puts "ERROR: USE_TECH_MODELS is set but tech_sim_flist.tcl not found at ${TECH_SIM_FLIST}"
        exit 1
    }
}

if { [info exists ::env(CHIP_LEVEL_TEST)] && $::env(CHIP_LEVEL_TEST) == "1" } {
    set TECH_FLIST ${PROJECT_ROOT}/target/syn/tech/tsmc7ff/lagd_tech_flist.tcl
    if { [file exists $TECH_FLIST] && $SKIP_TECH_FLIST != 0 } {
        source $TECH_FLIST
    } else {
        puts "ERROR: CHIP_LEVEL_TEST is set but tech_flist.tcl not found at ${TECH_FLIST}"
        exit 1
    }
}
