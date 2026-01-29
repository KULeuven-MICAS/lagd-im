# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

SIM_DIR ?= $(shell basename $(CURDIR))/..
RUN_TARGET ?= $(foreach s,$(SIM_NAME),$(WORK_DIR)/$(s)/work/$(s).wlf)
BUILD_TARGET ?= $(foreach s,$(SIM_NAME),$(WORK_DIR)/$(s)/work/work_$(s))

VSIM_BUILD_SCRIPT = $(SIM_DIR)/vsim/build.tcl
VSIM_SCRIPT = $(SIM_DIR)/vsim/sim-run.tcl
ifeq ($(DBG), 1)
	VSIM_OBJ_PREFIX = dbg_
else
	VSIM_OBJ_PREFIX = nodbg_
endif

# VSIM FLAGS
ifeq ($(NO_GUI), 1)
	RUN_FLAGS += -c
endif

# Set 64 bit mode
ifdef XLEN32
	XLEN_FLAG :=
else
	XLEN_FLAG := -64
endif

# Questasim build target
$(BUILD_TARGET): $(HDL_FILES) $(INCLUDE_FILES) $(VSIM_BUILD_SCRIPT)
	@mkdir -p $(WORK_DIR)/work
	TEST_PATH=$(TEST_PATH) WORK_DIR=$(WORK_DIR) SIM_NAME=$(SIM_NAME) DBG=$(DBG) \
	BUILD_ONLY=1 DEFINES="$(DEFINES)" HDL_FILE_LIST=$(HDL_FILES_LIST) PARAMS="$(PARAMS)" \
	VLOG_FLAGS="$(VLOG_FLAGS)" VOPT_ARGS="$(VOPT_ARGS)" \
	vsim $(XLEN_FLAG) -c -do "source $(VSIM_BUILD_SCRIPT)" \
	&& mv ./transcript $(WORK_DIR)/transcript.build

# Questasim run target
$(RUN_TARGET): $(BUILD_TARGET) $(TEST_FILES) $(VSIM_SCRIPT) $(HDL_FILES) $(INCLUDE_FILES)
	@mkdir -p $(WORK_DIR)/work
	TEST_PATH=$(TEST_PATH) WORK_DIR=$(WORK_DIR) SIM_NAME=$(SIM_NAME) DEFINES="$(DEFINES)" \
	HDL_FILE_LIST=$(HDL_FILES_LIST) PARAMS="$(PARAMS)" OBJ=$(VSIM_OBJ_PREFIX)$(SIM_NAME) \
	DBG=$(DBG) FORCE_BUILD=0  VSIM_FLAGS="$(VSIM_FLAGS)" VOPT_ARGS="$(VSIM_VOPT_ARGS)" \
	vsim $(XLEN_FLAG) $(RUN_FLAGS) -do "source $(VSIM_SCRIPT)" \
	&& mv ./transcript $(WORK_DIR)/transcript.run

vsim-run: $(RUN_TARGET)

vsim-build: $(BUILD_TARGET)

vsim-clean-sim: 
	rm -rf $(WORK_DIR)/work/*.wlf $(WORK_DIR)/transcript.run ${WORK_DIR}/*.vcd

vsim-clean:
	rm -rf $(WORK_DIR)

# Aliases
build: vsim-build
run: vsim-run
clean-all: vsim-clean

.PHONY: vsim-clean vsim-clean-sim clean-all run 