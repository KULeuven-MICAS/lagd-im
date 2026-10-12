// Copyright 2026 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Toon Bettens <toon.bettens@kuleuven.be>

// Write a pattern to every spin cell and exit -- no readback, no checking.
// TODO: take the pattern as a parameter; hardcoded to all-one for now.

#ifndef CORE_TESTED
#define CORE_TESTED 0
#endif
#ifndef SPIN_WRITE_CYCLES
#define SPIN_WRITE_CYCLES 100
#endif

#include <stdint.h>
#include "printf.h"
#include "lagd_chip.h"
#include "lagd_bringup.h"
#include "lagd_galena_recipes.h"

int main(void) {
    lagd_chip_init();

    lagd_core_apply_config(CORE_TESTED, &LAGD_BASE_CONFIG);
    galena_stage_spin_write_timing(CORE_TESTED, SPIN_WRITE_CYCLES);
    galena_commit_spin_configure(CORE_TESTED);

    uint32_t spins[LAGD_SPIN_NUM_WORDS];
    for (unsigned i = 0; i < LAGD_SPIN_NUM_WORDS; i++) spins[i] = 0xFFFFFFFFu;
    galena_write_spins(CORE_TESTED, spins);

    printf("spins written:");
    for (unsigned i = 0; i < LAGD_SPIN_NUM_WORDS; i++) printf(" %08x", spins[i]);

    lagd_chip_finish();
    return 0;
}
