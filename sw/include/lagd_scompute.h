// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Header-only LAGD register configuration.

#pragma once

#include "lagd_define.h"
#include "lagd_core_reg.h"
#include "model_j_data.h"
#include "spin_data.h"
#include "lagd_reg_params.h"
#include "util.h"
#include "printf.h"

// Configure initial spin registers for the given core index.
static void lagd_configure_initial_spins(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    // Write initial spin set 0
    for (int i = 0; i < NUM_SPIN / 32; i++) {
        *reg32(base, LAGD_CORE_CONFIG_SPIN_INITIAL_0_0_REG_OFFSET + 4 * i) = spin_initial_0[i];
    }
    // Write initial spin set 1
    for (int i = 0; i < NUM_SPIN / 32; i++) {
        *reg32(base, LAGD_CORE_CONFIG_SPIN_INITIAL_1_0_REG_OFFSET + 4 * i) = spin_initial_1[i];
    }
}

// Configure h_rdata registers
static void lagd_configure_h_rdata(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    for (int i = 0; i < NUM_SPIN * BIT_H / 32; i++) {
        *reg32(base, LAGD_CORE_H_RDATA_0_REG_OFFSET + 4 * i) = model_h_data[i];
    }
}

// Compare the values in spin_fifo_data registers with the expected values and print the mismatch if
// any
static void lagd_check_spin_fifo_data(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);

    uint32_t spin_fifo_data_0[NUM_SPIN / 32], spin_fifo_data_1[NUM_SPIN / 32];
    for (int i = 0; i < NUM_SPIN / 32; i++) {
        spin_fifo_data_0[i] = *reg32(base, LAGD_CORE_SPIN_FIFO_DATA_0_0_REG_OFFSET + 4 * i);
        spin_fifo_data_1[i] = *reg32(base, LAGD_CORE_SPIN_FIFO_DATA_1_0_REG_OFFSET + 4 * i);
    }

    int pass0 = 1, pass1 = 1;
    for (int i = 0; i < NUM_SPIN / 32; i++) {
        if (spin_fifo_data_0[i] != spin_ref_0[i]) {
            pass0 = 0;
            break; // stop at the first mismatch
        }
    }
    for (int i = 0; i < NUM_SPIN / 32; i++) {
        if (spin_fifo_data_1[i] != spin_ref_1[i]) {
            pass1 = 0;
            break; // stop at the first mismatch
        }
    }

    printf("spin_fifo_data_0[%u]: %08x%08x%08x%08x%08x%08x%08x%08x ", core, spin_fifo_data_0[7],
           spin_fifo_data_0[6], spin_fifo_data_0[5], spin_fifo_data_0[4], spin_fifo_data_0[3],
           spin_fifo_data_0[2], spin_fifo_data_0[1], spin_fifo_data_0[0]);
    if (pass0) {
        printf("[PASS]\r\n");
    } else {
        printf("[FAIL] expected %08x%08x%08x%08x%08x%08x%08x%08x\r\n", spin_ref_0[7], spin_ref_0[6],
               spin_ref_0[5], spin_ref_0[4], spin_ref_0[3], spin_ref_0[2], spin_ref_0[1],
               spin_ref_0[0]);
    }

    printf("spin_fifo_data_1[%u]: %08x%08x%08x%08x%08x%08x%08x%08x ", core, spin_fifo_data_1[7],
           spin_fifo_data_1[6], spin_fifo_data_1[5], spin_fifo_data_1[4], spin_fifo_data_1[3],
           spin_fifo_data_1[2], spin_fifo_data_1[1], spin_fifo_data_1[0]);
    if (pass1) {
        printf("[PASS]\r\n");
    } else {
        printf("[FAIL] expected %08x%08x%08x%08x%08x%08x%08x%08x\r\n", spin_ref_1[7], spin_ref_1[6],
               spin_ref_1[5], spin_ref_1[4], spin_ref_1[3], spin_ref_1[2], spin_ref_1[1],
               spin_ref_1[0]);
    }
}
