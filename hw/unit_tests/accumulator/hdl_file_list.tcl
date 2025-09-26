# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set HDL_PATH ../../rtl

set HDL_FILES [ list \
    "./tb_partial_energy_calc.sv" \
    "${HDL_PATH}/adder_tree.sv" \
    "${HDL_PATH}/partial_energy_calc.sv" \
]
