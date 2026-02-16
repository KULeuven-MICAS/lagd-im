# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

source ./bender_list.tcl

set HDL_PATH ./

set HDL_FILES [ list \
    ${HDL_PATH}/tb_lagd_chip.sv \
    ${HDL_PATH}/models/pomelo_pll/pomelo_pll.sv \
    ${HDL_PATH}/models/galena/galena_pkg.sv \
    ${HDL_PATH}/models/galena/galena.sv \
]

set PROJECT_ROOT [exec realpath ../..]

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
    if { [file exists $TECH_FLIST] } {
        source $TECH_FLIST
    } else {
        puts "ERROR: CHIP_LEVEL_TEST is set but tech_flist.tcl not found at ${TECH_FLIST}"
        exit 1
    }
}

set INCLUDE_DIRS [ list \
    ${PROJECT_ROOT}/hw/rtl/include \
]