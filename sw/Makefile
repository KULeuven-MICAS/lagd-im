# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

PROJECT_ROOT := $(shell realpath ../)
include $(PROJECT_ROOT)/common.mk

CHS_SW_LD_DIR ?= ./link

CHS_ROOT := $(shell $(BENDER) path cheshire)
CHS_SW_PATH := $(CHS_ROOT)/sw
include $(CHS_ROOT)/cheshire.mk

# Add local sw/include path
CHS_SW_INCLUDES += -I$(PROJECT_ROOT)/sw/include

# Extract IC_REGS_BASE_ADDR from lagd_define.svh and expose as linker symbol
LAGD_IC_REGS_BASE := $(shell grep 'define IC_REGS_BASE_ADDR' \
    $(PROJECT_ROOT)/hw/rtl/include/lagd_define.svh | \
    sed -E "s/.*'h([0-9A-Fa-f_]+).*/0x\1/" | tr -d '_')
CHS_SW_LDFLAGS += -Wl,--defsym=__base_lagd_regs=$(LAGD_IC_REGS_BASE)

MY_TEST_SRCS = $(wildcard tests/*.spm.c)
MY_TESTS = $(MY_TEST_SRCS:.c=.elf) $(MY_TEST_SRCS:.c=.dump)

all: $(CHS_SW_LIBS) $(CHS_SW_GEN_HDRS) $(MY_TESTS)

# Auto-generate data header from model file
include/model_1_data.h: tests/data/model_1 tests/data/gen_model_data.py
	python3 tests/data/gen_model_data.py

# Ensure header is generated before compiling the lagd program
tests/lagd_scompute.spm.o: include/model_1_data.h

clean:
	rm -f tests/*.elf tests/*.dump include/model_1_data.h

build-chs: chs-sw-all

clean-chs:
	cd $(CHS_SW_PATH)/tests && rm -rf *.dump *.elf *.memh