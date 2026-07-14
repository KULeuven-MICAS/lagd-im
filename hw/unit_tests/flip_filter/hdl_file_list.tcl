# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set PROJECT_ROOT ../../..
set HDL_PATH ../../rtl

set HDL_FILES [ list \
    "./tb_flip_filter.sv" \
    "${HDL_PATH}/flip_filter/flip_filter.sv" \
    "${HDL_PATH}/flip_filter/dgt_raddr_manager.sv" \
    "${HDL_PATH}/flip_filter/customized_arbiter.sv" \
    "${HDL_PATH}/lib/bp_pipe.sv" \
    "${HDL_PATH}/lib/registers.svh" \
    "${HDL_PATH}/energy_monitor/step_counter.sv" \
    "[exec bender path common_cells]/src/onehot_to_bin.sv" \
    "[exec bender path common_cells]/src/popcount.sv" \
]

set INCLUDE_DIRS [list \
    "[exec bender path common_cells]/include" \
]
