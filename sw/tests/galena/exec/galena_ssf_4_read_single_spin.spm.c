// Copyright 2026 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Toon Bettens <toon.bettens@kuleuven.be>

// Step 4/4 of the single-spin-feedback procedure: read back the current spin_feedback_cfg first
// (sanity check -- chip_reset.py runs before every UART load, so this confirms whether step 3's
// staged single-spin feedback actually survived, or whether it reverted to its reset default),
// then trigger a read driven for CYCLE_PER_READ*READ_NUM cycles and print the resulting spins.
// Deliberately does NOT restage feedback -- whatever's currently in spin_feedback_cfg (from step
// 3, or its reset default if that didn't survive) is what drives this read.

#ifndef CORE_TESTED
#define CORE_TESTED 0
#endif
#ifndef CYCLE_PER_READ
#define CYCLE_PER_READ 5
#endif
#ifndef READ_NUM
#define READ_NUM 5
#endif

#include <stdint.h>
#include "printf.h"
#include "lagd_chip.h"
#include "lagd_bringup.h"
#include "lagd_galena_recipes.h"

int main(void) {
    lagd_chip_init();

    lagd_core_apply_config(CORE_TESTED, &LAGD_BASE_CONFIG);

    uint32_t feedback_now[LAGD_SPIN_NUM_WORDS];
    lagd_core_read_vector(CORE_TESTED, LAGD_CORE_SPIN_FEEDBACK_CFG_0_REG_OFFSET, feedback_now,
                          LAGD_SPIN_NUM_WORDS);
    printf("spin_feedback_cfg (before read):");
    for (unsigned i = 0; i < LAGD_SPIN_NUM_WORDS; i++) printf(" %08x", feedback_now[i]);
    printf("\r\n");

    galena_stage_spin_read_timing(CORE_TESTED, CYCLE_PER_READ, READ_NUM);
    galena_enable_spin_out(CORE_TESTED, 1);
    galena_commit_spin_configure(CORE_TESTED);

    galena_trigger_spin_read(CORE_TESTED);
    galena_poll_spin_read_idle(CORE_TESTED);

    uint32_t spins[LAGD_SPIN_NUM_WORDS];
    galena_read_spin_out(CORE_TESTED, spins);

    printf("spins:");
    for (unsigned i = 0; i < LAGD_SPIN_NUM_WORDS; i++) printf(" %08x", spins[i]);
    printf("\r\n");
    printf("PASS\r\n");

    lagd_chip_finish();
    return 0;
}
