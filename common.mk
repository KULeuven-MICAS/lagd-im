# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

BENDER ?= pixi run ~/.cargo/bin/bender -d $(PROJECT_ROOT)
BENDER_ROOT ?= $(PROJECT_ROOT)/.bender/
CHS_SW_GCC_BINROOT ?= $(PROJECT_ROOT)/.opt/riscv-gnu-toolchain/bin/