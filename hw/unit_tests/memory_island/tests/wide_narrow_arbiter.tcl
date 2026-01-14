# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

source ./bender_list.tcl

# Multi-word command must be stored as a list so exec gets the right argv.
set BENDER [list pixi run $::env(HOME)/.cargo/bin/bender]

set HDL_PATH ../../rtl/memory_island

set HDL_FILES [ list \
    ../../rtl/lagd_pkg.sv \
    ./src/tb_wide_narrow_arbiter.sv \
    ${HDL_PATH}/wide_narrow_arbiter.sv \
]

# set INCLUDE_DIRS [list \
#     ../../tb/include \
#     ../../rtl/include \
#     ./include \
#     ${HDL_PATH}/include \
#     [exec {*}$BENDER path common_cells]/include \
#     [exec {*}$BENDER path axi]/include \
#     [exec {*}$BENDER path common_verification]/include \
#     [exec {*}$BENDER path register_interface]/include \
# ]

set INCLUDE_DIRS [list \
    ../../tb/include \
    ../../rtl/include \
    ./include \
    ${HDL_PATH}/include \
    [exec {*}$BENDER path axi]/include \
    [exec {*}$BENDER path register_interface]/include \
]