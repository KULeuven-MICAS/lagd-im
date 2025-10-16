# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

PROJECT_ROOT := $(shell realpath ../../)
include $(PROJECT_ROOT)/common.mk

SYN_TOOL ?= synopsys
SYN_ARGS ?= --target syn --target tech_cells_generic_exclude_tc_sram

TECH ?= tsmc7ff

.PHONY: all clean tech

all: inputs/lagd-flist.tcl gen-sram

inputs/lagd-flist.tcl: $(PROJECT_ROOT)/Bender.yml
	$(BENDER) script $(SYN_TOOL) $(SYN_ARGS) > $@

tech:
	$(MAKE) -C ./tech/$(TECH) all

clean:
	rm -f inputs/lagd-flist.tcl
	$(MAKE) -C ./tech/$(TECH) clean