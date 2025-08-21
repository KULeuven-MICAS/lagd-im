# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>
# Basic simulation makefile

PROJECT_ROOT = $(realpath ../../../)

# PATHS
SIM_DIR = $(PROJECT_ROOT)/target/sim

SIM_NAME ?= $(shell basename $(CURDIR))
TEST_PATH ?= $(CURDIR)
DBG ?= 0
NO_GUI ?= 1
DEFINES ?=

VSIM_BUILD_SCRIPT = $(SIM_DIR)/questa/build.tcl
VSIM_SCRIPT = $(SIM_DIR)/questa/sim-run.tcl
ifeq ($(DBG), 1)
	VSIM_OBJ = dbg_${SIM_NAME}
else
	VSIM_OBJ = nodbg_${SIM_NAME}
endif

HDL_FILES_LIST ?= $(TEST_PATH)/hdl_file_list.tcl
UTIL_PATH ?= $(PROJECT_ROOT)/tools/utils
HDL_FILES ?= $(shell python3 $(UTIL_PATH)/get_hdl_flist.py -f $(HDL_FILES_LIST))
$(info HDL_FILES: $(HDL_FILES))

# VSIM FLAGS
ifeq ($(NO_GUI), 1)
	VSIM_FLAGS += -c
endif

# Questasim build target
$(TEST_PATH)/work/work_${SIM_NAME}: $(HDL_FILES) $(VSIM_BUILD_SCRIPT)
	@mkdir -p ./work
	TEST_PATH=$(TEST_PATH) SIM_NAME=$(SIM_NAME) DBG=$(DBG) \
	BUILD_ONLY=1 DEFINES="$(DEFINES)" HDL_FILE_LIST=$(HDL_FILES_LIST) \
	vsim $(VSIM_FLAGS) -do "source $(VSIM_BUILD_SCRIPT)"

# Questasim run target
$(TEST_PATH)/work/${SIM_NAME}.wlf: $(TEST_PATH)/work/work_${SIM_NAME} $(TEST_FILES) $(VSIM_SCRIPT) $(HDL_FILES)
	@mkdir -p ./work
	TEST_PATH=$(TEST_PATH) SIM_NAME=$(SIM_NAME) DBG=$(DBG) FORCE_BUILD=0 \
	DEFINES="$(DEFINES)" HDL_FILE_LIST=$(HDL_FILES_LIST) OBJ=$(VSIM_OBJ) \
	vsim $(VSIM_FLAGS) -do "source $(VSIM_SCRIPT)"

questa-run: $(TEST_PATH)/work/${SIM_NAME}.wlf

clean:
	rm -rf work transcript *.vcd