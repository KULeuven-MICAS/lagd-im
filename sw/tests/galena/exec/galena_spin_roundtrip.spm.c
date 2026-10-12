// Copyright 2026 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Toon Bettens <toon.bettens@kuleuven.be>

// Write a spin pattern, read it back, and say what stuck -- twice, once with all-zeros and once
// with all-ones. Everything goes through the same debug routes the other scenarios use:
// galena_write_spins to write, galena_read_spins to read.
//
// WHY BOTH DIRECTIONS. The two are not symmetric on this die. Clearing a spin works; setting one
// often does not, and the failures grow with hardware index. Running zeros first and ones second
// separates the two: after the zero phase the cache is known-clear, so every mismatch in the ones
// phase is a bit that would not SET, and any spin still high after the zero phase is genuinely
// stuck rather than a write that did not take.
//
// Nothing here needs a problem loaded -- it only touches the spin cache, not the J array.

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

// Hardware order: spin 0 is the leftmost digit's most significant bit, grouped in 32s.
static void print_hex(const uint32_t s[LAGD_SPIN_NUM_WORDS]) {
    for (unsigned d = 0; d < NUM_SPIN / 4; d++) {
        unsigned nib = 0;
        for (unsigned b = 0; b < 4; b++) {
            unsigned i = d * 4 + b;
            nib = (nib << 1) | ((s[i / 32] >> (i % 32)) & 1u);
        }
        printf("%x", nib);
        if ((d & 7u) == 7u && d + 1 < NUM_SPIN / 4) printf(" ");
    }
}

// Write `want`, read it back, print both plus the diff. Returns the mismatch count.
static unsigned phase(const char *name, uint32_t fill) {
    uint32_t want[LAGD_SPIN_NUM_WORDS], got[LAGD_SPIN_NUM_WORDS], diff[LAGD_SPIN_NUM_WORDS];
    for (unsigned w = 0; w < LAGD_SPIN_NUM_WORDS; w++) want[w] = fill;

    galena_write_spins(CORE_TESTED, want);
    galena_read_spins(CORE_TESTED, got);

    unsigned bad = 0;
    unsigned bucket[4] = {0, 0, 0, 0};
    for (unsigned w = 0; w < LAGD_SPIN_NUM_WORDS; w++) diff[w] = want[w] ^ got[w];
    for (unsigned i = 0; i < NUM_SPIN; i++)
        if ((diff[i / 32] >> (i % 32)) & 1u) {
            bad++;
            bucket[i / 64]++;
        }

    printf("--- %s ---\r\n", name);
    printf("  wrote : ");
    print_hex(want);
    printf("\r\n");
    printf("  read  : ");
    print_hex(got);
    printf("\r\n");
    printf("  diff  : ");
    print_hex(diff);
    printf("\r\n");
    printf("  %u of %u differ   [0-63]=%u [64-127]=%u [128-191]=%u [192-255]=%u   %s\r\n", bad,
           (unsigned)NUM_SPIN, bucket[0], bucket[1], bucket[2], bucket[3], bad ? "FAIL" : "ok");
    return bad;
}

int main(void) {
    lagd_chip_init();

    printf("=== SPIN ROUND TRIP (debug write, debug read) ===\r\n");
    printf("core=%u spins=%u spin_write_cycles=%u\r\n", (unsigned)CORE_TESTED, (unsigned)NUM_SPIN,
           (unsigned)SPIN_WRITE_CYCLES);
    printf("hex is HARDWARE order, spin 0 in the leftmost digit's MSB\r\n");

    lagd_core_apply_config(CORE_TESTED, &LAGD_BASE_CONFIG);
    galena_stage_spin_write_timing(CORE_TESTED, SPIN_WRITE_CYCLES);
    galena_commit_spin_configure(CORE_TESTED);

    unsigned bad_zero = phase("all zeros", 0x00000000u);
    unsigned bad_ones = phase("all ones", 0xFFFFFFFFu);

    printf("--- summary ---\r\n");
    printf("  clearing: %u stuck high\r\n", bad_zero);
    printf("  setting : %u would not set\r\n", bad_ones);
    printf("%s\r\n", (bad_zero == 0 && bad_ones == 0) ? "PASS" : "FAIL");

    printf("FINISH\r\n");
    lagd_chip_finish();
    return 0;
}
