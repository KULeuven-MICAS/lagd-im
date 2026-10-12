// Copyright 2026 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Toon Bettens <toon.bettens@kuleuven.be>

// Drive the array continuously for a fixed wall-clock time, so its power draw can be measured.
//
// The loop does one thing and nothing else: assert feedback for PULSE_CYCLES cycles, wait for it
// to finish, assert it again, for DURATION_S seconds. No reads, no writes, no energy computation,
// no problem data -- just the array being exercised, so whatever a meter sees is the array plus a
// fixed CPU/bus background rather than a varying workload.
//
// It expects load_problem_l1.spm.c to have put a problem in the array first. Nothing here writes
// to it, and nothing here depends on what the problem is, so this ELF is built once and reused.
//
// NOT LOSING PULSES. A feedback request raised while the previous one is still running is
// SILENTLY DROPPED, not queued: analog_spin_debug.sv:78 gates the enable on the busy status,
//     debug_feedback_en_comb = (busy_status_comb | debug_wen_i) ? 1'b0 : debug_feedback_en_i;
// so a dropped request produces no error and no pulse -- it would just quietly inflate the pulse
// count and make the duty cycle a lie. The loop therefore waits for DEBUG_SPIN_CMPT_IDLE
// (analog_spin_debug.sv:88, debug_spin_feedback_idle_o = ~feedback_busy_status) BEFORE every
// trigger rather than after it, so each trigger is issued into a known-idle engine and every
// counted pulse is one that actually ran.
//
// SUBTRACTING THE BACKGROUND. The polling loop is itself CSR traffic, and that costs power that
// has nothing to do with the array. Build a second copy with -DBASELINE=1 and it stages an
// ALL-ZERO feedback pattern instead of the real one. Everything else is bit-identical: the pulse
// still runs, feedback_busy_status still cycles, the CPU still polls at exactly the same cadence
// and issues exactly the same number of triggers -- but spin_feedback_o drives nothing, because
// it is gated on the staged pattern (analog_spin_debug.sv:95). Same CPU and bus activity, array
// not driven, so the difference between the two meter readings is the array's own contribution.
// Skipping the trigger instead would be a worse baseline: the idle poll would return immediately
// and the loop would spin faster, doing MORE bus traffic than the run it is meant to subtract.

#ifndef CORE_TESTED
#define CORE_TESTED 0
#endif
// How long to keep going, in seconds of wall clock.
#ifndef DURATION_S
#define DURATION_S 10
#endif
// Feedback pulse width, in cycles (cycle_per_spin_compute). A step_counter value of v runs v+1
// cycles. Longer pulses mean a higher array-active duty cycle, since the per-pulse CPU handshake
// is roughly fixed.
#ifndef PULSE_CYCLES
#define PULSE_CYCLES 12
#endif
// Feedback on every spin (1) or only the first BLOCK_SIZE (0). All spins is the realistic case for
// a power number: the whole array is what draws current.
#ifndef FEEDBACK_ALL
#define FEEDBACK_ALL 0
#endif
#ifndef BLOCK_BASE
#define BLOCK_BASE 0
#endif
#ifndef BLOCK_SIZE
#define BLOCK_SIZE NUM_SPIN
#endif
// Read the clock once per this many pulses. Checking every pulse would put the mtime read in the
// inner loop and add bus traffic that has nothing to do with the array.
#ifndef CHECK_EVERY
#define CHECK_EVERY 100000
#endif
// Drive no spins while doing all the same work, to measure the CPU/bus background alone.
#ifndef BASELINE
#define BASELINE 0
#endif

#include <stdint.h>
#include "regs/cheshire.h"
#include "dif/clint.h"
#include "printf.h"
#include "lagd_chip.h"
#include "lagd_bringup.h"
#include "lagd_galena_recipes.h"

int main(void) {
    lagd_chip_init();

    uint32_t rtc_freq = *reg32(&__base_regs, CHESHIRE_RTC_FREQ_REG_OFFSET);
    uint64_t core_freq = clint_get_core_freq(rtc_freq, 2500);

    printf("=== POWER LOOP ===\r\n");
    printf("core=%u duration=%us pulse=%u cycles feedback=%s%s\r\n", (unsigned)CORE_TESTED,
           (unsigned)DURATION_S, (unsigned)(PULSE_CYCLES + 1),
           FEEDBACK_ALL ? "all spins" : "block only",
           BASELINE ? " [BASELINE: pattern empty, no spins driven]" : "");
    printf("rtc=%u Hz core=%u Hz\r\n", (unsigned)rtc_freq, (unsigned)core_freq);

    // Host-side configuration only: nothing here writes the array, so the problem
    // load_problem_l1.spm.c wrote is left intact.
    lagd_core_apply_config(CORE_TESTED, &LAGD_BASE_CONFIG);

    uint32_t feedback[LAGD_SPIN_NUM_WORDS] = {0};
#if !BASELINE
    for (unsigned i = 0; i < NUM_SPIN; i++)
        if (FEEDBACK_ALL || (i >= BLOCK_BASE && i < BLOCK_BASE + BLOCK_SIZE))
            feedback[i / 32] |= (1u << (i % 32));
#endif

    // Staged and committed once, outside the loop. The loop body must stay minimal -- every extra
    // CSR access in it is power attributed to the array that the array did not spend.
    galena_stage_spin_feedback_pattern(CORE_TESTED, feedback);
    galena_stage_feedback_pulse_timing(CORE_TESTED, PULSE_CYCLES);
    galena_commit_spin_configure(CORE_TESTED);

    // ---- hot loop setup ------------------------------------------------------------------
    // Everything the loop touches is resolved once, here, so the loop body is nothing but the
    // three bus transactions that actually matter.
    //
    // The recipes are not used inside the loop, deliberately. galena_trigger_feedback_pulse ends
    // up in lagd_set_bit/lagd_clear_bit, which are READ-MODIFY-WRITE on a volatile register
    // (lagd_mmio.h:20-27): that is a read, a write, a read and a write per trigger, four bus
    // transactions to toggle one bit. Nothing else writes global_cfg_1 while this runs, so the
    // register value is known and both writes can be precomputed -- two writes, no reads.
    volatile uint32_t *status = lagd_core_reg(CORE_TESTED, LAGD_CORE_OUTPUT_STATUS_REG_OFFSET);
    volatile uint32_t *cfg1   = lagd_core_reg(CORE_TESTED, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET);

    const uint32_t idle_mask = 1u << LAGD_CORE_OUTPUT_STATUS_DEBUG_SPIN_CMPT_IDLE_BIT;
    const uint32_t cfg1_idle = *cfg1;                 // read ONCE, outside the loop
    const uint32_t cfg1_trig = cfg1_idle | (1u << LAGD_CORE_GLOBAL_CFG_1_DEBUG_SPIN_COMPUTE_EN_BIT);

    uint64_t t0 = clint_get_mtime();
    uint64_t deadline = t0 + (uint64_t)DURATION_S * (uint64_t)rtc_freq;
    uint64_t pulses = 0;

    printf("running...\r\n");
    lagd_chip_finish();          // flush before the loop; no UART traffic during the measurement

    for (;;) {
        for (unsigned k = 0; k < CHECK_EVERY; k++) {
            // Wait for idle FIRST, so the trigger cannot land on a busy engine and be dropped
            // (analog_spin_debug.sv:78). On the first pass this falls straight through;
            // afterwards it is what paces the loop to the pulse width.
            while ((*status & idle_mask) == 0)
                ;
            // The rising edge is what analog_dt_debug triggers on, so the bit has to go up and
            // back down. Two stores, no read-modify-write.
            *cfg1 = cfg1_trig;
            *cfg1 = cfg1_idle;
        }
        // The inner loop always runs to completion, so the count is exact without touching a
        // counter in the hot path.
        pulses += CHECK_EVERY;
        if (clint_get_mtime() >= deadline) break;
    }

    // Let the last pulse finish before reporting, so the array is quiet when the run ends.
    while ((*status & idle_mask) == 0)
        ;
    uint64_t elapsed = clint_get_mtime() - t0;

    // Reopen the UART side now that the measurement window is closed.
    uint64_t ticks = elapsed ? elapsed : 1;
    uint64_t ms = (elapsed * 1000u) / rtc_freq;
    uint64_t per_s = (pulses * (uint64_t)rtc_freq) / ticks;
    uint64_t active_cycles = pulses * (uint64_t)(PULSE_CYCLES + 1);
    uint64_t total_cycles = (elapsed * core_freq) / rtc_freq;
    unsigned duty = total_cycles ? (unsigned)((active_cycles * 100u) / total_cycles) : 0u;

    printf("--- result ---\r\n");
    printf("elapsed   : %u ms\r\n", (unsigned)ms);
    printf("pulses    : %u\r\n", (unsigned)pulses);
    printf("rate      : %u pulses/s\r\n", (unsigned)per_s);
#if BASELINE
    printf("duty      : %u%% of core cycles pulsing, but no spins driven (baseline)\r\n", duty);
#else
    printf("duty      : %u%% of core cycles with feedback asserted\r\n", duty);
#endif

    // Leave feedback off so the array is not left settling after the run.
    galena_stage_spin_feedback(CORE_TESTED, 0);
    galena_commit_spin_configure(CORE_TESTED);

    printf("FINISH\r\n");
    lagd_chip_finish();
    return 0;
}
