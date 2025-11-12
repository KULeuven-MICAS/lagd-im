# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

include ./common.mk

.PHONY: all build install target-syn target-sim target-all

all: build

build:
	$(MAKE) -C hw all

target-syn:
	$(MAKE) -C target/syn

target-sim:
	$(MAKE) -C target/sim

target-all: target-syn target-sim

install: 
	./ci/install.sh