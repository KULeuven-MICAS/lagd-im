# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

PROJECT_ROOT := $(shell realpath .)
BENDER ?= pixi run ~/.cargo/bin/bender -d $(PROJECT_ROOT)

.PHONY: all

all: build

build:
	$(MAKE) -C hw

install: 
	./ci/install.sh