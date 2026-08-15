# Paths and toolchain -----------------------------------------------------
PROJECT_ROOT := $(shell realpath ../)
BENDER ?= ~/.cargo/bin/bender
include $(PROJECT_ROOT)/common.mk

CHS_ROOT := $(shell $(BENDER) path cheshire)
CHS_SW_PATH := $(CHS_ROOT)/sw
CHS_SW_LD_DIR ?= ./link
include $(CHS_ROOT)/cheshire.mk

# Build configuration -------------------------------------------------------
CHS_SW_INCLUDES += -I$(PROJECT_ROOT)/sw/include
CHS_SW_INCLUDES += -I$(PROJECT_ROOT)/sw/include/gen
CHS_SW_INCLUDES += -I$(PROJECT_ROOT)/sw/include/ref

# Space-separated NAME=VALUE pairs to forward as -D onto the compile line.
CHS_SW_INCLUDES += $(addprefix -D,$(COMPILE_ARGS))

# Data folder under tests/ref/data/ used by the tests/ref/ generated data headers below.
DATA_FOLDER ?= default

# Test sources ---------------------------------------------------------------
MY_TEST_SRCS = $(shell find tests -name '*.spm.c')
MY_TESTS = $(MY_TEST_SRCS:.c=.elf) $(MY_TEST_SRCS:.c=.dump)

# Only the tests/ref/ legacy tests need the generated data headers below.
REF_TEST_SRCS = $(wildcard tests/ref/*.spm.c)

# Generated headers -----------------------------------------------------------
# All generated headers live under include/gen/
RTL_ROOT := $(PROJECT_ROOT)/hw/rtl
SVH2H := utils/svh2h.py
GEN_MODEL_PY := utils/gen_model_data.py
GEN_FLIP_PY := utils/gen_flip_data.py
GEN_SPIN_PY := utils/gen_spin_data.py
GEN_STATE_OUT_PY := utils/gen_state_out_ref.py

include/gen:
	mkdir -p $@

# User configuration for LAGD system
include/gen/lagd_config.h: $(RTL_ROOT)/include/lagd_config.svh $(SVH2H) | include/gen
	python3 $(SVH2H) $< $@

# System-wide definitions for LAGD system
include/gen/lagd_define.h: $(RTL_ROOT)/include/lagd_define.svh $(SVH2H) include/gen/lagd_config.h | include/gen
	python3 $(SVH2H) $< $@

# LAGD core register- & bit-offsets.
include/gen/lagd_core_reg.h: $(RTL_ROOT)/lagd_core_reg/lagd_core_regs.hjson | include/gen
	$(MAKE) -C $(RTL_ROOT)/lagd_core_reg BENDER=$(BENDER) SW_INCLUDE_DIR=$(PROJECT_ROOT)/sw/include/gen all

# tests/ref/ data headers
include/gen/model_j_data.h: tests/ref/data/$(DATA_FOLDER)/model_1 $(GEN_MODEL_PY) | include/gen
	python3 $(GEN_MODEL_PY) --core-onload 0 --folder $(DATA_FOLDER)

include/gen/model_j_data_sec.h: tests/ref/data/$(DATA_FOLDER)/model_2 $(GEN_MODEL_PY) | include/gen
	python3 $(GEN_MODEL_PY) --core-onload 1 --folder $(DATA_FOLDER) --suffix _sec

include/gen/model_f_data.h: tests/ref/data/$(DATA_FOLDER)/clusters_1 tests/ref/data/$(DATA_FOLDER)/clusters_2 $(GEN_FLIP_PY) | include/gen
	python3 $(GEN_FLIP_PY) --core-onload 0 --folder $(DATA_FOLDER)

include/gen/model_f_data_sec.h: tests/ref/data/$(DATA_FOLDER)/clusters_3 tests/ref/data/$(DATA_FOLDER)/clusters_4 $(GEN_FLIP_PY) | include/gen
	python3 $(GEN_FLIP_PY) --core-onload 1 --folder $(DATA_FOLDER) --suffix _sec

include/gen/spin_data.h: tests/ref/data/$(DATA_FOLDER)/states_in_1 tests/ref/data/$(DATA_FOLDER)/states_in_2 $(GEN_SPIN_PY) | include/gen
	python3 $(GEN_SPIN_PY) --folder $(DATA_FOLDER) --core-onload 0

include/gen/spin_data_sec.h: tests/ref/data/$(DATA_FOLDER)/states_in_3 tests/ref/data/$(DATA_FOLDER)/states_in_4 $(GEN_SPIN_PY) | include/gen
	python3 $(GEN_SPIN_PY) --folder $(DATA_FOLDER) --suffix _sec --core-onload 1

include/gen/state_out_ref.h: tests/ref/data/$(DATA_FOLDER)/states_out_1 tests/ref/data/$(DATA_FOLDER)/states_out_2 $(GEN_STATE_OUT_PY) | include/gen
	python3 $(GEN_STATE_OUT_PY) --folder $(DATA_FOLDER) --core-onload 0

include/gen/state_out_ref_sec.h: tests/ref/data/$(DATA_FOLDER)/states_out_3 tests/ref/data/$(DATA_FOLDER)/states_out_4 $(GEN_STATE_OUT_PY) | include/gen
	python3 $(GEN_STATE_OUT_PY) --folder $(DATA_FOLDER) --suffix _sec --core-onload 1

# Ensure headers are generated before compiling tests that use them
$(MY_TEST_SRCS:.c=.o): include/gen/lagd_config.h include/gen/lagd_define.h include/gen/lagd_core_reg.h
$(REF_TEST_SRCS:.c=.o): include/gen/model_j_data.h include/gen/model_f_data.h include/gen/spin_data.h \
	include/gen/model_j_data_sec.h include/gen/model_f_data_sec.h include/gen/spin_data_sec.h \
	include/gen/state_out_ref.h include/gen/state_out_ref_sec.h

# Targets ---------------------------------------------------------------------
all: $(CHS_SW_LIBS) $(CHS_SW_GEN_HDRS) $(MY_TESTS)

clean:
	rm -f $(MY_TESTS) $(MY_TEST_SRCS:.c=.o)
	rm -rf include/gen

build-chs: chs-sw-all

clean-chs:
	cd $(CHS_SW_PATH)/tests && rm -rf *.dump *.elf *.memh
