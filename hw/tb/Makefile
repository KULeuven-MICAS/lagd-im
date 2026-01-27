# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

SIM_TOOL := vsim
VLOG_ARGS   ?= -suppress 2583 -suppress 13314 -timescale 1ns/1ps
TEST_PATH := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

PROJECT_ROOT ?= $(abspath $(CURDIR)/../..)
include $(PROJECT_ROOT)/common.mk

# ============================================================
# Flist generation for system verification
# ============================================================

ifdef TECH_MODELS
	TECH_ARGS := -t tech_cells_generic_include_tc_sram
else
	TECH_ARGS :=
endif

# Memory island hdl_file_list.tcl generation
SIM_ARGS := -t rtl -t sim -t test -t cva6 -t cv64a6_imafdcsclic_sv39 --vlog-arg="$(VLOG_ARGS)"

flist: $(TEST_PATH)/bender_list.tcl

$(TEST_PATH)/bender_list.tcl: $(PROJECT_ROOT)/Bender.yml
	$(BENDER) script $(SIM_TOOL) $(SIM_ARGS) $(TECH_ARGS) > $@

clean:
	rm -f $(TEST_PATH)/bender_list.tcl