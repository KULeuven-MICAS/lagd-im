// Copyright 2026 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Toon Bettens <toon.bettens@kuleuven.be>

// Same bare-minimum single spin readback as galena_read_spins.spm.c, but via the OTHER readback
// mechanism: a direct L1 flip-mem read of the triggered sample (galena_read_spin_flip_mem),
// instead of the spin_out CSR mirror (galena_read_spin_out). Every triggered spin read is written
// into L1 flip memory unconditionally, so sample index 0 is valid right after this one read.
// Deliberately does NOT stage spin_feedback (or anything else galena-input-side) -- whatever
// feedback/other config is currently sitting on the chip is left exactly as-is.

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

    galena_stage_spin_read_timing(CORE_TESTED, /*cycle_per_read=*/CYCLE_PER_READ, /*read_num=*/1);
    galena_commit_spin_configure(CORE_TESTED);

    galena_trigger_spin_read(CORE_TESTED);
    galena_poll_spin_read_idle(CORE_TESTED);

    uint32_t spins[LAGD_SPIN_NUM_WORDS];
    galena_read_spin_flip_mem(CORE_TESTED, /*index=*/0, spins);

    printf("spins (flip-mem):");
    for (unsigned i = 0; i < LAGD_SPIN_NUM_WORDS; i++) printf(" %08x", spins[i]);
    printf("\r\n");

    lagd_chip_finish();
    return 0;
}
