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
#include "spin_data.h"
#include "util.h"
#include "printf.h"

// Configure initial spin registers for the given core index.
static void lagd_configure_initial_spins(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR +
                          (uintptr_t)core * IC_NUM_REGS);
    // Write initial spin set 0
    for (int i = 0; i < 8; i++)
        *reg32(base, LAGD_CORE_CONFIG_SPIN_INITIAL_0_0_REG_OFFSET + 4 * i) = spin_initial_0[i];
    // Write initial spin set 1
    for (int i = 0; i < 8; i++)
        *reg32(base, LAGD_CORE_CONFIG_SPIN_INITIAL_1_0_REG_OFFSET + 4 * i) = spin_initial_1[i];
}
