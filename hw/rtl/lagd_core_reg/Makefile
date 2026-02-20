# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Jiacong Sun <jiacong.sun@kuleuven.be>

PROJECT_ROOT := $(shell realpath ../../../)

CHS_REG_DIR := $(shell bender path register_interface)
REGTOOL ?= $(CHS_REG_DIR)/vendor/lowrisc_opentitan/util/regtool.py

SW_INCLUDE_DIR := $(PROJECT_ROOT)/sw/include
HEADER_OUT := $(SW_INCLUDE_DIR)/lagd_core_reg.h

all: lagd_core_reg_top.sv lagd_core_reg_pkg.sv $(HEADER_OUT)

lagd_core_reg_top.sv lagd_core_reg_pkg.sv: lagd_core_regs.hjson
	$(REGTOOL) -r $< --outdir $(dir $@)

$(HEADER_OUT): lagd_core_regs.hjson | $(SW_INCLUDE_DIR)
	$(REGTOOL) -D $< > $@

$(SW_INCLUDE_DIR):
	mkdir -p $@

clean:
	rm -f lagd_core_reg_top.sv lagd_core_reg_pkg.sv $(HEADER_OUT)