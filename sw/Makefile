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
# tests/ref/*.spm.c's own #include "lagd_reg_params.h" etc. only resolve via the including
# header's own directory (sw/include/ref/), not the test file's -- this makes them resolve from
# sw/tests/ref/*.spm.c too. Safe to add globally: no filename collides with sw/include's own.
CHS_SW_INCLUDES += -I$(PROJECT_ROOT)/sw/include/ref

# Space-separated NAME=VALUE pairs to forward as -D onto the compile line.
# E.g: make COMPILE_ARGS="CORE_TESTED=1" all.
CHS_SW_INCLUDES += $(addprefix -D,$(COMPILE_ARGS))

# Test sources ---------------------------------------------------------------
MY_TEST_SRCS_ORIG_EXCLUDE = tests/ref/lagd_dcompute.spm.c tests/ref/lagd_debug_spin.spm.c tests/ref/lagd_scompute.spm.c
MY_TEST_SRCS = $(filter-out $(MY_TEST_SRCS_ORIG_EXCLUDE),$(shell find tests -name '*.spm.c'))
MY_TESTS = $(MY_TEST_SRCS:.c=.elf) $(MY_TEST_SRCS:.c=.dump)

# Generated headers -----------------------------------------------------------
# All generated headers live under include/gen/
RTL_ROOT := $(PROJECT_ROOT)/hw/rtl
SVH2H := utils/svh2h.py

include/gen:
	mkdir -p $@

# User configuration for LAGD system
include/gen/lagd_config.h: $(RTL_ROOT)/include/lagd_config.svh $(SVH2H) | include/gen
	python3 $(SVH2H) $< $@

# System-wide definitions for LAGD system
include/gen/lagd_define.h: $(RTL_ROOT)/include/lagd_define.svh $(SVH2H) include/gen/lagd_config.h | include/gen
	python3 $(SVH2H) $< $@

# LAGD core register- & bit-offsets. hw/rtl/lagd_core_reg/Makefile is left untouched, but its
# SW_INCLUDE_DIR is a plain (":=") variable, so a command-line override redirects its header
# straight into include/gen/ -- no flat intermediate file shared across concurrent `make`
# invocations (e.g. this Makefile vs. ci/sys-run.sh, which also builds sw/) to race on.
include/gen/lagd_core_reg.h: $(RTL_ROOT)/lagd_core_reg/lagd_core_regs.hjson | include/gen
	$(MAKE) -C $(RTL_ROOT)/lagd_core_reg BENDER=$(BENDER) SW_INCLUDE_DIR=$(PROJECT_ROOT)/sw/include/gen all

# Ensure headers are generated before compiling tests that use them
$(MY_TEST_SRCS:.c=.o): include/gen/lagd_config.h include/gen/lagd_define.h include/gen/lagd_core_reg.h

# Targets ---------------------------------------------------------------------
all: $(CHS_SW_LIBS) $(CHS_SW_GEN_HDRS) $(MY_TESTS)

clean:
	rm -f $(MY_TESTS) $(MY_TEST_SRCS:.c=.o)
	rm -rf include/gen

build-chs: chs-sw-all

clean-chs:
	cd $(CHS_SW_PATH)/tests && rm -rf *.dump *.elf *.memh
