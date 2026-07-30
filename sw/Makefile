# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

PROJECT_ROOT := $(shell realpath ../)
BENDER ?= ~/.cargo/bin/bender
include $(PROJECT_ROOT)/common.mk

RTL_ROOT := $(PROJECT_ROOT)/hw/rtl

CHS_SW_LD_DIR ?= ./link

CHS_ROOT := $(shell $(BENDER) path cheshire)
CHS_SW_PATH := $(CHS_ROOT)/sw
include $(CHS_ROOT)/cheshire.mk

# Add local sw/include path
CHS_SW_INCLUDES += -I$(PROJECT_ROOT)/sw/include

# Core driven by the single-core tests. It selects the core at C level only: the generated data
# headers below have a fixed meaning, so this never changes what is generated.
CORE_TESTED ?= 0

# Optional switch used by tests that guard checks with #ifndef VERIFICATION_TEST.
VERIFICATION_TEST ?= 1

# Data folder name
DATA_FOLDER ?= default

# Define CORE_TESTED for C code
CHS_SW_INCLUDES += -DCORE_TESTED=$(CORE_TESTED)
CHS_SW_INCLUDES += -DVERIFICATION_TEST=$(VERIFICATION_TEST)

MY_TEST_SRCS = $(wildcard tests/*.spm.c)
MY_TESTS = $(MY_TEST_SRCS:.c=.elf) $(MY_TEST_SRCS:.c=.dump)

GEN_MODEL_PY := utils/gen_model_data.py
GEN_FLIP_PY := utils/gen_flip_data.py
GEN_SPIN_PY := utils/gen_spin_data.py

# Auto-generate C headers from SVH hardware definitions (single source of truth)
SVH2H := utils/svh2h.py

include/lagd_config.h: $(RTL_ROOT)/include/lagd_config.svh $(SVH2H)
	python3 $(SVH2H) $< $@

include/lagd_define.h: $(RTL_ROOT)/include/lagd_define.svh $(SVH2H)
	python3 $(SVH2H) $< $@

include/lagd_core_reg.h: $(RTL_ROOT)/lagd_core_reg/lagd_core_regs.hjson
	$(MAKE) -C $(RTL_ROOT)/lagd_core_reg BENDER=$(BENDER) all

# The generated data headers have a fixed meaning, independent of CORE_TESTED: the plain ones hold
# the data of core 0 (model_1, clusters_1/2, states_in_1/2) and the _sec ones the data of core 1
# (model_2, clusters_3/4, states_in_3/4). Each test selects the set it needs at C level.

# Auto-generate data header from model file
include/model_j_data.h: tests/data/$(DATA_FOLDER)/model_1 $(GEN_MODEL_PY)
	python3 $(GEN_MODEL_PY) --core-onload 0 --folder $(DATA_FOLDER)

include/model_j_data_sec.h: tests/data/$(DATA_FOLDER)/model_2 $(GEN_MODEL_PY)
	python3 $(GEN_MODEL_PY) --core-onload 1 --folder $(DATA_FOLDER) --suffix _sec

# Auto-generate flip candidates header from cluster files
include/model_f_data.h: tests/data/$(DATA_FOLDER)/clusters_1 tests/data/$(DATA_FOLDER)/clusters_2 $(GEN_FLIP_PY)
	python3 $(GEN_FLIP_PY) --core-onload 0 --folder $(DATA_FOLDER)

include/model_f_data_sec.h: tests/data/$(DATA_FOLDER)/clusters_3 tests/data/$(DATA_FOLDER)/clusters_4 $(GEN_FLIP_PY)
	python3 $(GEN_FLIP_PY) --core-onload 1 --folder $(DATA_FOLDER) --suffix _sec

# Auto-generate spin initial/reference header from state files
include/spin_data.h: tests/data/$(DATA_FOLDER)/states_in_1 tests/data/$(DATA_FOLDER)/states_in_2 $(GEN_SPIN_PY)
	python3 $(GEN_SPIN_PY) --folder $(DATA_FOLDER) --core-onload 0

include/spin_data_sec.h: tests/data/$(DATA_FOLDER)/states_in_3 tests/data/$(DATA_FOLDER)/states_in_4 $(GEN_SPIN_PY)
	python3 $(GEN_SPIN_PY) --folder $(DATA_FOLDER) --suffix _sec --core-onload 1

# Ensure headers are generated before compiling tests that use them
$(MY_TEST_SRCS:.c=.o): include/lagd_config.h include/lagd_define.h include/lagd_core_reg.h \
	include/model_j_data.h include/model_f_data.h include/spin_data.h \
	include/model_j_data_sec.h include/model_f_data_sec.h include/spin_data_sec.h

all: $(CHS_SW_LIBS) $(CHS_SW_GEN_HDRS) $(MY_TESTS)

clean:
	rm -f tests/*.elf tests/*.dump \
	      include/lagd_config.h include/lagd_define.h \
	      include/model_j_data*.h include/model_f_data*.h include/spin_data*.h

build-chs: chs-sw-all

clean-chs:
	cd $(CHS_SW_PATH)/tests && rm -rf *.dump *.elf *.memh