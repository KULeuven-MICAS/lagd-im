# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

PROJECT_ROOT := $(shell realpath ../)
include $(PROJECT_ROOT)/common.mk

CHS_ROOT := $(shell $(BENDER) path cheshire)
include $(CHS_ROOT)/cheshire.mk

SIM_TOOL := vsim

all: chs-hw-all test

# Memory island hdl_file_list.tcl generation
MI_TEST_PATH := ./unit_tests/memory_island
MI_SIM_ARGS := -t rtl

test: $(MI_TEST_PATH)/bender_list.tcl

$(MI_TEST_PATH)/bender_list.tcl:
	$(BENDER) script $(SIM_TOOL) $(MI_SIM_ARGS) > $@