# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

export PROJECT_ROOT := $(shell realpath ./)
include $(PROJECT_ROOT)/common.mk

# Hierarchical targets -------------------------------------------------

hw:
	$(MAKE) -C hw all
hw-clean:
	$(MAKE) -C hw clean

sw:
	$(MAKE) -C sw all

target-syn:
	$(MAKE) -C target/syn all
target-syn-clean:
	$(MAKE) -C target/syn clean

target-sim:
	$(MAKE) -C target/sim

target-all: target-syn target-sim

PHONY_HIER := hw sw target-syn target-sim target-all hw-clean target-syn-clean

# All targets needed for synthesis --------------------------------------

# TODO: add cheshire targets

SYNC_DEPS := hw target-syn
include ./target/syn/sync.mk

target-syn-all: hw target-syn sync
target-syn-clean-all: hw-clean target-syn-clean

PHONY_SYN := target-syn-all target-syn-clean-all

# All targets needed for system simulation --------------------------------------

# TODO: make flist generation a dependency of the run target
soc-tb-flist: ./Bender.yml
	$(MAKE) -C hw/tb flist

run-soc: soc-tb-flist
	$(MAKE) -C hw/tb run

PHONY_SOC_SIM := soc-tb-flist run-soc

# Other targets ---------------------------------------------------------

install: 
	./ci/install.sh

PHONY_OTHER := install

# PHONY all and clean targets -------------------------------------------

.PHONY: all clean $(PHONY_HIER) $(PHONY_SYN) $(PHONY_SOC_SIM) $(PHONY_OTHER)

all: hw