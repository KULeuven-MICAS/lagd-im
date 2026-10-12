// Copyright 2026 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Toon Bettens <toon.bettens@kuleuven.be>

// N=2 sanity check for the compute/feedback path, and the first step of the galena_single_well
// ladder item: couple two spins with a single J value (both signs tried), seed all four possible
// initial states, run feedback+read via galena_compute_and_read_spins, and print before/after so
// a human can read off which sign of J actually drives the pair toward agreement on this chip --
// neither the RTL doc nor the ladder notes say which sign is "ferromagnetic" here, so this
// establishes that empirically before generalizing to an arbitrary-size single-well test.

#ifndef CORE_TESTED
#define CORE_TESTED 0
#endif
#ifndef SPIN_A
#define SPIN_A 0
#endif
#ifndef SPIN_B
#define SPIN_B 1
#endif
#ifndef J_MAGNITUDE
#define J_MAGNITUDE 5
#endif
#ifndef WWL_CYCLES
#define WWL_CYCLES 100
#endif
#ifndef SPIN_WRITE_CYCLES
#define SPIN_WRITE_CYCLES 5
#endif
#ifndef FEEDBACK_CYCLE_PER_READ
#define FEEDBACK_CYCLE_PER_READ 1
#endif
#ifndef FEEDBACK_READ_NUM
#define FEEDBACK_READ_NUM 100
#endif

#include <stdint.h>
#include "printf.h"
#include "lagd_chip.h"
#include "lagd_bringup.h"
#include "lagd_galena_recipes.h"

static const int INITIAL_STATES[4][2] = {{0, 0}, {1, 1}, {0, 1}, {1, 0}};

static void set_pair(uint32_t spins[LAGD_SPIN_NUM_WORDS], int val_a, int val_b) {
    for (unsigned i = 0; i < LAGD_SPIN_NUM_WORDS; i++) spins[i] = 0;
    if (val_a) spins[SPIN_A / 32] |= (1u << (SPIN_A % 32));
    if (val_b) spins[SPIN_B / 32] |= (1u << (SPIN_B % 32));
}

static void run_trial(unsigned core, int j_value, int init_a, int init_b) {
    galena_zero_array(core);
    galena_write_cu(core, SPIN_A, SPIN_B, j_value);
    galena_write_cu(core, SPIN_B, SPIN_A, j_value);

    uint32_t spins[LAGD_SPIN_NUM_WORDS];
    set_pair(spins, init_a, init_b);
    galena_write_spins(core, spins);

    uint32_t out[LAGD_SPIN_NUM_WORDS];
    galena_compute_and_read_spins(core, FEEDBACK_CYCLE_PER_READ, FEEDBACK_READ_NUM, out);

    unsigned a_after = (out[SPIN_A / 32] >> (SPIN_A % 32)) & 1u;
    unsigned b_after = (out[SPIN_B / 32] >> (SPIN_B % 32)) & 1u;

    printf("J=%+d init=(%d,%d) -> final=(%u,%u) %s\r\n", j_value, init_a, init_b, a_after, b_after,
          (a_after == b_after) ? "AGREE" : "DISAGREE");
}

int main(void) {
    lagd_chip_init();

    lagd_core_apply_config(CORE_TESTED, &LAGD_BASE_CONFIG);
    galena_stage_wwl_timing(CORE_TESTED, WWL_CYCLES, WWL_CYCLES);
    galena_commit_dt_configure(CORE_TESTED);
    galena_stage_spin_write_timing(CORE_TESTED, SPIN_WRITE_CYCLES);
    galena_commit_spin_configure(CORE_TESTED);

    printf("spins %u/%u, |J|=%u, feedback ~%u cycles:\r\n", SPIN_A, SPIN_B, J_MAGNITUDE,
          FEEDBACK_CYCLE_PER_READ * FEEDBACK_READ_NUM);

    for (unsigned sign = 0; sign < 2; sign++) {
        int j_value = sign ? -J_MAGNITUDE : J_MAGNITUDE;
        for (unsigned i = 0; i < 4; i++)
            run_trial(CORE_TESTED, j_value, INITIAL_STATES[i][0], INITIAL_STATES[i][1]);
    }

    lagd_chip_finish();
    return 0;
}
