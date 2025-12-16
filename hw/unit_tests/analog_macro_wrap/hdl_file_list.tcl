# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set PROJECT_ROOT ../../..
set HDL_PATH ../../rtl

set HDL_FILES [ list \
    "./tb_analog_macro_wrap.sv" \
    "${HDL_PATH}/energy_monitor/step_counter.sv" \
    "${HDL_PATH}/analog_macro_wrap/analog_macro_wrap.sv" \
    "${HDL_PATH}/analog_macro_wrap/analog_cfg.sv" \
    "${HDL_PATH}/analog_macro_wrap/analog_tx.sv" \
    "${HDL_PATH}/analog_macro_wrap/analog_rx.sv" \
]

set INCLUDE_DIRS [list \
    "${PROJECT_ROOT}/.bender/git/checkouts/common_cells-08bbccfb95b81332/include" \
]
