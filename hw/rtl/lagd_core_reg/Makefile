# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Authors: 
#	Jiacong Sun <jiacong.sun@kuleuven.be>
#	Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

CHS_REG_DIR := $(shell $(BENDER) path register_interface)
REGTOOL ?= $(CHS_REG_DIR)/vendor/lowrisc_opentitan/util/regtool.py

all: lagd_core_reg_top.sv lagd_core_reg_pkg.sv lagd_core_reg.h

lagd_core_reg_top.sv lagd_core_reg_pkg.sv: lagd_core_regs.hjson
	$(REGTOOL) -r $< --outdir $(dir $@)

lagd_core_reg.h: lagd_core_regs.hjson
	$(REGTOOL) -D $< > $@

clean:
	rm -f lagd_core_reg_top.sv lagd_core_reg_pkg.sv lagd_core_reg.h