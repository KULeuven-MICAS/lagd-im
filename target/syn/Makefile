# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

PROJECT_ROOT := $(shell realpath ../../)
include $(PROJECT_ROOT)/common.mk

SYN_TOOL ?= synopsys
SYN_ARGS ?= --target syn

inputs/lagd-flist.tcl: $(PROJECT_ROOT)/Bender.yml
	$(BENDER) script $(SYN_TOOL) $(SYN_ARGS) > $@

