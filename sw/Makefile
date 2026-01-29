# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

PROJECT_ROOT := $(shell realpath ../)
include $(PROJECT_ROOT)/common.mk

CHS_SW_GCC_BINROOT ?= $(PROJECT_ROOT)/.opt/riscv-gnu-toolchain/bin
CHS_SW_LD_DIR ?= ./link

CHS_ROOT := $(shell $(BENDER) path cheshire)
include $(CHS_ROOT)/cheshire.mk

all: chs-sw-all