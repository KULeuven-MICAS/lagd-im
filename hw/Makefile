# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

PROJECT_ROOT := $(shell realpath ../)
include $(PROJECT_ROOT)/common.mk

# Deps targets ---------------------------------------------------------

CHS_ROOT := $(shell $(BENDER) path cheshire)
include $(CHS_ROOT)/cheshire.mk

# TODO: write cheshire clean targets

# Hierarchical targets -------------------------------------------------

memory_island_flist:
	$(MAKE) -C unit_tests/memory_island flist

uts: memory_island_flist

lagd_chip_test_flist:
	$(MAKE) -C ./tb flist

soc_tb: lagd_chip_test_flist

bootrom:
	$(MAKE) -C bootrom all

bootrom-clean:
	$(MAKE) -C bootrom clean

lagd_core_reg:
	$(MAKE) -C ./rtl/lagd_core_reg all

lagd_core_reg-clean:
	$(MAKE) -C ./rtl/lagd_core_reg clean

# PHONY all and clean targets -------------------------------------------------

.PHONY: all uts memory_island_flist lagd_chip_test_flist soc_tb bootrom bootrom-clean lagd_core_reg lagd_core_reg-clean

all: chs-hw-all bootrom lagd_core_reg

clean: bootrom-clean lagd_core_reg-clean