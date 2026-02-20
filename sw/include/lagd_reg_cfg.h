// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Header-only LAGD register configuration.
// Include this in your test program and call lagd_configure_regs().
// UART must be initialized before calling this function.

#pragma once

#include "lagd_params.h"
#include "lagd_core_reg.h"
#include "spin_data.h"
#include "util.h"
#include "printf.h"

// Configure initial spin registers for core 0.
// Writes spin_initial_0 -> CONFIG_SPIN_INITIAL_0_* (word[0] -> _0_REG_OFFSET, ...)
// Writes spin_initial_1 -> CONFIG_SPIN_INITIAL_1_* (word[0] -> _0_REG_OFFSET, ...)
static void lagd_configure_regs(void) {
    printf("=== LAGD Register Configuration ===\r\n");

    // Write initial spin set 0
    for (int i = 0; i < 8; i++)
        *reg32(&__base_lagd_regs,
               LAGD_CORE_CONFIG_SPIN_INITIAL_0_0_REG_OFFSET + 4 * i) = spin_initial_0[i];
    printf("spin_initial_0      : written to CONFIG_SPIN_INITIAL_0_[0..7]\r\n");

    // Write initial spin set 1
    for (int i = 0; i < 8; i++)
        *reg32(&__base_lagd_regs,
               LAGD_CORE_CONFIG_SPIN_INITIAL_1_0_REG_OFFSET + 4 * i) = spin_initial_1[i];
    printf("spin_initial_1      : written to CONFIG_SPIN_INITIAL_1_[0..7]\r\n");

}
