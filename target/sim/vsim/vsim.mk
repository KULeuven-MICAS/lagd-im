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

# Questasim build target
$(WORK_DIR)/work/work_${SIM_NAME}: $(HDL_FILES) $(VSIM_BUILD_SCRIPT)
	@mkdir -p $(WORK_DIR)/work
	TEST_PATH=$(TEST_PATH) WORK_DIR=$(WORK_DIR) SIM_NAME=$(SIM_NAME) DBG=$(DBG) \
	BUILD_ONLY=1 DEFINES="$(DEFINES)" HDL_FILE_LIST=$(HDL_FILES_LIST) \
	vsim $(VSIM_FLAGS) -do "source $(VSIM_BUILD_SCRIPT)" \
	&& mv ./transcript $(WORK_DIR)/transcript.build

# Questasim run target
$(WORK_DIR)/work/${SIM_NAME}.wlf: $(WORK_DIR)/work/work_${SIM_NAME} $(TEST_FILES) $(VSIM_SCRIPT) $(HDL_FILES)
	@mkdir -p $(WORK_DIR)/work
	TEST_PATH=$(TEST_PATH) WORK_DIR=$(WORK_DIR) SIM_NAME=$(SIM_NAME) DBG=$(DBG) FORCE_BUILD=0 \
	DEFINES="$(DEFINES)" HDL_FILE_LIST=$(HDL_FILES_LIST) OBJ=$(VSIM_OBJ) \
	vsim $(VSIM_FLAGS) -do "source $(VSIM_SCRIPT)" \
	&& mv ./transcript $(WORK_DIR)/transcript.run

vsim-run: $(WORK_DIR)/work/${SIM_NAME}.wlf

vsim-build: $(WORK_DIR)/work/work_${SIM_NAME}

clean-sim: 
	rm -rf $(WORK_DIR)/work/${SIM_NAME}.wlf $(WORK_DIR)/transcript.run ${WORK_DIR}/*.vcd

clean:
	rm -rf $(WORK_DIR)

# Aliases
build: vsim-build
run: vsim-run build
clean-all: clean

.PHONY: clean clean-sim clean-all