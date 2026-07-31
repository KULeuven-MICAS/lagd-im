// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Header-only LAGD register configuration for dual-core computation.

#pragma once

#include "lagd_define.h"
#include "lagd_core_reg.h"
#include "model_j_data.h"
#include "model_j_data_sec.h"
#include "spin_data.h"
#include "spin_data_sec.h"

#define GCFG2_DGT_HSCALING(core) (((core) == 0) ? model_scaling_factor : model_scaling_factor_sec)

#include "lagd_reg_params.h"
// Included here, after GCFG2_DGT_HSCALING is defined, so that a test only has to include this
// header to get a consistent set
#include "lagd_common.h"
#include "util.h"
#include "printf.h"

// Configure initial spin registers for the given core index.
static void lagd_configure_initial_spins_dual(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    const uint32_t *spin_0 = (core == 0) ? spin_initial_0 : spin_initial_0_sec;
    const uint32_t *spin_1 = (core == 0) ? spin_initial_1 : spin_initial_1_sec;
    // Write initial spin set 0
    for (int i = 0; i < NUM_SPIN / 32; i++) {
        *reg32(base, LAGD_CORE_CONFIG_SPIN_INITIAL_0_0_REG_OFFSET + 4 * i) = spin_0[i];
    }
    // Write initial spin set 1
    for (int i = 0; i < NUM_SPIN / 32; i++) {
        *reg32(base, LAGD_CORE_CONFIG_SPIN_INITIAL_1_0_REG_OFFSET + 4 * i) = spin_1[i];
    }
}

// Configure h_rdata registers
static void lagd_configure_h_rdata_dual(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    const uint32_t *h_data = (core == 0) ? model_h_data : model_h_data_sec;

    for (int i = 0; i < NUM_SPIN * BIT_H / 32; i++) {
        *reg32(base, LAGD_CORE_H_RDATA_0_REG_OFFSET + 4 * i) = h_data[i];
    }
}

// Compare the values in spin_fifo_data registers against the model loaded on the given core and
// print the mismatch if any. Returns 0 when both sets match.
static int lagd_check_spin_fifo_data_dual(unsigned core) {
    const uint32_t *ref_0 = (core == 0) ? spin_ref_0 : spin_ref_0_sec;
    const uint32_t *ref_1 = (core == 0) ? spin_ref_1 : spin_ref_1_sec;
    return lagd_check_spin_fifo_data_ref(core, ref_0, ref_1);
}
