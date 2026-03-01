# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

source ./bender_list.tcl

# Multi-word command must be stored as a list so exec gets the right argv.
set BENDER [list $::env(HOME)/.cargo/bin/bender]

set HDL_PATH ../../rtl

set HDL_FILES [ list \
    ${HDL_PATH}/lagd_pkg.sv \
    ${HDL_PATH}/lagd_mem_cfg_pkg.sv \
    ${HDL_PATH}/memory_island/axi_to_mem_adapter.sv \
    ${HDL_PATH}/memory_island/mem_multicut.sv \
    ${HDL_PATH}/memory_island/mem_req_multicut.sv \
    ${HDL_PATH}/memory_island/mem_rsp_multicut.sv \
    ${HDL_PATH}/memory_island/memory_island_core.sv \
    ${HDL_PATH}/memory_island/memory_island_pkg.sv \
    ${HDL_PATH}/memory_island/memory_island_wrap.sv \
    ${HDL_PATH}/memory_island/tcdm_interconnect_wrap.sv \
    ${HDL_PATH}/memory_island/wide_narrow_arbiter.sv \
    ${HDL_PATH}/memory_island/wide_to_narrow_splitter.sv \
    ./src/common/axi_rand_stim_gen.sv \
    ./src/common/mem_seq_stim_gen.sv \
    ./src/common/mem_intf.sv \
    ./src/common/mem_test.sv \
    ./src/common/mem_rand_test.sv \
    ./src/tb_memory_island.sv \
]

set INCLUDE_DIRS [list \
    ../../tb/include \
    ../../rtl/include \
    ./include \
    ${HDL_PATH}/memory_island/include \
    [exec {*}$BENDER path common_cells]/include \
    [exec {*}$BENDER path axi]/include \
    [exec {*}$BENDER path common_verification]/include \
    [exec {*}$BENDER path register_interface]/include \
]


set PROJECT_ROOT [exec realpath ../../..]
if { [info exists ::env(USE_TECH_MODELS)] && $::env(USE_TECH_MODELS) == "1" } {
    set TECH_SIM_FLIST ${PROJECT_ROOT}/target/syn/tech/tsmc7ff/lagd_tech_sim_flist.tcl
    if { [file exists $TECH_SIM_FLIST] } {
        source $TECH_SIM_FLIST
    } else {
        puts "ERROR: USE_TECH_MODELS is set but tech_sim_flist.tcl not found at ${TECH_SIM_FLIST}"
        exit 1
    }
}