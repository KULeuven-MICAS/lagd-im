# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

# TODO: fix dep graph to avoid re-building RTL everytime

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

ifeq ($(USE_TECH_MODELS),1)
$(info "USE_TECH_MODELS is set to $(USE_TECH_MODELS), including tech cells in the flist")
TECH_ARGS := -t tech_cells_generic_exclude_tc_sram
TECH_MODELS_DEFINES = TSMC_CM_UNIT_DELAY=1 TSMC_DISABLE_INFO_MESSAGE=1
TECH_MODELS_DEFINES += TSMC_INITIALIZE_MEM_USING_DEFAULT_TASKS=1 TSMC_MEM_LOAD_RANDOM=1
else
TECH_ARGS :=
endif

# Memory island hdl_file_list.tcl generation
SIM_ARGS := -t rtl -t sim -t test -t cva6 -t cv64a6_imafdcsclic_sv39 --vlog-arg="$(VLOG_ARGS)"
CHS_ROOT := $(shell $(BENDER) path cheshire)
CXX_PATH := $(shell which g++)

flist: $(TEST_PATH)/bender_list.tcl $(TEST_PATH)/pkg_bender_list.tcl

$(TEST_PATH)/bender_list.tcl: $(PROJECT_ROOT)/Bender.yml
	$(BENDER) script $(SIM_TOOL) $(SIM_ARGS) $(TECH_ARGS) > $@
	echo 'vlog "$(realpath $(CHS_ROOT))/target/sim/src/elfloader.cpp" -ccflags "-std=c++11" \
		-cpppath "$(CXX_PATH)"' >> $@

TMP_FILE := ./tmp.bender_list.tcl
.INTERMEDIATE: $(TMP_FILE)
# Remove non-package files from the bender list to create a package-only list
$(TMP_FILE): $(TEST_PATH)/bender_list.tcl
	awk '!/\.sv" \\$$/ || /(_pkg|fixture_lagd_chip|rand_id_queue|axi_test|spinal_usb_ohci)\.sv" \\$$/' $< > $@

# Clean up the temporary file after generating the package-only list
$(TEST_PATH)/pkg_bender_list.tcl: $(TMP_FILE)
	awk 'BEGIN {block=""; header=""; printed=0} \
	NR<=2 {header=header $$0 "\n"; next} \
	/^if \{/ {block=$$0; next} \
	{block=block"\n"$$0} \
	/\}\]\} \{return 1\}/ { \
		if (block ~ /\.sv"/) { \
			if (!printed) {printf "%s", header; printed=1} \
			print block \
		} \
		block="" \
	}' $< > $@

# ===========================================================
# Make DPI-C shared library
# ===========================================================
# Note: this is not needed adding the vlog elfloader.cpp command to the bender list 
#	and using vsim -64

ELFLOADER_SRC := $(CHS_ROOT)/target/sim/src/elfloader.cpp
DPI_LIB := $(TEST_PATH)/libelfloader.so

# Questasim HOME must be defined to build the DPI library
ifndef MGC_QUESTA_HOME
$(error MGC_QUESTA_HOME is not defined. Please set it to your QuestaSim installation path)
endif

$(DPI_LIB): $(ELFLOADER_SRC)
	$(CXX_PATH) -m64 -shared -fPIC -I$(MGC_QUESTA_HOME)/include/ -std=c++11 $< -o $@

libelfloader: $(DPI_LIB)


# ============================================================
# Simulation Makefile
# ============================================================

TEST_PATH ?= $(CURDIR)
HDL_FILES_LIST ?= $(TEST_PATH)/hdl_file_list.tcl
SIM_NAME ?= lagd_chip
WORK_DIR ?= $(TEST_PATH)/${SIM_TOOL}-runs/$(SIM_NAME)
HDL_FILES ?=
DBG ?= 1
CXX_PATH ?= $(shell which g++)
VOPT_ARGS += -O5 +acc=pr+tb_lagd_chip. +noacc=p+lagd_soc. -permissive
VSIM_FLAGS += -suppress 3009 -suppress 8386 -error 7 -cpppath ${CXX_PATH} +notimingchecks
# VSIM_FLAGS += -sv_lib libelfloader

# Simulation defines
BOOT_MODE ?= 0
PRELOAD_MODE ?= 0
PRELOAD_ELF ?= ""
CHIP_LEVEL_TEST ?= 0
DEFINES += BOOT_MODE=$(BOOT_MODE) PRELOAD_MODE=$(PRELOAD_MODE)
DEFINES += PRELOAD_ELF=\"$(PRELOAD_ELF)\" CHIP_LEVEL_TEST=$(CHIP_LEVEL_TEST) $(TECH_MODELS_DEFINES)

RUN_DEPS := flist
include $(SIM_DIR)/${SIM_TOOL}/$(SIM_TOOL).mk

clean: vsim-clean
	rm -f $(TEST_PATH)/bender_list.tcl $(TEST_PATH)/pkg_bender_list.tcl