# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# LAGD Xilinx FPGA build flow (board: ZCU102).
# Adapted from cheshire/target/xilinx.
#
# Usage:
#   make sources              # generate the bender source list
#   make ips                  # build the Xilinx IPs (clk_wiz)
#   make synth                # synthesis only (no pins) -> utilization/timing
#   make bitstream            # full synth + impl -> out/lagd.zcu102.bit
#   make impl                 # re-impl only, reusing the synth checkpoint (fast)
#   make program              # program the board over the HW server (JTAG)
#   make clean
#
# Set LAGD_CLOCKS_RPT=1 to also generate clocks.rpt (adds a ~4 min elaboration).
#
# Override tools on the command line, e.g.:
#   make bitstream VIVADO="vitis-2025.2 vivado"

MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
XILINX_DIR  := $(patsubst %/,%,$(dir $(MKFILE_PATH)))
ROOT        := $(abspath $(XILINX_DIR)/../..)

BENDER ?= bender
VIVADO ?= vivado

BOARD ?= zcu102
PROJ  := lagd

# Bender targets selecting the FPGA source list. `rtl` selects the iDMA (and
# other) synthesizable RTL (incl. idma_pkg); `cva6`/`cv64a6_imafdcsclic_sv39`
# pick the CVA6 config. Mirrors cheshire's CHS_BENDER_RTL_FLAGS plus fpga/xilinx.
BENDER_TARGETS := -t fpga -t xilinx -t rtl -t cva6 -t cv64a6_imafdcsclic_sv39

# Xilinx IPs required per board.
IPS_zcu102 := clkwiz
IPS        := $(IPS_$(BOARD))
IP_XCIS    := $(foreach ip,$(IPS),$(XILINX_DIR)/build/$(BOARD).$(ip)/out.xci)

# HW server parameters for programming (defaults: single local board).
#
# common.tcl globs `${HWS_URL}/${HWS_PATH}` against the hw target name, which has
# the shape `<host>:<port>/xilinx_tcf/<vendor>/<serial>`. So HWS_PATH must NOT be
# prefixed with `*/` (that would expect an extra path segment and match nothing),
# and the vendor is `Digilent`: the ZCU102's onboard USB-JTAG is a Digilent
# FT232H module (`lsusb` 0403:6014), not a Xilinx-branded cable.
#
# Verified 2026-07-15: localhost:3121/xilinx_tcf/Digilent/210308AE6C4B -> xczu9_0.
# With several boards on one server, pin the serial instead of globbing (the glob
# silently takes the LAST match), e.g.:
#   make program HWS_PATH=xilinx_tcf/Digilent/210308AE6C4B
HWS_URL  ?= localhost:3121
HWS_PATH ?= xilinx_tcf/Digilent/*

ADD_SOURCES := $(XILINX_DIR)/scripts/add_sources.$(BOARD).tcl
BIT         := $(XILINX_DIR)/out/$(PROJ).$(BOARD).bit

.PHONY: all sources ips synth impl bitstream program clean

all: bitstream

#######################
# Bender source list  #
#######################

$(ADD_SOURCES): $(ROOT)/Bender.yml $(MKFILE_PATH)
	cd $(ROOT) && $(BENDER) script vivado $(BENDER_TARGETS) > $@

sources: $(ADD_SOURCES)

#######################
# Xilinx IPs          #
#######################

$(XILINX_DIR)/build/$(BOARD).%/out.xci: $(XILINX_DIR)/scripts/impl_ip.tcl
	mkdir -p $(dir $@)
	cd $(dir $@) && $(VIVADO) -mode batch -source $< -tclargs $(BOARD) $*

ips: $(IP_XCIS)

#######################
# Bitstream           #
#######################

bitstream: $(BIT)

$(BIT): $(XILINX_DIR)/scripts/impl_sys.tcl $(ADD_SOURCES) $(IP_XCIS)
	mkdir -p $(XILINX_DIR)/build/$(BOARD).$(PROJ)
	cd $(XILINX_DIR)/build/$(BOARD).$(PROJ) && \
		$(VIVADO) -mode batch -source $< -tclargs $(BOARD) $(PROJ) $(IP_XCIS)

# Synthesis only (stops before implementation). Runs without FMC pin LOCs;
# useful for an early utilization/timing/elaboration check. Creates the project
# under build/$(BOARD).$(PROJ) so you can also open it in the Vivado GUI.
synth: $(XILINX_DIR)/scripts/impl_sys.tcl $(ADD_SOURCES) $(IP_XCIS)
	mkdir -p $(XILINX_DIR)/build/$(BOARD).$(PROJ)
	cd $(XILINX_DIR)/build/$(BOARD).$(PROJ) && \
		LAGD_STOP_AFTER_SYNTH=1 $(VIVADO) -mode batch -source $< -tclargs $(BOARD) $(PROJ) $(IP_XCIS)

# Fast re-implementation: reuse the synthesis checkpoint from a previous
# `make bitstream` / `make synth` and run only opt/place/route/bitstream.
# Skips synthesis (~26 min) + the RTL elaboration (~4 min).
#
# ONLY valid when implementation-affecting inputs changed (pins, *_impl.xdc,
# strategy). If the RTL or the bender source list changed, run `make bitstream`:
# this target would implement the STALE netlist without warning.
impl: $(XILINX_DIR)/scripts/impl_only.tcl
	cd $(XILINX_DIR)/build/$(BOARD).$(PROJ) && \
		$(VIVADO) -mode batch -source $< -tclargs $(BOARD) $(PROJ)

#######################
# Program             #
#######################

program: $(XILINX_DIR)/scripts/util/program.tcl
	cd $(XILINX_DIR) && $(VIVADO) -mode batch -source $< \
		-tclargs $(HWS_URL) "$(HWS_PATH)" $(BOARD) $(BIT)

#######################
# Clean               #
#######################

clean:
	rm -rf $(XILINX_DIR)/build $(XILINX_DIR)/out
	rm -f  $(XILINX_DIR)/scripts/add_sources.*.tcl
	rm -f  $(XILINX_DIR)/*.jou $(XILINX_DIR)/*.log
