# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

# VIRTUTAL clock ---------------------------------------------------------------------
set virt_clock_period 10.0
set virt_clock_period_half [expr { $virt_clock_period / 2.0 } ]
create_clock -period $virt_clock_period -name VIRT_CLK -waveform "0 $virt_clock_period_half"
# ------------------------------------------------------------------------------------

# Virtual clocks
# These go through synchronizers anyway
# Although timing won't be checked after all
set virt_clk_input_delay [expr { $virt_clock_period / $input_delay_denum } ]
set virt_clk_output_delay [expr { $virt_clock_period / $output_delay_denum } ]

set_input_delay -max $virt_clk_input_delay -clock VIRT_CLK [get_ports pad_uart_*i]
set_output_delay -max $virt_clk_output_delay -clock VIRT_CLK [get_ports pad_uart_*o]

set_input_delay -max $virt_clk_input_delay -clock VIRT_CLK [get_ports pad_rtc_i]

# Jtag ports are also asynchronous but specify completely here
# This is well controlled from the outside not within
set_input_delay -max $virt_clk_output_delay -clock VIRT_CLK [get_ports pad_jtag_trst_ni]
set_input_delay -max $virt_clk_output_delay -clock VIRT_CLK [get_ports pad_jtag_tms_i]
set_input_delay -max $virt_clk_output_delay -clock VIRT_CLK [get_ports pad_jtag_tdi_i]
set_output_delay -max $virt_clk_output_delay -clock VIRT_CLK [get_ports pad_jtag_tdo_o]