// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Header-only LAGD register configuration for single-core computation.

#pragma once

#ifndef CORE_TESTED
#define CORE_TESTED 0
#endif

#include "lagd_define.h"
#include "lagd_core_reg.h"

#if CORE_TESTED == 0
#include "model_j_data.h"
#include "model_f_data.h"
#include "spin_data.h"
#define SC_SPIN_INITIAL_0 spin_initial_0
#define SC_SPIN_INITIAL_1 spin_initial_1
#define SC_MODEL_H_DATA   model_h_data
#define SC_SPIN_REF_0     spin_ref_0
#define SC_SPIN_REF_1     spin_ref_1
#define SC_SCALING_FACTOR model_scaling_factor
#else
#include "model_j_data_sec.h"
#include "model_f_data_sec.h"
#include "spin_data_sec.h"
#define SC_SPIN_INITIAL_0 spin_initial_0_sec
#define SC_SPIN_INITIAL_1 spin_initial_1_sec
#define SC_MODEL_H_DATA   model_h_data_sec
#define SC_SPIN_REF_0     spin_ref_0_sec
#define SC_SPIN_REF_1     spin_ref_1_sec
#define SC_SCALING_FACTOR model_scaling_factor_sec
#endif

// GCFG2_DGT_HSCALING(core) must be defined before lagd_reg_params.h
#define GCFG2_DGT_HSCALING(core) SC_SCALING_FACTOR

#include "lagd_reg_params.h"
#include "lagd_common.h"
#include "util.h"
#include "printf.h"

// The functions below configure the register block of the given core

// Configure initial spin registers for the given core index.
static void lagd_configure_initial_spins(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    // Write initial spin set 0
    for (int i = 0; i < NUM_SPIN / 32; i++) {
        *reg32(base, LAGD_CORE_CONFIG_SPIN_INITIAL_0_0_REG_OFFSET + 4 * i) = SC_SPIN_INITIAL_0[i];
    }
    // Write initial spin set 1
    for (int i = 0; i < NUM_SPIN / 32; i++) {
        *reg32(base, LAGD_CORE_CONFIG_SPIN_INITIAL_1_0_REG_OFFSET + 4 * i) = SC_SPIN_INITIAL_1[i];
    }
}

// Configure h_rdata registers
static void lagd_configure_h_rdata(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    for (int i = 0; i < NUM_SPIN * BIT_H / 32; i++) {
        *reg32(base, LAGD_CORE_H_RDATA_0_REG_OFFSET + 4 * i) = SC_MODEL_H_DATA[i];
    }
}

// Compare the values in spin_fifo_data registers against the model of CORE_TESTED and print the
// mismatch if any. Returns 0 when both sets match.
static int lagd_check_spin_fifo_data(unsigned core) {
    return lagd_check_spin_fifo_data_ref(core, SC_SPIN_REF_0, SC_SPIN_REF_1);
}
