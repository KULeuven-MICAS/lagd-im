# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Jiacong Sun <jiacong.sun@kuleuven.be>

PROJECT_ROOT := $(shell realpath ../../../)

SW_INCLUDE_DIR := $(PROJECT_ROOT)/sw/include

HEADER_OUT_CONFIG := $(SW_INCLUDE_DIR)/lagd_config.h
HEADER_OUT_DEFINE := $(SW_INCLUDE_DIR)/lagd_define.h

all: $(HEADER_OUT_CONFIG) $(HEADER_OUT_DEFINE)

$(HEADER_OUT_CONFIG): lagd_config.svh svh2h.py
	python3 include/svh2h.py $< $@

$(HEADER_OUT_DEFINE): lagd_define.svh svh2h.py
	python3 include/svh2h.py $< $@