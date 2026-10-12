// Copyright 2026 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Toon Bettens <toon.bettens@kuleuven.be>

// Watch the array converge: take a sequence of spin snapshots while feedback is held, instead of
// the single settled reading run_capture.spm.c takes.
//
// Like run_capture.spm.c this writes NOTHING into the array -- it expects load_problem_l1.spm.c to
// have put the problem there already, and only configures host-side registers.
//
// THE HARDWARE. analog_spin_debug.sv runs a read burst off two counters: i_read_counter paces the
// samples (cycle_per_spin_read) and i_read_num_counter counts them (spin_read_num). Feedback is
// driven for the whole burst -- spin_feedback_o is asserted while r_busy_status holds
// (analog_spin_debug.sv:95) -- so every sample is taken with the array actively settling, which is
// the only way to observe a convergence at all: bct_read_o reverts to the written spin the moment
// feedback drops.
//
// Every sample is written into L1 FLIP MEMORY at its own sample index (analog_macro_wrap.sv:175),
// 256 bits per sample, and the CPU reads them back afterwards. That memory holds the flip icons
// during a real compute run, but nothing here runs the flip engine, so the whole 1024-entry depth
// is available as a sample buffer.
//
// TIMING, AND ONE HARDWARE CONSTRAINT. The counters give uniformly spaced samples, and the first
// one lands one full interval after the trigger -- there is no separate "delay to first sample"
// register, so the initial delay and the spacing are the same number. WARMUP_CYCLES is the way to
// wait longer before sampling starts: it runs a feedback-only pulse first. Note that pulse ends
// before the burst begins (the CPU has to clear spin_compute_en before spin_read_en is accepted --
// analog_spin_debug.sv:79 blocks the read while the feedback enable is high), so there is a short,
// CPU-latency-sized gap in feedback between the warmup and the first sample. Set WARMUP_CYCLES to
// 0 to sample straight from the trigger with no gap anywhere.

#ifndef CORE_TESTED
#define CORE_TESTED 0
#endif

// Number of snapshots to take. Capped by the flip memory's depth.
#ifndef SAMPLE_COUNT
#define SAMPLE_COUNT 64
#endif

// Cycles between samples, and equally the delay from the trigger to the FIRST sample.
// A step_counter value of v runs for v+1 cycles, so the true spacing is SAMPLE_INTERVAL+1.
#ifndef SAMPLE_INTERVAL
#define SAMPLE_INTERVAL 0
#endif

// Optional feedback-only settle before sampling starts, in cycles (0 = start sampling right away).
// Use this when you want the first sample later than one SAMPLE_INTERVAL without stretching the
// spacing between samples.
#ifndef WARMUP_CYCLES
#define WARMUP_CYCLES 0
#endif

// Hold feedback on every spin, not just the problem block. The block-only default keeps spins
// outside the problem from being driven, matching run_capture.
#ifndef FEEDBACK_ALL
#define FEEDBACK_ALL 0
#endif

#include <stdint.h>
#include "printf.h"
#include "lagd_chip.h"
#include "lagd_bringup.h"
#include "lagd_galena_recipes.h"
// The same problem source load_problem_l1 loads from: J sits in l1_j_spm and the captured
// samples land in l1_f_spm, so the two never collide.
#include "lagd_l1_model.h"

// The problem occupies the whole array. Where logical spin i physically sits is decided by
// REFMODEL_MIRROR in lagd_l1_model.h -- mirrored (the default) puts it at hardware index i,
// in the low cells the debug spin write can actually reach; refmodel_hw() is the authority.
#define BLOCK_BASE 0
#define BLOCK_SIZE REFMODEL_SIZE
// One past the last spin that is actually part of the problem. A problem smaller than 256 is
// zero-padded, and the padding has no couplings and no field, so feedback on it settles it on
// nothing, costs power and lets it drift. States still print in full, all 256.
#define BLOCK_END refmodel_size()

// One sample out of this core's L1 flip memory. analog_macro_wrap.sv writes each read-burst
// sample there at its own sample index, 256 bits wide, so sample k starts at word
// k * LAGD_SPIN_NUM_WORDS from the base of the flip region.
static void read_sample(unsigned core, unsigned index, uint32_t out[LAGD_SPIN_NUM_WORDS]) {
    volatile uint32_t *flip =
        (volatile uint32_t *)((uintptr_t)IC_MEM_BASE_ADDR + (uintptr_t)core * IC_L1_MEM_SIZE_B +
                              (uintptr_t)L1_J_MEM_SIZE_B);
    for (unsigned w = 0; w < LAGD_SPIN_NUM_WORDS; w++)
        out[w] = flip[index * LAGD_SPIN_NUM_WORDS + w];
}

int main(void) {
    lagd_chip_init();

    printf("=== MONITOR CAPTURE ===\r\n");
    printf("core=%u spins=%u at hw [%u,%u)\r\n", (unsigned)CORE_TESTED, (unsigned)BLOCK_SIZE,
           (unsigned)BLOCK_BASE, (unsigned)BLOCK_END);
    printf("samples=%u interval=%u cycles warmup=%u cycles feedback=%s\r\n",
           (unsigned)SAMPLE_COUNT, (unsigned)(SAMPLE_INTERVAL + 1), (unsigned)WARMUP_CYCLES,
           FEEDBACK_ALL ? "all spins" : "block only");

    // Host-side configuration only: lagd_core_apply_config touches CSRs, never the array, so the
    // problem load_problem_l1.spm.c wrote is left intact.
    lagd_core_apply_config(CORE_TESTED, &LAGD_BASE_CONFIG);

    uint32_t feedback[LAGD_SPIN_NUM_WORDS] = {0};
    for (unsigned i = 0; i < NUM_SPIN; i++)
        if (FEEDBACK_ALL || (i >= BLOCK_BASE && i < BLOCK_END))
            feedback[i / 32] |= (1u << (i % 32));

    uint32_t before[LAGD_SPIN_NUM_WORDS];
    galena_read_spins(CORE_TESTED, before);
    printf("--- initial state (as left by the loader) ---\r\n");
    refmodel_print_state("initial", before);

    galena_stage_spin_feedback_pattern(CORE_TESTED, feedback);

    if (WARMUP_CYCLES) {
        // Feedback-only settle. Nothing is captured; this exists purely to push the first sample
        // further out than one SAMPLE_INTERVAL.
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

    // Cycle counts are nominal, measured from the read trigger: sample k lands after
    // (k+1)*(SAMPLE_INTERVAL+1) cycles. The CPU's own store latency in reaching the trigger is not
    // included, so treat these as relative times rather than absolute ones.
    printf("--- samples ---\r\n");
    printf("  %-4s | %8s | %8s | %s\r\n", "n", "cycle", "energy", "spins");
    printf("  -----+----------+----------+-------------------\r\n");

    int best = 0;
    for (unsigned k = 0; k < SAMPLE_COUNT; k++) {
        uint32_t s[LAGD_SPIN_NUM_WORDS];
        read_sample(CORE_TESTED, k, s);
        int e = refmodel_energy(s);
        if (k == 0 || e < best) best = e;
        printf("  %4u | %8u | %8d | ", k, (unsigned)((k + 1) * (SAMPLE_INTERVAL + 1)), e);
        refmodel_print_hex(s);
        printf("\r\n");
    }
    printf("best energy over %u samples: %d\r\n", (unsigned)SAMPLE_COUNT, best);

    printf("FINISH\r\n");
    lagd_chip_finish();
    return 0;
}
