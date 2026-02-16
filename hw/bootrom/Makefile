# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

PROJECT_ROOT := $(shell realpath ../../)
include $(PROJECT_ROOT)/common.mk

# Override the default cheshire paths before include
CHS_ROOT := $(shell $(BENDER) path cheshire)
CHS_SW_LD_DIR := $(PROJECT_ROOT)/sw/link

include $(CHS_ROOT)/cheshire.mk

# Boot ROM (needs SW stack)
CHS_BROM_SRCS = $(wildcard $(CHS_ROOT)/hw/bootrom/*.S $(CHS_ROOT)/hw/bootrom/*.c) $(CHS_SW_LIBS)
BROM_FLAGS = $(CHS_SW_LDFLAGS) -Os -fno-zero-initialized-in-bss -flto -fwhole-program
# IMPORTANT: linker script MUST be the first prerequisite
BROM_LD_SCRIPTS = ./lagd_bootrom.ld $(CHS_SW_LD_DIR)/common.ldh

CHS_BROM := 1  # Temporarily until we do not have our own bootrom files
ifdef CHS_BROM
BROM_SRCS := $(CHS_BROM_SRCS)
else
BROM_SRCS :=
endif

# To make sure HDL file list is correct we need to override the
BOOTROM_SV_FILE := $(CHS_ROOT)/hw/bootrom/cheshire_bootrom.sv

./lagd_bootrom.elf: $(BROM_LD_SCRIPTS) $(BROM_SRCS)
	$(CHS_SW_CC) $(CHS_SW_INCLUDES) -T$< $(BROM_FLAGS) -o $@ $(BROM_SRCS)

./lagd_bootrom.sv: ./lagd_bootrom.bin $(CHS_ROOT)/util/gen_bootrom.py
	$(CHS_ROOT)/util/gen_bootrom.py --sv-module cheshire_bootrom $< > $@

$(BOOTROM_SV_FILE): ./lagd_bootrom.sv
	cp $< $@


all: $(BOOTROM_SV_FILE) ./lagd_bootrom.dump

clean:
	rm -f $(BOOTROM_SV_FILE) ./lagd_bootrom.elf ./lagd_bootrom.bin ./lagd_bootrom.dump ./lagd_bootrom.sv