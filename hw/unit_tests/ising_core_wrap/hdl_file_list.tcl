# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

source ./bender_list.tcl

set PROJECT_ROOT ../../..
set HDL_PATH ../../rtl

set HDL_FILES [ list \
    "./tb_ising_core_wrap.sv" \
    "${HDL_PATH}/lagd_mem_cfg_pkg.sv" \
    "${HDL_PATH}/lagd_pkg.sv" \
    "${PROJECT_ROOT}/hw/tb/models/galena/galena_pkg.sv" \
    "${PROJECT_ROOT}/hw/tb/models/galena/galena.sv" \
    "${HDL_PATH}/ising_core_wrap/ising_core_wrap.sv" \
    "${HDL_PATH}/memory_island/axi_to_mem_adapter.sv" \
    "${HDL_PATH}/memory_island/mem_multicut.sv" \
    "${HDL_PATH}/memory_island/mem_req_multicut.sv" \
    "${HDL_PATH}/memory_island/mem_rsp_multicut.sv" \
    "${HDL_PATH}/memory_island/memory_island_core.sv" \
    "${HDL_PATH}/memory_island/memory_island_pkg.sv" \
    "${HDL_PATH}/memory_island/memory_island_wrap.sv" \
    "${HDL_PATH}/memory_island/tcdm_interconnect_wrap.sv" \
    "${HDL_PATH}/memory_island/wide_narrow_arbiter.sv" \
    "${HDL_PATH}/memory_island/wide_to_narrow_splitter.sv" \
    "[exec bender path common_cells]/src/onehot_to_bin.sv" \
    "[exec bender path common_cells]/src/popcount.sv" \
    "${HDL_PATH}/digital_macro/digital_macro.sv" \
    "${HDL_PATH}/digital_macro/config_spin_ctrl.sv" \
    "${HDL_PATH}/digital_macro/mem_to_handshake_fifo.sv" \
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
    "[exec bender path axi]/include" \
    "[exec bender path common_verification]/include" \
    "[exec bender path register_interface]/include" \
    "[exec bender path cluster_interconnect]/include" \
    "${HDL_PATH}/memory_island/include" \
    "${HDL_PATH}/include" \
]
