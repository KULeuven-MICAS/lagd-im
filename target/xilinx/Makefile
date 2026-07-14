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
#   make program              # program the board over the HW server (JTAG)
#   make clean
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
HWS_URL  ?= localhost:3121
HWS_PATH ?= */xilinx_tcf/Xilinx/*

ADD_SOURCES := $(XILINX_DIR)/scripts/add_sources.$(BOARD).tcl
BIT         := $(XILINX_DIR)/out/$(PROJ).$(BOARD).bit

.PHONY: all sources ips synth bitstream program clean

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
