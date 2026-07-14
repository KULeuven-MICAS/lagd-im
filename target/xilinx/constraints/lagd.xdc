# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# LAGD design/timing constraints (board-independent).
# Imported before the board XDC (see impl_sys.tcl).

##########################
# Externally-driven clocks
##########################

# SPI-slave clock, driven by the external master board. The SPI slave crosses
# this into soc_clk through its own CDC FIFO. Set the period to your master's
# SCK rate; 25 MHz (40 ns) is a safe bring-up default.
create_clock -period 40.000 -name spi_sck [get_ports spi_sck_i]

# JTAG TCK, driven by the debug adapter. 10 MHz (100 ns) default; raise if your
# adapter runs faster.
create_clock -period 100.000 -name jtag_tck [get_ports jtag_tck_i]

# RTC reference from the driver board (<= 32.768 kHz). Period set to 32.768 kHz
# (the fastest expected); the SoC timer crosses it asynchronously.
create_clock -period 30517.578 -name rtc_clk [get_ports rtc_i]

##############################
# Asynchronous control inputs
##############################

# These are synchronized inside the design, so exclude them from timing.
set_false_path -from [get_ports sys_reset]
set_false_path -from [get_ports jtag_trst_ni]

# NOTE: cross-clock grouping (soc_clk vs spi_sck vs jtag_tck) lives in the board
# XDC, because it references `sys_clk` which is created there. Constraints are
# evaluated in import order: this file first, then the board file.
