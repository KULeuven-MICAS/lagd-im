# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set PROJECT_ROOT ../../..
set HDL_PATH ../../rtl

set HDL_FILES [ list \
    "./config_pkg.sv" \
    "./data_read_pkg.sv" \
    "./analog_format_pkg.sv" \
    "./energy_calc_pkg.sv" \
    "./tb_digital_macro.sv" \
    "[exec bender path common_cells]/src/onehot_to_bin.sv" \
    "[exec bender path common_cells]/src/popcount.sv" \
    "${HDL_PATH}/digital_macro/digital_macro.sv" \
    "${HDL_PATH}/digital_macro/mem_to_handshake_fifo.sv" \
    "${HDL_PATH}/digital_macro/config_spin_ctrl.sv" \
    "${HDL_PATH}/flip_filter/flip_filter.sv" \
    "${HDL_PATH}/flip_filter/dgt_raddr_manager.sv" \
    "${HDL_PATH}/flip_filter/customized_arbiter.sv" \
    "${HDL_PATH}/energy_monitor/energy_monitor.sv" \
    "${HDL_PATH}/lib/bp_pipe.sv" \
    "${HDL_PATH}/energy_monitor/vector_caching.sv" \
    "${HDL_PATH}/energy_monitor/step_counter.sv" \
    "${HDL_PATH}/energy_monitor/logic_ctrl.sv" \
    "${HDL_PATH}/energy_monitor/partial_energy_calc.sv" \
    "${HDL_PATH}/energy_monitor/adder_tree.sv" \
    "${HDL_PATH}/energy_monitor/accumulator.sv" \
    "${HDL_PATH}/flip_manager/flip_manager.sv" \
    "${HDL_PATH}/flip_manager/lagd_fifo_v3.sv" \
    "${HDL_PATH}/flip_manager/flip_engine.sv" \
    "${HDL_PATH}/flip_manager/energy_fifo_maintainer.sv" \
    "${HDL_PATH}/flip_manager/spin_fifo_maintainer.sv" \
    "${HDL_PATH}/analog_macro_wrap/analog_macro_wrap.sv" \
    "${HDL_PATH}/analog_macro_wrap/analog_cfg.sv" \
    "${HDL_PATH}/analog_macro_wrap/analog_tx.sv" \
    "${HDL_PATH}/analog_macro_wrap/analog_rx.sv" \
    "${HDL_PATH}/analog_macro_wrap/synchronizer.sv" \
    "${HDL_PATH}/analog_macro_wrap/analog_dt_debug.sv" \
    "${HDL_PATH}/analog_macro_wrap/analog_spin_debug.sv" \
]

set INCLUDE_DIRS [list \
    "[exec bender path common_cells]/include" \
]
