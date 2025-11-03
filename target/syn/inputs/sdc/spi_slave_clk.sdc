# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

# SPI clock --------------------------------------------------------------------------
set spi_clock_period 6.0
set spi_clock_period_half [expr { $spi_clock_period / 2.0 } ]
create_clock [get_ports spis_sck_i] \
    -period $spi_clock_period -name SPI_CLK -waveform "0 $spi_clock_period_half"
# ------------------------------------------------------------------------------------

#-----------------------------
# Setup and hold time uncertainties
#-----------------------------
set_clock_uncertainty 0.10 -setup [get_clocks SPI_CLK]
set_clock_uncertainty 0.05 -hold [get_clocks SPI_CLK]

# Clock transition
set_clock_transition -fall 0.150 [get_clocks SPI_CLK]
set_clock_transition -rise 0.150 [get_clocks SPI_CLK]

# SPI assignments
set spi_clk_input_delay [expr { $spi_clock_period / $input_delay_denum } ]
set spi_clk_output_delay [expr { $spi_clock_period / $output_delay_denum } ]

set_input_delay -max $spi_clk_input_delay -clock SPI_CLK [get_ports pad_spis_csb_i]
set_input_delay -max $spi_clk_input_delay -clock SPI_CLK [get_ports pad_spis_sd_io]
set_output_delay -max $spi_clk_output_delay -clock SPI_CLK [get_ports pad_spis_sd_io]