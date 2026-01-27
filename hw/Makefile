# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

PROJECT_ROOT := $(shell realpath ../)
include $(PROJECT_ROOT)/common.mk

CHS_ROOT := $(shell $(BENDER) path cheshire)
include $(CHS_ROOT)/cheshire.mk

SIM_TOOL := vsim

VLOG_ARGS   ?= -suppress 2583 -suppress 13314 -timescale 1ns/1ps

all: chs-hw-all test

# Memory island hdl_file_list.tcl generation
MI_TEST_PATH := ./unit_tests/memory_island
MI_SIM_ARGS := -t rtl -t sim -t test -t cva6 -t cv64a6_imafdcsclic_sv39 --vlog-arg="$(VLOG_ARGS)"

test: $(MI_TEST_PATH)/bender_list.tcl $(MI_TEST_PATH)/bender_list_tsmc.tcl

$(MI_TEST_PATH)/bender_list.tcl: $(PROJECT_ROOT)/Bender.yml
	$(BENDER) script $(SIM_TOOL) $(MI_SIM_ARGS) > $@

$(MI_TEST_PATH)/bender_list_tsmc.tcl: $(PROJECT_ROOT)/Bender.yml
	$(BENDER) script $(SIM_TOOL) $(MI_SIM_ARGS) -t tech_cells_generic_exclude_tc_sram > $@
