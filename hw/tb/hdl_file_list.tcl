# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

source ./bender_list.tcl

set HDL_PATH ./

set HDL_FILES [ list \
    ${HDL_PATH}/tb_lagd_chip.sv \
]

set PROJECT_ROOT [exec realpath ../..]

set MODELS_FLIST ${PROJECT_ROOT}/target/syn/tech/tsmc7ff/lagd_IP_models_flist.tcl
source ${MODELS_FLIST}

if { [info exists ::env(USE_TECH_MODELS)] && $::env(USE_TECH_MODELS) == "1" } {
    set TECH_SIM_FLIST ${PROJECT_ROOT}/target/syn/tech/tsmc7ff/lagd_tech_sim_flist.tcl
    if { [file exists $TECH_SIM_FLIST] } {
        source $TECH_SIM_FLIST
    } else {
        puts "ERROR: USE_TECH_MODELS is set but tech_sim_flist.tcl not found at ${TECH_SIM_FLIST}"
        exit 1
    }
}