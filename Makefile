# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

include ./common.mk

.PHONY: all build install

all: build

build:
	$(MAKE) -C hw all

install: 
	./ci/install.sh