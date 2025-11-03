# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

#-----------------------------
# Set design rules
#-----------------------------
set_max_transition 0.250 [current_design]
set_max_fanout 32 [current_design]

#-----------------------------
# IO constraints
#-----------------------------

set_load 1.0 [all_outputs]

# 10% on each IO port
set input_delay_denum 10.0
set output_delay_denum 10.0

#-----------------------------
# Declare clocks
#-----------------------------
source ./sdc/lagd_core_clk.sdc
source ./sdc/lagd_jtag_clk.sdc
#source ./sdc/lagd_spi_clk.sdc
source ./sdc/lagd_virt_clk.sdc

#-----------------------------
# Path groups
#-----------------------------

# Add here difficult paths (groups) that need special optimization effort

#-----------------------------
# Debug false paths
#-----------------------------

# Add false path on async inputs #TODO

#-----------------------------
# Set don't touch
#-----------------------------

# Remove optimizations on some blocks

#-----------------------------
# Reset false paths
#-----------------------------

#-----------------------------
# Don't use cells
# Use carefully, but this was cherry-picked
# for correct purposes
#-----------------------------