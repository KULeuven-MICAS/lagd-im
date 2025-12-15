# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set PROJECT_ROOT ../../..
set HDL_PATH ../../rtl

set HDL_FILES [ list \
    "./tb_energy_monitor.sv" \
    "${HDL_PATH}/energy_monitor/energy_monitor.sv" \
    "${HDL_PATH}/lib/bp_pipe.sv" \
    "${HDL_PATH}/energy_monitor/vector_caching.sv" \
    "${HDL_PATH}/energy_monitor/step_counter.sv" \
    "${HDL_PATH}/energy_monitor/logic_ctrl.sv" \
    "${HDL_PATH}/energy_monitor/partial_energy_calc.sv" \
    "${HDL_PATH}/energy_monitor/adder_tree.sv" \
    "${HDL_PATH}/energy_monitor/accumulator.sv" \
]

set INCLUDE_FILES [list \
    "${PROJECT_ROOT}/.bender/git/checkouts/common_cells-08bbccfb95b81332/include" \
]
