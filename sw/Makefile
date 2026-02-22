# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

PROJECT_ROOT := $(shell realpath ../)
include $(PROJECT_ROOT)/common.mk

RTL_ROOT := $(PROJECT_ROOT)/hw/rtl

CHS_SW_LD_DIR ?= ./link

CHS_ROOT := $(shell $(BENDER) path cheshire)
CHS_SW_PATH := $(CHS_ROOT)/sw
include $(CHS_ROOT)/cheshire.mk

# Add local sw/include path
CHS_SW_INCLUDES += -I$(PROJECT_ROOT)/sw/include

# XOR data verification (off by default; enable with: make XOR_CHECK=1)
XOR_CHECK ?= 0
ifeq ($(XOR_CHECK),1)
CHS_SW_INCLUDES += -DENABLE_XOR_CHECK
endif

MY_TEST_SRCS = $(wildcard tests/*.spm.c)
MY_TESTS = $(MY_TEST_SRCS:.c=.elf) $(MY_TEST_SRCS:.c=.dump)

all: $(CHS_SW_LIBS) $(CHS_SW_GEN_HDRS) $(MY_TESTS)

# Auto-generate C headers from SVH hardware definitions (single source of truth)
SVH2H := $(RTL_ROOT)/include/svh2h.py

include/lagd_config.h include/lagd_define.h: $(RTL_ROOT)/include/lagd_config.svh $(RTL_ROOT)/include/lagd_define.svh $(SVH2H)
	$(MAKE) -C $(RTL_ROOT)/include

# Auto-generate data header from model file
include/model_1_data.h: tests/data/model_1 tests/data/gen_model_data.py
	python3 tests/data/gen_model_data.py

# Auto-generate flip candidates header from cluster files
include/model_f_data.h: tests/data/clusters_1 tests/data/clusters_2 tests/data/gen_flip_data.py
	python3 tests/data/gen_flip_data.py

# Auto-generate spin initial/reference header from state files
include/spin_data.h: tests/data/states_in_1 tests/data/states_in_2 tests/data/gen_spin_data.py
	python3 tests/data/gen_spin_data.py

# Ensure headers are generated before compiling tests that use them
tests/lagd_scompute.spm.o: include/lagd_define.h include/model_1_data.h include/model_f_data.h include/spin_data.h
tests/lagd_reg.spm.o: include/lagd_define.h

clean:
	rm -f tests/*.elf tests/*.dump \
	      include/lagd_config.h include/lagd_define.h \
	      include/model_1_data.h include/model_f_data.h include/spin_data.h \
	      link/lagd_mem.h link/common.ldh

build-chs: chs-sw-all

clean-chs:
	cd $(CHS_SW_PATH)/tests && rm -rf *.dump *.elf *.memh