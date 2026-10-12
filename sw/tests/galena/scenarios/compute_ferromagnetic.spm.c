// Copyright 2026 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Toon Bettens <toon.bettens@kuleuven.be>

// Ferromagnetic Ising problem computation

#ifndef CORE_TESTED
#define CORE_TESTED 0
#endif
#ifndef PROBLEM_SIZE
#define PROBLEM_SIZE 64
#endif
#ifndef PROBLEM_START
#define PROBLEM_START (NUM_SPIN - PROBLEM_SIZE)
#endif
#ifndef WWL_CYCLES
#define WWL_CYCLES 100
#endif
#ifndef SPIN_WRITE_CYCLES
#define SPIN_WRITE_CYCLES 100
#endif
#ifndef CYCLE_PER_READ
#define CYCLE_PER_READ 5
#endif
#ifndef READ_NUM
#define READ_NUM 1
#endif
#ifndef RANDOM_SEED
#define RANDOM_SEED 0xBBBBBBBB
#endif
#ifndef MARGIN
#define MARGIN 3
#endif

#include <stdint.h>
#include "printf.h"
#include "lagd_chip.h"
#include "lagd_bringup.h"
#include "lagd_galena_recipes.h"

static void print_spins_binary(const char *label, const uint32_t spins[LAGD_SPIN_NUM_WORDS], unsigned start, unsigned count) {
    printf("%s [%u, %u): ", label, start, start + count);
    for (unsigned i = start; i < start + count; i++)
        printf("%u", (spins[i / 32] >> (i % 32)) & 1u);
    printf("\r\n");
}

static uint32_t xorshift32(uint32_t *state) {
    uint32_t x = *state;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    *state = x;
    return x;
}

int main(void) {
    lagd_chip_init();

    lagd_core_apply_config(CORE_TESTED, &LAGD_BASE_CONFIG);
    galena_stage_wwl_timing(CORE_TESTED, WWL_CYCLES, WWL_CYCLES);
    galena_commit_dt_configure(CORE_TESTED);
    galena_stage_spin_write_timing(CORE_TESTED, SPIN_WRITE_CYCLES);
    galena_commit_spin_configure(CORE_TESTED);

    galena_zero_array(CORE_TESTED);
    uint32_t zero_spins[LAGD_SPIN_NUM_WORDS] = {0};
    galena_write_spins(CORE_TESTED, zero_spins);

    for (unsigned row = PROBLEM_START; row < PROBLEM_START + PROBLEM_SIZE; row++)
        galena_write_row_range(CORE_TESTED, row, /*value=*/-1, /*col_start=*/PROBLEM_START,
                               /*col_count=*/PROBLEM_SIZE);

    printf("programmed %ux%u-problem sub-block at spins [%u, %u), rest of array 0\r\n",
           PROBLEM_SIZE, PROBLEM_SIZE, PROBLEM_START, PROBLEM_START + PROBLEM_SIZE);

    unsigned count_ones = (unsigned)(PROBLEM_SIZE / 2 + MARGIN);
    unsigned char bits[PROBLEM_SIZE];
    for (unsigned i = 0; i < PROBLEM_SIZE; i++) bits[i] = (i < count_ones) ? 1 : 0;

    uint32_t rng_state = RANDOM_SEED;
    for (unsigned i = PROBLEM_SIZE - 1; i > 0; i--) {
        unsigned j = xorshift32(&rng_state) % (i + 1);
        unsigned char tmp = bits[i];
        bits[i] = bits[j];
        bits[j] = tmp;
    }

    uint32_t start_spins[LAGD_SPIN_NUM_WORDS] = {0};
    for (unsigned i = 0; i < PROBLEM_SIZE; i++)
        if (bits[i]) start_spins[(PROBLEM_START + i) / 32] |= (1u << ((PROBLEM_START + i) % 32));
    galena_write_spins(CORE_TESTED, start_spins);

    printf("spin cache loaded: shuffled %u ones / %u zeros (seed=0x%x) on spins [%u, %u), rest 0\r\n",
           count_ones, PROBLEM_SIZE - count_ones, RANDOM_SEED, PROBLEM_START,
           PROBLEM_START + PROBLEM_SIZE);

    uint32_t written[LAGD_SPIN_NUM_WORDS];
    galena_read_spins(CORE_TESTED, written);
    print_spins_binary("written", written, PROBLEM_START, PROBLEM_SIZE);

    unsigned mismatches = 0;
    for (unsigned i = 0; i < NUM_SPIN; i++) {
        unsigned expected = (start_spins[i / 32] >> (i % 32)) & 1u;
        unsigned actual = (written[i / 32] >> (i % 32)) & 1u;
        if (expected != actual) {
            printf("mismatch at spin %u: expected %u, got %u\r\n", i, expected, actual);
            mismatches++;
        }
    }
    if (mismatches)
        printf("WRITE CHECK FAIL (%u mismatches)\r\n", mismatches);
    else
        printf("WRITE CHECK PASS\r\n");

    uint32_t feedback[LAGD_SPIN_NUM_WORDS] = {0};
    for (unsigned i = PROBLEM_START; i < PROBLEM_START + PROBLEM_SIZE; i++)
        feedback[i / 32] |= (1u << (i % 32));
    galena_stage_spin_feedback_pattern(CORE_TESTED, feedback);
    galena_stage_spin_read_timing(CORE_TESTED, CYCLE_PER_READ, READ_NUM);
    galena_enable_spin_out(CORE_TESTED, 1);
    galena_commit_spin_configure(CORE_TESTED);

    printf("feedback enabled on spins [%u, %u)\r\n", PROBLEM_START, PROBLEM_START + PROBLEM_SIZE);

    galena_trigger_spin_read(CORE_TESTED);
    galena_poll_spin_read_idle(CORE_TESTED);

    uint32_t out[LAGD_SPIN_NUM_WORDS];
    galena_read_spin_out(CORE_TESTED, out);

    print_spins_binary("readout (feedback still enabled)", out, PROBLEM_START, PROBLEM_SIZE);

    printf("FINISH\r\n");

    lagd_chip_finish();
    return 0;
}
