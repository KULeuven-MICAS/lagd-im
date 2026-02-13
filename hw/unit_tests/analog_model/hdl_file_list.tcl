# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set PROJECT_ROOT ../../..
set HDL_PATH ../../rtl

set HDL_FILES [ list \
    "${PROJECT_ROOT}/hw/tb/models/galena/galena_pkg.sv" \
    "${PROJECT_ROOT}/hw/tb/models/galena/galena.sv" \
    "./tb_analog_model.sv" \
]

set INCLUDE_DIRS [list \
    "${HDL_PATH}/include" \
]
