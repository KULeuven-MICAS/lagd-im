# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>
# Basic simulation makefile

PROJECT_ROOT = $(realpath ../../../)

# PATHS
SIM_DIR = $(PROJECT_ROOT)/target/sim

ifdef LEAF
	SIM_NAME := $(LEAF)
else
	SIM_NAME ?= $(shell basename $(CURDIR))
endif

$(info SIM_NAME: $(SIM_NAME))

TEST_PATH ?= $(CURDIR)
WORK_DIR ?= $(TEST_PATH)/${SIM_TOOL}-runs/$(SIM_NAME)
DBG ?= 0
NO_GUI ?= 1
DEFINES ?=
PARAMS ?=

HDL_FILES_LIST ?= $(TEST_PATH)/hdl_file_list.tcl
UTIL_PATH ?= $(PROJECT_ROOT)/tools/utils
HDL_FILES ?= $(shell python3 $(UTIL_PATH)/get_hdl_flist.py -f $(HDL_FILES_LIST) -t HDL_FILES)
$(info HDL_FILES: $(HDL_FILES))
INCLUDE_FILES ?= $(shell python3 $(UTIL_PATH)/get_hdl_flist.py -f $(HDL_FILES_LIST) -t INCLUDE_DIRS)
$(info INCLUDE_FILES: $(INCLUDE_FILES))

include $(SIM_DIR)/${SIM_TOOL}/$(SIM_TOOL).mk
