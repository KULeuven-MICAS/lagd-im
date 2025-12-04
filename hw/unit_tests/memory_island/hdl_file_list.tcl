# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set HDL_PATH ../../rtl

# Run bender command to get the path
set bender "pixi run .cargo/bin/bender"

set PULP_AXI [exec ${bender} path axi]
set PULP_AXI_HDL ${PULP_AXI}/src

set PULP_CLUSTER [exec ${bender} path cluster_interconnect]
set PULP_CLUSTER_HDL ${PULP_CLUSTER}/rtl/tcdm_interconnect

# TODO add dependencies
set HDL_FILES [ list \
    "${HDL_PATH}/memory_island/axi_to_mem_adapter.sv" \
    "${HDL_PATH}/memory_island/mem_req_multicut.sv" \
    "${HDL_PATH}/memory_island/mem_rsp_multicut.sv" \
    "${HDL_PATH}/memory_island/mem_multicut.sv" \
    "${HDL_PATH}/memory_island/wide_to_narrow_splitter.sv" \
    "${HDL_PATH}/memory_island/wide_narrow_arbiter.sv" \
    "${HDL_PATH}/memory_island/tcdm_interconnect.sv" \
    "${HDL_PATH}/memory_island/memory_island_pkg.sv" \
    "${HDL_PATH}/memory_island/memory_island_core.sv" \
    "${HDL_PATH}/memory_island/memory_island.sv" \
    "./tb_memory_island.sv" \
]
