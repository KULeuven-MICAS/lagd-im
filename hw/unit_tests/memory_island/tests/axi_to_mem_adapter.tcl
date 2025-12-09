# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

source ../bender_list.tcl

set HDL_PATH ../../rtl/memory_island

set HDL_FILES [ list \
    "./tb_axi_to_mem_adapter.sv" \
    "${HDL_PATH}/axi_to_mem_adapter.sv" \
]