# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

PROJECT_ROOT := $(shell realpath ../)
include $(PROJECT_ROOT)/common.mk

CHS_ROOT := $(shell $(BENDER) path cheshire)
include $(CHS_ROOT)/cheshire.mk

all: chs-hw-all uts soc_tb

uts: memory_island_flist

soc_tb: lagd_chip_test_flist

memory_island_flist:
	$(MAKE) -C unit_tests/memory_island flist

lagd_chip_test_flist:
	$(MAKE) -C ./tb flist

.PHONY: all uts memory_island_flist lagd_chip_test_flist soc_tb