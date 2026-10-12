// Copyright 2026 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Toon Bettens <toon.bettens@kuleuven.be>

// Bare-minimum spin readback: trigger a single spin read and print it. Deliberately does NOT
// stage spin_feedback (or anything else galena-input-side) -- whatever feedback/other config is
// currently sitting on the chip is left exactly as-is, so this doesn't perturb the thing under
// investigation. Only the plumbing strictly required to get a read to complete is touched (read
// timing counters, and enabling the spin_out CSR mirror).

#ifndef CORE_TESTED
#define CORE_TESTED 0
#endif
#ifndef CYCLE_PER_READ
#define CYCLE_PER_READ 5
#endif

#include <stdint.h>
#include "printf.h"
#include "lagd_chip.h"
#include "lagd_bringup.h"
#include "lagd_galena_recipes.h"

int main(void) {
    lagd_chip_init();

    lagd_core_apply_config(CORE_TESTED, &LAGD_BASE_CONFIG);

    galena_stage_spin_read_timing(CORE_TESTED, /*cycle_per_read=*/CYCLE_PER_READ, /*read_num=*/5);
    galena_enable_spin_out(CORE_TESTED, 1);
    galena_commit_spin_configure(CORE_TESTED);

    galena_trigger_spin_read(CORE_TESTED);
    galena_poll_spin_read_idle(CORE_TESTED);

    uint32_t spins[LAGD_SPIN_NUM_WORDS];
    galena_read_spin_out(CORE_TESTED, spins);

    // MSB-first (word[7]=spins 255:224 ... word[0]=spins 31:0), so the leftmost hex digit's MSB is
    // the highest spin and the rightmost digit's LSB is spin 0.
    printf("spins: ");
    for (int i = LAGD_SPIN_NUM_WORDS - 1; i >= 0; i--) printf("%08x", spins[i]);
    printf("\r\n");

    lagd_chip_finish();
    return 0;
}
