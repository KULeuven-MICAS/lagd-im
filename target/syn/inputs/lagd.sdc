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
# Declare clocks
#-----------------------------

# Core clock ------------------------------------------------------------------------
set core_clock_period 2.0
set core_clock_period_half [expr { $core_clock_period / 2.0 } ]
create_clock [get_ports clk_i] \
    -period $core_clock_period -name CORE_CLK -waveform "0 $core_clock_period_half"

# Add this constraint to ensure that the CLK gen is used
#set_case_analysis 1 [get_pins i_core_clk_mux/S]
# ------------------------------------------------------------------------------------
# JTAG clock -------------------------------------------------------------------------
set jtag_clock_period 6.0
set jtag_clock_period_half [expr { $jtag_clock_period / 2.0 } ]
create_clock [get_ports jtag_tck_i] \
    -period $jtag_clock_period -name JTAG_CLK -waveform "0 $jtag_clock_period_half"
# ------------------------------------------------------------------------------------
# SPI clock --------------------------------------------------------------------------
# To do add SPI SLAVE
# set spi_clock_period 6.0
# set spi_clock_period_half [expr { $spi_clock_period / 2.0 } ]
# create_clock [get_ports spis_sck_i] \
#     -period $spi_clock_period -name SPI_CLK -waveform "0 $spi_clock_period_half"
# ------------------------------------------------------------------------------------
# VIRTUTAL clock ---------------------------------------------------------------------
set virt_clock_period 10.0
set virt_clock_period_half [expr { $virt_clock_period / 2.0 } ]
create_clock -period $virt_clock_period -name VIRT_CLK -waveform "0 $virt_clock_period_half"
# ------------------------------------------------------------------------------------

#-----------------------------
# Setup and hold time uncertainties
#-----------------------------
set_clock_uncertainty 0.10 -setup [get_clocks CORE_CLK]
set_clock_uncertainty 0.05 -hold [get_clocks CORE_CLK]

set_clock_uncertainty 0.10 -setup [get_clocks JTAG_CLK]
set_clock_uncertainty 0.05 -hold [get_clocks JTAG_CLK]

set_clock_uncertainty 0.10 -setup [get_clocks SPI_CLK]
set_clock_uncertainty 0.05 -hold [get_clocks SPI_CLK]

#-----------------------------
# Clock transition
#-----------------------------

# Guide is generally min(T/6, 150ps) for clock
set_clock_transition -fall 0.150 [get_clocks CORE_CLK]
set_clock_transition -rise 0.150 [get_clocks CORE_CLK]

set_clock_transition -fall 0.150 [get_clocks JTAG_CLK]
set_clock_transition -rise 0.150 [get_clocks JTAG_CLK]

set_clock_transition -fall 0.150 [get_clocks SPI_CLK]
set_clock_transition -rise 0.150 [get_clocks SPI_CLK]

#-----------------------------
# Path groups
#-----------------------------

# Add here difficult paths (groups) that need special optimization effort

#-----------------------------
# IO constraints
#-----------------------------

set_load 1.0 [all_outputs]

# 10% on each IO port
set input_delay_denum 10.0
set output_delay_denum 10.0

# JTAG assignments
set jtag_clk_input_delay [expr { $jtag_clock_period / $input_delay_denum } ]
set jtag_clk_output_delay [expr { $jtag_clock_period / $output_delay_denum } ]

set_input_delay -max $jtag_clk_input_delay -clock JTAG_CLK [get_ports pad_jtag_*_i]
set_output_delay -max $jtag_clk_output_delay -clock JTAG_CLK [get_ports pad_jtag_*_o]

# SPI assignments
set spi_clk_input_delay [expr { $spi_clock_period / $input_delay_denum } ]
set spi_clk_output_delay [expr { $spi_clock_period / $output_delay_denum } ]

set_input_delay -max $spi_clk_input_delay -clock SPI_CLK [get_ports pad_spis_csb_i]
set_input_delay -max $spi_clk_input_delay -clock SPI_CLK [get_ports pad_spis_sd_io]
set_output_delay -max $spi_clk_output_delay -clock SPI_CLK [get_ports pad_spis_sd_io]

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