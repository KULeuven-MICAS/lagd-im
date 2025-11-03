# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

# Core clock ------------------------------------------------------------------------
set core_clock_period 2.0
set core_clock_period_half [expr { $core_clock_period / 2.0 } ]
create_clock [get_ports clk_i] \
    -period $core_clock_period -name CORE_CLK -waveform "0 $core_clock_period_half"

# Add this constraint to ensure that the CLK gen is used
#set_case_analysis 1 [get_pins i_core_clk_mux/S]
# ------------------------------------------------------------------------------------

#-----------------------------
# Setup and hold time uncertainties
#-----------------------------
set_clock_uncertainty 0.10 -setup [get_clocks CORE_CLK]
set_clock_uncertainty 0.05 -hold [get_clocks CORE_CLK]

# Clock transition
set_clock_transition -fall 0.150 [get_clocks CORE_CLK]
set_clock_transition -rise 0.150 [get_clocks CORE_CLK]