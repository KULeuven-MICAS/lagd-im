// Copyright 2026 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Toon Bettens <toon.bettens@kuleuven.be>

// Write a single spin (SPIN_INDEX) to VALUE and exit -- no readback, no checking. Uses the spin
// path's per-spin strobe (galena_write_single_spin), so every other spin's stored value is left
// untouched.
//
// ACC_WRITE (default 0): when set to 1, forces wbl[4*SPIN_INDEX] high regardless of VALUE -- i.e.
// a VALUE=0 write still drives that WBL bit to 1 instead of 0.

#ifndef CORE_TESTED
#define CORE_TESTED 0
#endif
#ifndef SPIN_INDEX
#define SPIN_INDEX 0
#endif
#ifndef VALUE
#define VALUE 1
#endif
#ifndef ACC_WRITE
#define ACC_WRITE 0
#endif
#ifndef SPIN_WRITE_CYCLES
#define SPIN_WRITE_CYCLES 5
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

    uint32_t wbl[LAGD_WBL_NUM_WORDS] = {0};
    unsigned bit = BIT_H * SPIN_INDEX + SPIN_WBL_OFFSET;
    if (VALUE || ACC_WRITE) wbl[bit / 32] |= (1u << (bit % 32));

    galena_write_single_spin_raw(CORE_TESTED, SPIN_INDEX, wbl);

    printf("wrote spin %u (VALUE=%d, ACC_WRITE=%d): wbl bit %u = %u\r\n", SPIN_INDEX, VALUE,
          ACC_WRITE, bit, (wbl[bit / 32] >> (bit % 32)) & 1u);
    printf("PASS\r\n");

    lagd_chip_finish();
    return 0;
}
