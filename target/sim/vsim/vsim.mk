# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

SIM_DIR ?= $(shell basename $(CURDIR))/..

VSIM_BUILD_SCRIPT = $(SIM_DIR)/vsim/build.tcl
VSIM_SCRIPT = $(SIM_DIR)/vsim/sim-run.tcl
ifeq ($(DBG), 1)
	VSIM_OBJ = dbg_${SIM_NAME}
else
	VSIM_OBJ = nodbg_${SIM_NAME}
endif

# VSIM FLAGS
ifeq ($(NO_GUI), 1)
	VSIM_FLAGS += -c
endif

build: vsim-build

run: vsim-run build

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

vsim-run: $(TEST_PATH)/work/${SIM_NAME}.wlf

vsim-build: $(TEST_PATH)/work/work_${SIM_NAME}