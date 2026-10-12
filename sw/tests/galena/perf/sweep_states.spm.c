// Copyright 2026 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Toon Bettens <toon.bettens@kuleuven.be>

// Sweep one problem over many start states, in one ELF.
//
// load_and_monitor, repeated: J and h are written once, then for each state the spins are
// written, read back and checked, and a monitored run is captured. State 0 is the one that came
// through L1; the rest are random over the active spins. Everything prints.

#ifndef CORE_TESTED
#define CORE_TESTED 0
#endif

// --- sweep ------------------------------------------------------------------
// States to try, state 0 being REFMODEL_INITIAL. 1..
#ifndef STATE_COUNT
#define STATE_COUNT 5
#endif
// PRNG seed for states 1.. (any non-zero value). Same seed -> same sweep.
#ifndef STATE_SEED
#define STATE_SEED 0x1234567u
#endif
// Randomise all NUM_SPIN spins rather than only the problem's. Padding has no couplings.
#ifndef STATE_ALL
#define STATE_ALL 0
#endif

// Write each state and read it straight back, no monitored run at all. The narrowest possible
// check that distinct states reach the array: nothing else runs, so nothing else can explain a
// result. 1 = do this and stop.
#ifndef WRITE_ONLY
#define WRITE_ONLY 0
#endif
// Make every state a full load_and_monitor: re-apply the core config, zero the array and rewrite
// J and h before the spins, instead of loading the problem once for the whole sweep. The closest
// this scenario can get to starting each state from scratch -- there is no core reset available
// from software, so re-applying the config is the whole of "reset".
#ifndef FULL_RELOAD
#define FULL_RELOAD 0
#endif
// Read state n's samples starting at slot n*SAMPLE_COUNT instead of slot 0. Tests whether the
// capture write pointer keeps counting across bursts rather than restarting: the flip memory
// holds FLIP_ICON_DEPTH icons and a sweep uses only SAMPLE_COUNT of them, so a free-running
// pointer would leave burst 0 at slots 0.., burst 1 at SAMPLE_COUNT.., and so on.
#ifndef SLOTS_PER_BURST
#define SLOTS_PER_BURST 0
#endif
// Barrel roll: how far to slide the whole problem around the array between states. State n sits
// at hardware index (canonical + n*ROLL_STEP) mod NUM_SPIN, so a given logical spin visits a
// different cell every run and no result can be an artefact of one column. J, h, the start state
// and the feedback mask all move together; samples are rolled back before scoring, so energies
// stay directly comparable. 0 disables (everything stays where it is today).
#ifndef ROLL_STEP
#define ROLL_STEP 0
#endif
// Smallest Hamming distance, in spins, between a state and the one before it. Random states over
// n spins sit around n/2 apart already; this rejects and redraws anything closer, so "the states
// were too alike" is never the explanation for identical results.
#ifndef MIN_STATE_DISTANCE
#define MIN_STATE_DISTANCE 30
#endif

// --- load phase -------------------------------------------------------------
#ifndef WWL_CYCLES
#define WWL_CYCLES 100
#endif
#ifndef SPIN_WRITE_CYCLES
#define SPIN_WRITE_CYCLES 100
#endif
// Negate before encoding, matching the reference encoder's sign convention.
#ifndef INVERT_J
#define INVERT_J 1
#endif
#ifndef INVERT_H
#define INVERT_H 1
#endif

// --- monitor phase ----------------------------------------------------------
// Snapshots per state (1..FLIP_ICON_DEPTH). Every state prints this many rows.
#ifndef SAMPLE_COUNT
#define SAMPLE_COUNT 32
#endif
// Cycles between samples, and equally the delay to the FIRST one. True spacing is this plus one.
// 1 is what load_and_monitor captures 128 clean samples with, so it is the known-good value.
#ifndef SAMPLE_INTERVAL
#define SAMPLE_INTERVAL 1
#endif
// Feedback-only settle before sampling, in cycles. 0 starts sampling immediately.
#ifndef WARMUP_CYCLES
#define WARMUP_CYCLES 0
#endif
// Hold feedback on every spin rather than only the problem's.
#ifndef FEEDBACK_ALL
#define FEEDBACK_ALL 0
#endif

#include <stdint.h>
#include "printf.h"
#include "lagd_chip.h"
#include "lagd_bringup.h"
#include "lagd_galena_recipes.h"
#include "lagd_l1_model.h"

#if STATE_COUNT < 1
#error "STATE_COUNT must be at least 1"
#endif
#if SAMPLE_COUNT < 1 || SAMPLE_COUNT > FLIP_ICON_DEPTH
#error "SAMPLE_COUNT must be 1..FLIP_ICON_DEPTH"
#endif
#if STATE_SEED == 0
#error "STATE_SEED must be non-zero"
#endif

// This core's L1 flip memory: sample k starts at word k*LAGD_SPIN_NUM_WORDS.
static volatile uint32_t *flip_mem(unsigned core) {
    return (volatile uint32_t *)((uintptr_t)IC_MEM_BASE_ADDR +
                                 (uintptr_t)core * IC_L1_MEM_SIZE_B + (uintptr_t)L1_J_MEM_SIZE_B);
}

static void read_sample(unsigned core, unsigned index, uint32_t out[LAGD_SPIN_NUM_WORDS]) {
    volatile uint32_t *flip = flip_mem(core);
    for (unsigned w = 0; w < LAGD_SPIN_NUM_WORDS; w++)
        out[w] = flip[index * LAGD_SPIN_NUM_WORDS + w];
}

// xorshift32: the sweep has to be reproducible off-chip, so no library RNG.
static uint32_t rng = STATE_SEED;
static uint32_t next_rand(void) {
    rng ^= rng << 13;
    rng ^= rng >> 17;
    rng ^= rng << 5;
    return rng;
}

// Number of differing spins between two hardware-order vectors.
static unsigned distance(const uint32_t a[LAGD_SPIN_NUM_WORDS],
                         const uint32_t b[LAGD_SPIN_NUM_WORDS]) {
    unsigned d = 0;
    for (unsigned w = 0; w < LAGD_SPIN_NUM_WORDS; w++) {
        uint32_t x = a[w] ^ b[w];
        while (x) {
            d += x & 1u;
            x >>= 1;
        }
    }
    return d;
}

// --- barrel roll ------------------------------------------------------------
// The roll is a pure relabelling of hardware cells: hardware index h holds what canonically
// belongs at h - roll. Everything written to the array goes through roll_vector(); everything
// read back comes through unroll_vector() before it is printed or scored, so the rest of the
// program -- and lagd_l1_model.h -- never sees the roll at all.

static unsigned roll_of(unsigned n) {
    return ((unsigned)ROLL_STEP * n) % (unsigned)NUM_SPIN;
}

// Hardware cell holding logical spin i for this roll.
static unsigned rolled_hw(unsigned logical, unsigned roll) {
    return (refmodel_hw(logical) + roll) % (unsigned)NUM_SPIN;
}

static void roll_vector(const uint32_t in[LAGD_SPIN_NUM_WORDS], unsigned roll,
                        uint32_t out[LAGD_SPIN_NUM_WORDS]) {
    for (unsigned w = 0; w < LAGD_SPIN_NUM_WORDS; w++) out[w] = 0;
    for (unsigned h = 0; h < NUM_SPIN; h++)
        if ((in[h / 32] >> (h % 32)) & 1u) {
            unsigned t = (h + roll) % (unsigned)NUM_SPIN;
            out[t / 32] |= (1u << (t % 32));
        }
}

static void unroll_vector(const uint32_t in[LAGD_SPIN_NUM_WORDS], unsigned roll,
                          uint32_t out[LAGD_SPIN_NUM_WORDS]) {
    roll_vector(in, ((unsigned)NUM_SPIN - roll) % (unsigned)NUM_SPIN, out);
}

// Write J and h at this roll. Rows and columns move together, so the problem is unchanged --
// only which cells hold it. The h row is a dedicated selector, not a logical row, so it keeps
// its own index and only its columns move.
static void write_problem(unsigned core, unsigned roll, int hw_values[NUM_SPIN]) {
    for (unsigned i = 0; i < REFMODEL_SIZE; i++) {
        for (unsigned c = 0; c < NUM_SPIN; c++) hw_values[c] = 0;
        for (unsigned c = 0; c < REFMODEL_SIZE; c++) {
            int v = refmodel_j(i, c);
            hw_values[rolled_hw(c, roll)] = INVERT_J ? -v : v;
        }
        galena_write_row_values(core, rolled_hw(i, roll), hw_values, 0, NUM_SPIN);
    }
    for (unsigned c = 0; c < NUM_SPIN; c++) hw_values[c] = 0;
    for (unsigned c = 0; c < REFMODEL_SIZE; c++) {
        int v = refmodel_h(c);
        hw_values[rolled_hw(c, roll)] = INVERT_H ? -v : v;
    }
    galena_write_row_values(core, NUM_SPIN, hw_values, 0, NUM_SPIN);
}

// State n into hardware bit order. n == 0 is the one from L1; the rest
// are random over the active spins, redrawn until at least MIN_STATE_DISTANCE spins away from the
// previous state so consecutive runs are never near-copies of each other.
static void make_state(unsigned n, const uint32_t prev[LAGD_SPIN_NUM_WORDS],
                       uint32_t out[LAGD_SPIN_NUM_WORDS]) {
    for (unsigned w = 0; w < LAGD_SPIN_NUM_WORDS; w++) out[w] = 0;
    if (n == 0) {
        for (unsigned w = 0; w < LAGD_SPIN_NUM_WORDS; w++) out[w] = REFMODEL_INITIAL[w];
        return;
    }
    unsigned span = STATE_ALL ? (unsigned)NUM_SPIN : refmodel_size();
    for (unsigned attempt = 0; attempt < 64; attempt++) {
        for (unsigned w = 0; w < LAGD_SPIN_NUM_WORDS; w++) out[w] = 0;
        for (unsigned i = 0; i < span; i++)
            if (next_rand() & 1u) {
                unsigned h = refmodel_hw(i);
                out[h / 32] |= (1u << (h % 32));
            }
        if (n == 0 || distance(out, prev) >= (unsigned)MIN_STATE_DISTANCE) return;
    }
    printf("note: state %u never got %u spins away from the previous one\r\n", n,
           (unsigned)MIN_STATE_DISTANCE);
}

static void configure_core(unsigned core) {
    lagd_core_apply_config(core, &LAGD_BASE_CONFIG);
    galena_stage_wwl_timing(core, WWL_CYCLES, WWL_CYCLES);
    galena_commit_dt_configure(core);
    galena_stage_spin_write_timing(core, SPIN_WRITE_CYCLES);
    galena_commit_spin_configure(core);
}

int main(void) {
    lagd_chip_init();

    printf("=== STATE SWEEP ===\r\n");
    printf("core=%u spins=%u (problem occupies %u) invert_j=%u invert_h=%u\r\n",
           (unsigned)CORE_TESTED, (unsigned)REFMODEL_SIZE, (unsigned)refmodel_size(),
           (unsigned)INVERT_J, (unsigned)INVERT_H);
    printf("states=%u seed=0x%08x over %s\r\n", (unsigned)STATE_COUNT, (unsigned)STATE_SEED,
           STATE_ALL ? "all spins" : "problem only");
    printf("full reload=%u, roll step=%u cells per state, min state distance=%u spins%s\r\n",
           (unsigned)FULL_RELOAD,
           (unsigned)ROLL_STEP, (unsigned)MIN_STATE_DISTANCE,
           WRITE_ONLY ? "  [WRITE+READBACK ONLY]" : "");
    printf("samples=%u interval=%u cycles warmup=%u cycles feedback=%s\r\n",
           (unsigned)SAMPLE_COUNT, (unsigned)(SAMPLE_INTERVAL + 1), (unsigned)WARMUP_CYCLES,
           FEEDBACK_ALL ? "all spins" : "problem only");
    printf("J at 0x%08x, checksum 0x%08x (compare with the generator's)\r\n",
           (unsigned)(uintptr_t)REFMODEL_J, (unsigned)refmodel_j_checksum());

    configure_core(CORE_TESTED);

    // Clean slate: the array keeps its contents across runs.
    galena_zero_array(CORE_TESTED);
    uint32_t zero[LAGD_SPIN_NUM_WORDS] = {0};
    galena_write_spins(CORE_TESTED, zero);

    // ---- load J and h ------------------------------------------------------
    // Without a roll this happens once; with one the problem is rewritten per state, since it
    // occupies different cells each time.
    int hw_values[NUM_SPIN];
    if (!ROLL_STEP && !FULL_RELOAD) {
        write_problem(CORE_TESTED, 0, hw_values);
        printf("LOADED\r\n");
    }

    // Canonical feedback mask, rolled per state alongside the problem.
    uint32_t feedback0[LAGD_SPIN_NUM_WORDS] = {0};
    for (unsigned i = 0; i < NUM_SPIN; i++)
        if (FEEDBACK_ALL || i < refmodel_size())
            feedback0[refmodel_hw(i) / 32] |= (1u << (refmodel_hw(i) % 32));

    // ---- sweep -------------------------------------------------------------
    uint32_t prev_want[LAGD_SPIN_NUM_WORDS] = {0}, prev_got[LAGD_SPIN_NUM_WORDS] = {0};
    int sweep_best = 0;
    unsigned sweep_best_state = 0;
    unsigned total_bad = 0;

    for (unsigned n = 0; n < STATE_COUNT; n++) {
        uint32_t want[LAGD_SPIN_NUM_WORDS], got[LAGD_SPIN_NUM_WORDS];
        make_state(n, prev_want, want);

        // Everything below is canonical; only the array sees the roll.
        unsigned roll = roll_of(n);
        uint32_t rolled_want[LAGD_SPIN_NUM_WORDS], rolled_got[LAGD_SPIN_NUM_WORDS];
        uint32_t feedback[LAGD_SPIN_NUM_WORDS];
        roll_vector(feedback0, roll, feedback);
        roll_vector(want, roll, rolled_want);
        // A roll moves the problem to different cells, so it must be rewritten either way.
        if (ROLL_STEP || FULL_RELOAD) {
            if (FULL_RELOAD) configure_core(CORE_TESTED);
            galena_zero_array(CORE_TESTED);
            write_problem(CORE_TESTED, roll, hw_values);
        }

        // Clear first: the write clears reliably but does not always set, so a leftover 1 from
        // the previous state would otherwise survive into this one.
        galena_write_spins(CORE_TESTED, zero);
        galena_write_spins(CORE_TESTED, rolled_want);
        galena_read_spins(CORE_TESTED, rolled_got);
        unroll_vector(rolled_got, roll, got);

        uint32_t diff[LAGD_SPIN_NUM_WORDS];
        unsigned bad = 0;
        unsigned bucket[4] = {0, 0, 0, 0};
        for (unsigned w = 0; w < LAGD_SPIN_NUM_WORDS; w++) diff[w] = want[w] ^ got[w];
        for (unsigned i = 0; i < NUM_SPIN; i++)
            if ((diff[i / 32] >> (i % 32)) & 1u) {
                bad++;
                bucket[i / 64]++;
            }
        total_bad += bad;

        printf("=== state %u/%u  roll=%u ===\r\n", n, (unsigned)STATE_COUNT, roll);
        refmodel_print_state("wanted", want);
        refmodel_print_state("onchip", got);
        printf("  %-7s: ", "diff");
        refmodel_print_hex(diff);
        printf("\r\n  write: %u of %u differ  [0-63]=%u [64-127]=%u [128-191]=%u [192-255]=%u\r\n",
               bad, (unsigned)NUM_SPIN, bucket[0], bucket[1], bucket[2], bucket[3]);

        // The whole question in two numbers: how far this state was asked to be from the last
        // one, and how far the array actually ended up. If `read` collapses towards 0 while
        // `want` stays large, distinct states are not reaching the cells.
        if (n) {
            printf("  from previous state: wanted %u spins apart, read back %u apart\r\n",
                   distance(want, prev_want), distance(got, prev_got));
        }
        for (unsigned w = 0; w < LAGD_SPIN_NUM_WORDS; w++) {
            prev_want[w] = want[w];
            prev_got[w] = got[w];
        }
        if (WRITE_ONLY) continue;

        // ---- monitored run for this state ----------------------------------
        galena_stage_spin_feedback_pattern(CORE_TESTED, feedback);
        if (WARMUP_CYCLES) {
            galena_stage_feedback_pulse_timing(CORE_TESTED, WARMUP_CYCLES);
            galena_commit_spin_configure(CORE_TESTED);
            galena_trigger_feedback_pulse(CORE_TESTED);
            galena_poll_feedback_pulse_idle(CORE_TESTED);
        }
        galena_stage_spin_read_timing(CORE_TESTED, SAMPLE_INTERVAL, SAMPLE_COUNT);
        galena_enable_spin_out(CORE_TESTED, 1);
        galena_commit_spin_configure(CORE_TESTED);

        galena_trigger_spin_read(CORE_TESTED);
        galena_poll_spin_read_idle(CORE_TESTED);

        // Leave feedback off so the array is not left settling between states.
        galena_stage_spin_feedback(CORE_TESTED, 0);
        galena_enable_spin_out(CORE_TESTED, 0);
        galena_commit_spin_configure(CORE_TESTED);

        // Cycles are nominal, measured from the read trigger; treat them as relative times.
        printf("  %-4s | %8s | %8s | %s\r\n", "n", "cycle", "energy", "spins");
        printf("  -----+----------+----------+-------------------\r\n");
        printf("  %4s | %8u | %8d | ", "in", 0u, refmodel_energy(got));
        refmodel_print_hex(got);
        printf("\r\n");

        int best = refmodel_energy(got);
        for (unsigned k = 0; k < SAMPLE_COUNT; k++) {
            uint32_t raw[LAGD_SPIN_NUM_WORDS], s[LAGD_SPIN_NUM_WORDS];
            read_sample(CORE_TESTED, SLOTS_PER_BURST ? n * SAMPLE_COUNT + k : k, raw);
            unroll_vector(raw, roll, s);
            int e = refmodel_energy(s);
            if (e < best) best = e;
            printf("  %4u | %8u | %8d | ", k, (unsigned)((k + 1) * (SAMPLE_INTERVAL + 1)), e);
            refmodel_print_hex(s);
            printf("\r\n");
        }
        printf("  STATE %u start=%d best=%d bad_writes=%u\r\n", n, refmodel_energy(got), best,
               bad);

        if (n == 0 || best < sweep_best) {
            sweep_best = best;
            sweep_best_state = n;
        }
    }

    printf("=== sweep summary ===\r\n");
    if (WRITE_ONLY) {
        printf("write+readback only -- no runs, no captures\r\n");
        printf("spin-write mismatches: %u total, %u avg per state\r\n", total_bad,
               total_bad / (unsigned)STATE_COUNT);
        printf("FINISH\r\n");
        lagd_chip_finish();
        return 0;
    }
    printf("states=%u best energy %d from state %u\r\n", (unsigned)STATE_COUNT, sweep_best,
           sweep_best_state);
    printf("spin-write mismatches: %u total, %u avg per state\r\n", total_bad,
           total_bad / (unsigned)STATE_COUNT);

    printf("FINISH\r\n");
    lagd_chip_finish();
    return 0;
}
