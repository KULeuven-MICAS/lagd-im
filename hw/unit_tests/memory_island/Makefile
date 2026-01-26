# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>


SIM_TOOL := vsim
VLOG_ARGS   ?= -suppress 2583 -suppress 13314 -timescale 1ns/1ps
MI_TEST_PATH := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

PROJECT_ROOT ?= $(abspath $(CURDIR)/../../..)
include $(PROJECT_ROOT)/common.mk

# ============================================================
# Simulation directives
# ============================================================

ifdef REGRESSION
	TEST_LIST := $(shell ls $(CURDIR)/tests/*.tcl)
	SIM_NAME := $(basename $(notdir $(TEST_LIST)))
else
	SIM_NAME := memory_island
endif
HDL_FILES_LIST ?= $(CURDIR)/tests/memory_island.tcl

# ============================================================
# Memory Island flist generation
# ============================================================

ifdef TECH_MODELS
	TECH_ARGS := -t tech_cells_generic_include_tc_sram
else
	TECH_ARGS :=
endif

# Memory island hdl_file_list.tcl generation
MI_SIM_ARGS := -t rtl -t sim -t test -t cva6 -t cv64a6_imafdcsclic_sv39 --vlog-arg="$(VLOG_ARGS)"

flists: $(MI_TEST_PATH)/bender_list.tcl

$(MI_TEST_PATH)/bender_list.tcl: $(PROJECT_ROOT)/Bender.yml
	$(BENDER) script $(SIM_TOOL) $(MI_SIM_ARGS) $(TECH_ARGS) > $@