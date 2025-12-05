# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

# Note: bender_list.tcl is generated from hw/Makefile

ifdef REGRESSION
	TEST_LIST := $(shell ls $(CURDIR)/tests/*.tcl)
	SIM_NAME := $(basename $(notdir $(TEST_LIST)))
else
	SIM_NAME := memory_island
endif
HDL_FILES_LIST ?= $(CURDIR)/tests/memory_island.tcl

include ../common.mk
