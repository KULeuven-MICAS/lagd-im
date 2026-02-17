# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

export BENDER ?= ~/.cargo/bin/bender -d $(PROJECT_ROOT)
export BENDER_ROOT ?= $(PROJECT_ROOT)/.bender/
export CHS_SW_GCC_BINROOT ?= $(PROJECT_ROOT)/.opt/riscv-gnu-toolchain/bin/