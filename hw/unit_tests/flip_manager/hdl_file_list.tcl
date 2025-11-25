# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set HDL_PATH ../../rtl

set HDL_FILES [ list \
    "./tb_flip_manager.sv" \
    "${HDL_PATH}/flip_manager/flip_manager.sv" \
    "${HDL_PATH}/lib/bp_pipe.sv" \
    "${HDL_PATH}/flip_manager/flip_engine.sv" \
    "${HDL_PATH}/lib/fifo_v3.sv" \
    "${HDL_PATH}/lib/registers.svh" \
    "${HDL_PATH}/flip_manager/energy_fifo_maintainer.sv" \
    "${HDL_PATH}/flip_manager/spin_fifo_maintainer.sv" \
]
