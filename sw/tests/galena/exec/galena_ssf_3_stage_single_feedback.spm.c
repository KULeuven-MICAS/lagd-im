// Copyright 2026 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Toon Bettens <toon.bettens@kuleuven.be>

// Step 3/4 of the single-spin-feedback procedure: turn feedback on for exactly SPIN_INDEX,
// leaving every other spin's feedback line low, then read the spin_feedback_cfg register straight
// back and print it, so you can confirm only that one bit actually got set before moving on.

#ifndef CORE_TESTED
#define CORE_TESTED 0
#endif
#ifndef SPIN_INDEX
#define SPIN_INDEX 0
#endif

#include <stdint.h>
#include "printf.h"
#include "lagd_chip.h"
#include "lagd_bringup.h"
#include "lagd_galena_recipes.h"

int main(void) {
    lagd_chip_init();

    lagd_core_apply_config(CORE_TESTED, &LAGD_BASE_CONFIG);

    uint32_t feedback[LAGD_SPIN_NUM_WORDS] = {0};
    feedback[SPIN_INDEX / 32] |= (1u << (SPIN_INDEX % 32));
    galena_stage_spin_feedback_pattern(CORE_TESTED, feedback);
    galena_commit_spin_configure(CORE_TESTED);

    uint32_t readback[LAGD_SPIN_NUM_WORDS];
    lagd_core_read_vector(CORE_TESTED, LAGD_CORE_SPIN_FEEDBACK_CFG_0_REG_OFFSET, readback,
                          LAGD_SPIN_NUM_WORDS);

    printf("spin_feedback_cfg (spin %u staged on):", SPIN_INDEX);
    for (unsigned i = 0; i < LAGD_SPIN_NUM_WORDS; i++) printf(" %08x", readback[i]);
    printf("\r\n");
    printf("PASS\r\n");

    lagd_chip_finish();
    return 0;
}
