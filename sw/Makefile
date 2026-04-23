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

# Tested core
CORE_TESTED ?= 0
CORE_OTHER := $(if $(filter 0,$(CORE_TESTED)),1,0)

# Data folder name
DATA_FOLDER ?= default

# Define CORE_TESTED for C code
CHS_SW_INCLUDES += -DCORE_TESTED=$(CORE_TESTED)

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
	$(MAKE) -C $(RTL_ROOT)/lagd_core_reg BENDER=$(BENDER)

# Auto-generate data header from model file
include/model_j_data.h: tests/data/$(DATA_FOLDER)/model $(GEN_MODEL_PY)
	python3 $(GEN_MODEL_PY) --core-onload $(CORE_TESTED) --folder $(DATA_FOLDER)

include/model_j_data_sec.h: tests/data/$(DATA_FOLDER)/model $(GEN_MODEL_PY)
	python3 $(GEN_MODEL_PY) --core-onload $(CORE_OTHER) --folder $(DATA_FOLDER) --suffix _sec

# Auto-generate flip candidates header from cluster files
include/model_f_data.h: tests/data/$(DATA_FOLDER)/clusters_1 tests/data/$(DATA_FOLDER)/clusters_2 $(GEN_FLIP_PY)
	python3 $(GEN_FLIP_PY) --core-onload $(CORE_TESTED) --folder $(DATA_FOLDER)

include/model_f_data_sec.h: tests/data/$(DATA_FOLDER)/clusters_1 tests/data/$(DATA_FOLDER)/clusters_2 $(GEN_FLIP_PY)
	python3 $(GEN_FLIP_PY) --core-onload $(CORE_OTHER) --folder $(DATA_FOLDER) --suffix _sec

# Auto-generate spin initial/reference header from state files
include/spin_data.h: tests/data/$(DATA_FOLDER)/states_in_1 tests/data/$(DATA_FOLDER)/states_in_2 $(GEN_SPIN_PY)
	python3 $(GEN_SPIN_PY) --folder $(DATA_FOLDER)

# Ensure headers are generated before compiling tests that use them
$(MY_TEST_SRCS:.c=.o): include/lagd_config.h include/lagd_define.h include/lagd_core_reg.h include/model_j_data.h include/model_f_data.h include/spin_data.h

tests/lagd_dcompute.spm.o: include/model_f_data_sec.h include/model_j_data_sec.h

all: $(CHS_SW_LIBS) $(CHS_SW_GEN_HDRS) $(MY_TESTS)

clean:
	rm -f tests/*.elf tests/*.dump \
	      include/lagd_config.h include/lagd_define.h \
	      include/model_j_data*.h include/model_f_data*.h include/spin_data.h

build-chs: chs-sw-all

clean-chs:
	cd $(CHS_SW_PATH)/tests && rm -rf *.dump *.elf *.memh