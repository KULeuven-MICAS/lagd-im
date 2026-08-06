# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>
# Author: Jiacong Sun <jiacong.sun@kuleuven.be>

PROJECT_ROOT := $(shell realpath ../)
BENDER ?= ~/.cargo/bin/bender
include $(PROJECT_ROOT)/common.mk

RTL_ROOT := $(PROJECT_ROOT)/hw/rtl

CHS_SW_LD_DIR ?= ./link

CHS_ROOT := $(shell $(BENDER) path cheshire)
CHS_SW_PATH := $(CHS_ROOT)/sw
include $(CHS_ROOT)/cheshire.mk

# Add local sw/include paths: hand-written headers, and generated ones (kept separate so
# .gitignore doesn't need a per-file allowlist for the hand-written ones)
CHS_SW_INCLUDES += -I$(PROJECT_ROOT)/sw/include
CHS_SW_INCLUDES += -I$(PROJECT_ROOT)/sw/include/gen

# Core driven by the single-core tests. It selects the core at C level only: the generated data
# headers below have a fixed meaning, so this never changes what is generated.
CORE_TESTED ?= 0

# Optional switch used by tests that guard checks with #ifndef VERIFICATION_TEST.
VERIFICATION_TEST ?= 1

# Word line stride of lagd_debug_dt: 1 covers the whole array, a larger value shortens the
# simulation. The h word line is always covered.
ROW_STRIDE ?= 1

# Data folder name
DATA_FOLDER ?= default

# Define CORE_TESTED for C code
CHS_SW_INCLUDES += -DCORE_TESTED=$(CORE_TESTED)
CHS_SW_INCLUDES += -DVERIFICATION_TEST=$(VERIFICATION_TEST)
CHS_SW_INCLUDES += -DROW_STRIDE=$(ROW_STRIDE)

MY_TEST_SRCS = $(wildcard tests/*.spm.c)
MY_TESTS = $(MY_TEST_SRCS:.c=.elf) $(MY_TEST_SRCS:.c=.dump)

GEN_MODEL_PY := utils/gen_model_data.py
GEN_FLIP_PY := utils/gen_flip_data.py
GEN_SPIN_PY := utils/gen_spin_data.py
GEN_STATE_OUT_PY := utils/gen_state_out_ref.py

# Auto-generate C headers from SVH hardware definitions (single source of truth)
SVH2H := utils/svh2h.py

# All generated headers live under include/gen/ (kept separate from the hand-written ones in
# include/), so .gitignore can ignore the whole directory instead of naming files individually.
include/gen:
	mkdir -p $@

include/gen/lagd_config.h: $(RTL_ROOT)/include/lagd_config.svh $(SVH2H) | include/gen
	python3 $(SVH2H) $< $@

include/gen/lagd_define.h: $(RTL_ROOT)/include/lagd_define.svh $(SVH2H) | include/gen
	python3 $(SVH2H) $< $@

# hw/rtl/lagd_core_reg/Makefile writes its header straight to include/ (that Makefile lives under
# hw/ and is left untouched); relocate it into include/gen/ here to keep the split consistent.
include/gen/lagd_core_reg.h: $(RTL_ROOT)/lagd_core_reg/lagd_core_regs.hjson | include/gen
	$(MAKE) -C $(RTL_ROOT)/lagd_core_reg BENDER=$(BENDER) all
	mv include/lagd_core_reg.h $@

# The generated data headers have a fixed meaning, independent of CORE_TESTED: the plain ones hold
# the data of core 0 (model_1, clusters_1/2, states_in_1/2) and the _sec ones the data of core 1
# (model_2, clusters_3/4, states_in_3/4). Each test selects the set it needs at C level.

# Auto-generate data header from model file
include/gen/model_j_data.h: tests/data/$(DATA_FOLDER)/model_1 $(GEN_MODEL_PY) | include/gen
	python3 $(GEN_MODEL_PY) --core-onload 0 --folder $(DATA_FOLDER)

include/gen/model_j_data_sec.h: tests/data/$(DATA_FOLDER)/model_2 $(GEN_MODEL_PY) | include/gen
	python3 $(GEN_MODEL_PY) --core-onload 1 --folder $(DATA_FOLDER) --suffix _sec

# Auto-generate flip candidates header from cluster files
include/gen/model_f_data.h: tests/data/$(DATA_FOLDER)/clusters_1 tests/data/$(DATA_FOLDER)/clusters_2 $(GEN_FLIP_PY) | include/gen
	python3 $(GEN_FLIP_PY) --core-onload 0 --folder $(DATA_FOLDER)

include/gen/model_f_data_sec.h: tests/data/$(DATA_FOLDER)/clusters_3 tests/data/$(DATA_FOLDER)/clusters_4 $(GEN_FLIP_PY) | include/gen
	python3 $(GEN_FLIP_PY) --core-onload 1 --folder $(DATA_FOLDER) --suffix _sec

# Auto-generate spin initial/reference header from state files
include/gen/spin_data.h: tests/data/$(DATA_FOLDER)/states_in_1 tests/data/$(DATA_FOLDER)/states_in_2 $(GEN_SPIN_PY) | include/gen
	python3 $(GEN_SPIN_PY) --folder $(DATA_FOLDER) --core-onload 0

include/gen/spin_data_sec.h: tests/data/$(DATA_FOLDER)/states_in_3 tests/data/$(DATA_FOLDER)/states_in_4 $(GEN_SPIN_PY) | include/gen
	python3 $(GEN_SPIN_PY) --folder $(DATA_FOLDER) --suffix _sec --core-onload 1

# Auto-generate the spin vectors the analog macro hands out from the state output files
# (required by lagd_check_l1_f_mem in lagd_debug_spin.spm.c)
include/gen/state_out_ref.h: tests/data/$(DATA_FOLDER)/states_out_1 tests/data/$(DATA_FOLDER)/states_out_2 $(GEN_STATE_OUT_PY) | include/gen
	python3 $(GEN_STATE_OUT_PY) --folder $(DATA_FOLDER) --core-onload 0

include/gen/state_out_ref_sec.h: tests/data/$(DATA_FOLDER)/states_out_3 tests/data/$(DATA_FOLDER)/states_out_4 $(GEN_STATE_OUT_PY) | include/gen
	python3 $(GEN_STATE_OUT_PY) --folder $(DATA_FOLDER) --suffix _sec --core-onload 1

# Ensure headers are generated before compiling tests that use them
$(MY_TEST_SRCS:.c=.o): include/gen/lagd_config.h include/gen/lagd_define.h include/gen/lagd_core_reg.h \
	include/gen/model_j_data.h include/gen/model_f_data.h include/gen/spin_data.h \
	include/gen/model_j_data_sec.h include/gen/model_f_data_sec.h include/gen/spin_data_sec.h \
	include/gen/state_out_ref.h include/gen/state_out_ref_sec.h

all: $(CHS_SW_LIBS) $(CHS_SW_GEN_HDRS) $(MY_TESTS)

clean:
	rm -f tests/*.elf tests/*.dump
	rm -rf include/gen

build-chs: chs-sw-all

clean-chs:
	cd $(CHS_SW_PATH)/tests && rm -rf *.dump *.elf *.memh