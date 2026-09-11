# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Jiacong Sun <jiacong.sun@kuleuven.be>
#
# ZCU102 IMPLEMENTATION-ONLY constraints.
#
# These reference post-synthesis net names (the IBUFs Vivado inserts), so they
# cannot be evaluated during synthesis. The flow marks this file
# `used_in_synthesis false`, which also means editing it does NOT invalidate the
# synth_1 run - so `make impl` can reuse the existing synthesis checkpoint.

##############################
# Clock routing on non-GCIO pins
##############################

# spi_sck_i and jtag_tck_i are declared as clocks (lagd.xdc) and drive global
# clock buffers (the SPI slave's tc_clk_mux2 -> BUFGMUX; the JTAG TCK BUFG), but
# neither lands on a clock-capable (GCIO) pin:
#   * spi_sck_i is fixed to FMC LA02_P (V2) by the Zedboard's chip_sck_o + cable.
#   * jtag_tck_i is parked on a DIP switch (AN14) - no spare FMC pin for it.
# Without these, the placer fails with [Place 30-675] rule_gclkio_bufg.
#
# Demoting the rule is safe HERE: both are slow (25 MHz SPI, 10 MHz TCK, and TCK
# is static in the SPI-preload flow) and asynchronous to soc_clk, crossing
# through CDCs - so the less predictable clock insertion delay does not matter.
# (If SPI SCK skew ever does matter, have the Zedboard drive it on LA00_CC or
# LA01_CC instead, which ARE clock-capable on the ZCU102 - needs a driver change.)
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets spi_sck_i_IBUF_inst/O]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets jtag_tck_i_IBUF_inst/O]
