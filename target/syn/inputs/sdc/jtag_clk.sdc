# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

# ------------------------------------------------------------------------------------
# JTAG clock -------------------------------------------------------------------------
set jtag_clock_period 6.0
set jtag_clock_period_half [expr { $jtag_clock_period / 2.0 } ]
create_clock [get_ports jtag_tck_i] \
    -period $jtag_clock_period -name JTAG_CLK -waveform "0 $jtag_clock_period_half"
# ------------------------------------------------------------------------------------

#-----------------------------
# Setup and hold time uncertainties
#-----------------------------
set_clock_uncertainty 0.10 -setup [get_clocks JTAG_CLK]
set_clock_uncertainty 0.05 -hold [get_clocks JTAG_CLK]

# Clock transition
set_clock_transition -fall 0.150 [get_clocks JTAG_CLK]
set_clock_transition -rise 0.150 [get_clocks JTAG_CLK]

# JTAG assignments
set jtag_clk_input_delay [expr { $jtag_clock_period / $input_delay_denum } ]
set jtag_clk_output_delay [expr { $jtag_clock_period / $output_delay_denum } ]

set_input_delay -max $jtag_clk_input_delay -clock JTAG_CLK [get_ports pad_jtag_*_i]
set_output_delay -max $jtag_clk_output_delay -clock JTAG_CLK [get_ports pad_jtag_*_o]