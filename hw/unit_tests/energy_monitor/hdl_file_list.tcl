# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set HDL_PATH ../../rtl

set HDL_FILES [ list \
    "./tb_energy_monitor.sv" \
    "${HDL_PATH}/energy_monitor.sv" \
    "${HDL_PATH}/lib/bp_pipe.sv" \
    "${HDL_PATH}/counter_ctrl.sv" \
    "${HDL_PATH}/vector_caching.sv" \
    "${HDL_PATH}/step_counter.sv" \
    "${HDL_PATH}/logic_ctrl.sv" \
    "${HDL_PATH}/vector_mux.sv" \
    "${HDL_PATH}/partial_energy_calc.sv" \
    "${HDL_PATH}/adder_tree.sv" \
    "${HDL_PATH}/accumulator.sv" \
]
