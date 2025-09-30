# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

# Preserving the RTE net
set_dont_touch [get_nets {wire_rte}]
set_compile_directives -constant_propagation false [get_lib_cells */RTE_CELL]

# Don't touch tie cells
set_dont_touch [get_cells clock_dvddpg]
set_dont_touch [get_cells clock_dvddpgz]
set_dont_touch [get_cells clock_dislvl]
set_dont_touch [get_cells clock_dislvlz]

set_dont_touch [get_nets clock_dvddpg]
set_dont_touch [get_nets clock_dvddpgz]
set_dont_touch [get_nets clock_dislvl]
set_dont_touch [get_nets clock_dislvlz]