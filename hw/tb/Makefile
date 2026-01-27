# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

SIM_TOOL := vsim
VLOG_ARGS   ?= -suppress 2583 -suppress 13314 -timescale 1ns/1ps
TEST_PATH := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# Paths
PROJECT_ROOT ?= $(abspath $(CURDIR)/../..)
include $(PROJECT_ROOT)/common.mk
SIM_DIR := $(PROJECT_ROOT)/target/sim

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

# ============================================================
# Simulation Makefile
# ============================================================

TEST_PATH ?= $(CURDIR)
HDL_FILE_LIST ?= $(TEST_PATH)/bender_list.tcl
HDL_FILES ?=
DBG ?= 1
CXX_PATH ?= $(which g++)
VOPT_ARGS ?= -O5 +acc=p+tb_cheshire_soc. +noacc=p+cheshire_soc. +acc=r+stream_xbar -permissive
VSIM_FLAGS ?= -suppress 3009 -suppress 8386 -error 7 -cpppath ${CXX_PATH}

include $(SIM_DIR)/${SIM_TOOL}/$(SIM_TOOL).mk