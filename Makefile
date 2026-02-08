# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

PROJECT_ROOT := $(shell realpath ./)
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

# All targets needed for synthesis --------------------------------------

# TODO: add cheshire targets

SYNC_DEPS := hw target-syn
include ./target/syn/sync.mk

target-syn-all: hw target-syn sync

target-syn-clean-all: hw-clean target-syn-clean

# Other targets ---------------------------------------------------------

install: 
	./ci/install.sh

# PHONY all and clean targets -------------------------------------------

.PHONY: all hw install target-syn target-sim target-all sw

all: hw