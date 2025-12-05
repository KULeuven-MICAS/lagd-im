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
WORK_DIR ?= $(TEST_PATH)/${SIM_TOOL}-runs
DBG ?= 0
NO_GUI ?= 1
DEFINES ?=

HDL_FILES_LIST ?= $(TEST_PATH)/hdl_file_list.tcl
UTIL_PATH ?= $(PROJECT_ROOT)/tools/utils
HDL_FILES ?= $(shell python3 $(UTIL_PATH)/get_hdl_flist.py -f $(HDL_FILES_LIST))
$(info HDL_FILES: $(HDL_FILES))

include $(SIM_DIR)/${SIM_TOOL}/$(SIM_TOOL).mk
