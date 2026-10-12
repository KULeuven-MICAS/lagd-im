// Copyright 2026 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Toon Bettens <toon.bettens@kuleuven.be>

// Load the problem and capture a monitored run, in one ELF.
//
// load_problem_l1 + monitor_capture without the gap between them. The two-ELF flow depends on the
// array holding J and the spins across a chip reset; this does not, so it is the one to use when
// that retention is in question or when sweeping (one build, one run, one log).
//
// Phase 1 writes J, h and the start state through the galena debug recipes, reading the problem
// out of l1_j_spm. Phase 2 holds feedback and takes SAMPLE_COUNT snapshots into l1_f_spm. The two
// L1 regions are separate, so the captures never touch the matrix.

#ifndef CORE_TESTED
#define CORE_TESTED 0
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
// Top-left corner of the logical matrix, as a sanity check on what came out of L1. 0 prints none.
#ifndef PRINT_ROWS
#define PRINT_ROWS 8
#endif
#ifndef PRINT_COLS
#define PRINT_COLS 8
#endif

// --- monitor phase ----------------------------------------------------------
// Snapshots to take (1..FLIP_ICON_DEPTH).
#ifndef SAMPLE_COUNT
#define SAMPLE_COUNT 128
#endif
// Cycles between samples, and equally the delay to the FIRST one. True spacing is this plus one.
#ifndef SAMPLE_INTERVAL
#define SAMPLE_INTERVAL 0
#endif
// Feedback-only settle before sampling, in cycles. Pushes the first sample out without stretching
// the spacing. 0 starts sampling immediately.
#ifndef WARMUP_CYCLES
#define WARMUP_CYCLES 0
#endif
// Hold feedback on every spin rather than only the problem's. Padding has no couplings, so
// driving it settles nothing and only adds noise.
#ifndef FEEDBACK_ALL
#define FEEDBACK_ALL 0
#endif

#include <stdint.h>
#include "printf.h"
#include "lagd_chip.h"
#include "lagd_bringup.h"
#include "lagd_galena_recipes.h"
#include "lagd_l1_model.h"

#if SAMPLE_COUNT < 1 || SAMPLE_COUNT > FLIP_ICON_DEPTH
#error "SAMPLE_COUNT must be 1..FLIP_ICON_DEPTH"
#endif

// One snapshot out of this core's L1 flip memory: sample k starts at word k*LAGD_SPIN_NUM_WORDS.
static void read_sample(unsigned core, unsigned index, uint32_t out[LAGD_SPIN_NUM_WORDS]) {
    volatile uint32_t *flip =
        (volatile uint32_t *)((uintptr_t)IC_MEM_BASE_ADDR + (uintptr_t)core * IC_L1_MEM_SIZE_B +
                              (uintptr_t)L1_J_MEM_SIZE_B);
    for (unsigned w = 0; w < LAGD_SPIN_NUM_WORDS; w++)
        out[w] = flip[index * LAGD_SPIN_NUM_WORDS + w];
}

int main(void) {
    lagd_chip_init();

    printf("=== LOAD + MONITOR ===\r\n");
    printf("core=%u spins=%u (problem occupies %u) invert_j=%u invert_h=%u\r\n",
           (unsigned)CORE_TESTED, (unsigned)REFMODEL_SIZE, (unsigned)refmodel_size(),
           (unsigned)INVERT_J, (unsigned)INVERT_H);
    printf("samples=%u interval=%u cycles warmup=%u cycles feedback=%s\r\n",
           (unsigned)SAMPLE_COUNT, (unsigned)(SAMPLE_INTERVAL + 1), (unsigned)WARMUP_CYCLES,
           FEEDBACK_ALL ? "all spins" : "problem only");
    printf("J at 0x%08x, checksum 0x%08x (compare with the generator's)\r\n",
           (unsigned)(uintptr_t)REFMODEL_J, (unsigned)refmodel_j_checksum());

    lagd_core_apply_config(CORE_TESTED, &LAGD_BASE_CONFIG);
    galena_stage_wwl_timing(CORE_TESTED, WWL_CYCLES, WWL_CYCLES);
    galena_commit_dt_configure(CORE_TESTED);
    galena_stage_spin_write_timing(CORE_TESTED, SPIN_WRITE_CYCLES);
    galena_commit_spin_configure(CORE_TESTED);

    // Clean slate. The array keeps its contents across runs, so without this a leftover row or
    // spin reads back as though this load produced it. Clearing spins works even though setting
    // them is unreliable, so a residual here is a genuinely stuck cell.
    galena_zero_array(CORE_TESTED);
    uint32_t zero[LAGD_SPIN_NUM_WORDS] = {0};
    galena_write_spins(CORE_TESTED, zero);

    uint32_t cleared[LAGD_SPIN_NUM_WORDS];
    galena_read_spins(CORE_TESTED, cleared);
    unsigned residual = 0;
    for (unsigned i = 0; i < NUM_SPIN; i++)
        if ((cleared[i / 32] >> (i % 32)) & 1u) residual++;
    if (residual) {
        printf("note: %u spin(s) would not clear -- stuck high: ", residual);
        refmodel_print_hex(cleared);
        printf("\r\n");
    }

    printf("--- J top-left corner: rows 0..%u, columns 0..%u (logical indices) ---\r\n",
           (unsigned)(PRINT_ROWS ? PRINT_ROWS - 1 : 0), (unsigned)(PRINT_COLS - 1));

    // One row at a time, permuted into hardware column order before the write.
    int hw_values[NUM_SPIN];
    for (unsigned i = 0; i < REFMODEL_SIZE; i++) {
        for (unsigned c = 0; c < REFMODEL_SIZE; c++) {
            int v = refmodel_j(i, c);
            hw_values[refmodel_hw(c)] = INVERT_J ? -v : v;
        }
        galena_write_row_values(CORE_TESTED, refmodel_hw(i), hw_values, 0, NUM_SPIN);

        if (i < PRINT_ROWS) {
            printf("  row %3u -> hw %3u |", i, refmodel_hw(i));
            for (unsigned c = 0; c < PRINT_COLS && c < REFMODEL_SIZE; c++)
                printf(" %3d", refmodel_j(i, c));
            printf(" ...\r\n");
        }
    }

    // The h row is a dedicated selector, not a logical row, so it is not permuted -- its columns
    // are, exactly as debug_load_jh() treats H_ROW.
    for (unsigned c = 0; c < REFMODEL_SIZE; c++) {
        int v = refmodel_h(c);
        hw_values[refmodel_hw(c)] = INVERT_H ? -v : v;
    }
    galena_write_row_values(CORE_TESTED, NUM_SPIN, hw_values, 0, NUM_SPIN);
    printf("  h row             |");
    for (unsigned c = 0; c < PRINT_COLS && c < REFMODEL_SIZE; c++) printf(" %3d", refmodel_h(c));
    printf(" ...\r\n");

    // spin_initial_0 is already in hardware bit order, so it goes straight in.
    uint32_t start[LAGD_SPIN_NUM_WORDS];
    for (unsigned w = 0; w < LAGD_SPIN_NUM_WORDS; w++) start[w] = REFMODEL_INITIAL[w];
    galena_write_spins(CORE_TESTED, start);

    uint32_t before[LAGD_SPIN_NUM_WORDS];
    galena_read_spins(CORE_TESTED, before);

    // FYI: the debug spin write does not hold reliably, and its failures grow with hardware index.
    // Reading back DOES work, so this is a trustworthy account of what landed. J is written by a
    // different mechanism and is unaffected.
    uint32_t diff[LAGD_SPIN_NUM_WORDS];
    unsigned mismatches = 0;
    unsigned bucket[4] = {0, 0, 0, 0};
    for (unsigned w = 0; w < LAGD_SPIN_NUM_WORDS; w++) diff[w] = start[w] ^ before[w];
    for (unsigned i = 0; i < NUM_SPIN; i++)
        if ((diff[i / 32] >> (i % 32)) & 1u) {
            mismatches++;
            bucket[i / 64]++;
        }

    printf("--- initial state (FYI: the debug spin write is known to be unreliable) ---\r\n");
    refmodel_print_state("wanted", start);
    refmodel_print_state("onchip", before);
    printf("  %-7s: ", "diff");
    refmodel_print_hex(diff);
    printf("  %u of %u differ\r\n", mismatches, (unsigned)NUM_SPIN);
    printf("  by hardware index: [0-63]=%u [64-127]=%u [128-191]=%u [192-255]=%u\r\n", bucket[0],
           bucket[1], bucket[2], bucket[3]);
    printf("LOADED\r\n");

    // ---- monitor -----------------------------------------------------------
    // Feedback only on the real problem: padding has no couplings, so driving it settles nothing.
    uint32_t feedback[LAGD_SPIN_NUM_WORDS] = {0};
    for (unsigned i = 0; i < NUM_SPIN; i++)
        if (FEEDBACK_ALL || i < refmodel_size()) feedback[i / 32] |= (1u << (i % 32));
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

    // Leave feedback off so the array is not left settling after the burst.
    galena_stage_spin_feedback(CORE_TESTED, 0);
    galena_enable_spin_out(CORE_TESTED, 0);
    galena_commit_spin_configure(CORE_TESTED);

    // Cycles are nominal, measured from the read trigger: sample k lands after
    // (k+1)*(SAMPLE_INTERVAL+1). CPU store latency to the trigger is not included, so treat these
    // as relative times.
    printf("--- samples ---\r\n");
    printf("  %-4s | %8s | %8s | %s\r\n", "n", "cycle", "energy", "spins");
    printf("  -----+----------+----------+-------------------\r\n");
    printf("  %4s | %8u | %8d | ", "in", 0u, refmodel_energy(before));
    refmodel_print_hex(before);
    printf("\r\n");

    int best = refmodel_energy(before);
    for (unsigned k = 0; k < SAMPLE_COUNT; k++) {
        uint32_t s[LAGD_SPIN_NUM_WORDS];
        read_sample(CORE_TESTED, k, s);
        int e = refmodel_energy(s);
        if (e < best) best = e;
        printf("  %4u | %8u | %8d | ", k, (unsigned)((k + 1) * (SAMPLE_INTERVAL + 1)), e);
        refmodel_print_hex(s);
        printf("\r\n");
    }
    printf("best energy over %u samples: %d  (started at %d)\r\n", (unsigned)SAMPLE_COUNT, best,
           refmodel_energy(before));

    printf("FINISH\r\n");
    lagd_chip_finish();
    return 0;
}
