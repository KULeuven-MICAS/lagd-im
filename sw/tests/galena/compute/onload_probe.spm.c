// Copyright 2026 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Toon Bettens <toon.bettens@kuleuven.be>

// Does the compute-path J onload actually write the array? Checked without reading the array back,
// since debug data reads do not work on this die.
//
// The one proven observable into the array is the accumulation line: galena_acc_probe turns
// feedback on for a single spin and returns the sign of that column's summed couplings. Filling
// the array with a uniform +-PROBE_VALUE gives every column one sign, so flipping the data's sign
// must flip every probe; an onload that writes nothing leaves both probes identical. A uniform
// value also makes the result invariant under L1's 4-bit-field packing order.
//
// Stages B and C establish what +V and -V look like at the probe using the debug write path, so no
// polarity convention is assumed; D and E must reproduce that with the onload. Stages F and G add
// h = -H_BIAS on the h row (row NUM_SPIN) to move the comparator's decision point: an idle
// comparator reads back as 1 just like a correct +V, so without the offset only the negative
// direction is diagnostic.
//
// ONLOAD_WWL_CYCLES defaults to the debug path's 100; re-run at lagd_reg_params.h's 5 to separate
// "onload too fast" from "onload broken".
//
// Ordering: cfg_trans_num walks addresses and with PARALLELISM=4 address 64 is the h row
// (analog_cfg.sv:63), so the stock onload ends by loading h from H_RDATA, which nothing here
// stages. The bias therefore goes in afterwards over the debug path, leaving the onload
// bit-identical to the one scompute runs and the J cells it wrote untouched.

#ifndef CORE_TESTED
#define CORE_TESTED 0
#endif
// Magnitude written and onloaded, 1..7. Every cell in the array gets +V, then -V.
#ifndef PROBE_VALUE
#define PROBE_VALUE 7
#endif
// Debug-side pulse width for the controls: the value known to work.
#ifndef DEBUG_WWL_CYCLES
#define DEBUG_WWL_CYCLES 100
#endif
// Compute-side pulse width for the onload under test.
#ifndef ONLOAD_WWL_CYCLES
#define ONLOAD_WWL_CYCLES 100
#endif
// Analog cfg transactions: addresses 0..64, J on 0..63 and the h row last at 64.
#ifndef ONLOAD_TRANS_NUM
#define ONLOAD_TRANS_NUM 64
#endif
// Run the h-biased stages F..K. The bias magnitude wants to be the smallest value that reliably
// moves the probe on its own (stages F/G check that), so that a real J sum still dominates it.
#ifndef RUN_BIASED
#define RUN_BIASED 1
#endif
#ifndef H_BIAS
#define H_BIAS 1
#endif
// Columns acc-probed per stage, spread across the array.
#ifndef PROBE_COLS
#define PROBE_COLS 64
#endif
// Repeats per probe; the majority is taken, since the array is analog.
#ifndef PROBE_REPEAT
#define PROBE_REPEAT 5
#endif
#ifndef CYCLE_PER_READ
#define CYCLE_PER_READ 5
#endif
#ifndef READ_NUM
#define READ_NUM 1
#endif

#include <stdint.h>
#include "printf.h"
#include "lagd_chip.h"
#include "lagd_bringup.h"
#include "lagd_galena_recipes.h"

#if CORE_TESTED == 0
#define J_DATA_SECTION ".l1j_data_c0"
#else
#define J_DATA_SECTION ".l1j_data_c1"
#endif

// The J source the onloader reads. Not const: l1_j_spm is (rwx) in the linker script, so the CPU
// can rewrite it between onloads and both polarities can be tested from one ELF.
#define J_WORDS (NUM_SPIN * NUM_SPIN * BIT_J / 64)
static uint64_t probe_j_data[J_WORDS] __attribute__((used, section(J_DATA_SECTION)));

// Fill every 4-bit field of the J memory with `value` in two's complement -- the format
// analog_cfg.sv expects, which it converts to the array's sign-magnitude on the way out.
static void fill_j_memory(int value) {
    uint64_t nibble = (uint64_t)(value & 0xF);
    uint64_t word = 0;
    for (unsigned k = 0; k < 16; k++) word = (word << 4) | nibble;
    for (unsigned i = 0; i < J_WORDS; i++) probe_j_data[i] = word;
}

// Acc-probe PROBE_COLS columns and return how many read back as 1. With a uniform array every
// column has the same sign, so this should come out at 0 or PROBE_COLS, not in between.
static unsigned probe_columns(unsigned core, const char *what) {
    unsigned ones = 0;
    printf("  %-10s ", what);
    for (unsigned k = 0; k < PROBE_COLS; k++) {
        unsigned col = (k * (NUM_SPIN - 1)) / (PROBE_COLS > 1 ? PROBE_COLS - 1 : 1);
        unsigned hits = 0;
        for (unsigned r = 0; r < PROBE_REPEAT; r++)
            hits += galena_acc_probe(core, col, CYCLE_PER_READ, READ_NUM);
        unsigned bit = (hits * 2 >= PROBE_REPEAT) ? 1u : 0u;
        ones += bit;
        printf("%u", bit);
    }
    printf("   (%u/%u ones)\r\n", ones, (unsigned)PROBE_COLS);
    return ones;
}

// Debug-write every J cell to `value`, leaving the h row exactly as it is. Split out from
// write_array_uniform because the biased stages need the h bias to survive the J fill.
static void write_j_uniform(unsigned core, int value) {
    for (unsigned row = 0; row < NUM_SPIN; row++)
        galena_write_row_broadcast(core, row, value);
}

static void write_array_uniform(unsigned core, int value) {
    write_j_uniform(core, value);
    galena_write_row_broadcast(core, NUM_SPIN, 0);   // leave the h row out of it
}

// Broadcast one signed h value onto every column's HU. The H row is encoded exactly like a J
// row, so `value` is negated here to match the polarity the J writes above already use.
static void set_h_bias(unsigned core, int value) {
    galena_write_row_broadcast(core, NUM_SPIN, -value);
}

// Pulse DT_CFG_ENABLE and wait for the onload to report idle.
static void run_onload(unsigned core, unsigned trans_num) {
    // CRITICAL: wbl_floating latches only on the debug configure pulse (analog_macro_wrap.sv:189)
    // and is active-low. Any earlier debug operation may have left it floating, and the compute
    // path cannot restore it -- an onload with floating bitlines drives nothing, which would look
    // exactly like the failure this test is looking for. Re-stage it driven every time.
    galena_stage_wbl_floating(core, 1);
    galena_stage_wwl_timing(core, ONLOAD_WWL_CYCLES, ONLOAD_WWL_CYCLES);
    galena_commit_dt_configure(core);

    // analog_cfg loads its own timing on the CONFIG_VALID_AW edge, so the counters go in first.
    *lagd_core_reg(core, LAGD_CORE_COUNTER_CFG_1_REG_OFFSET) =
        ((uint32_t)trans_num << LAGD_CORE_COUNTER_CFG_1_CFG_TRANS_NUM_OFFSET) |
        ((uint32_t)ONLOAD_WWL_CYCLES << LAGD_CORE_COUNTER_CFG_1_CYCLE_PER_WWL_HIGH_OFFSET);
    lagd_core_write_field(core, LAGD_CORE_COUNTER_CFG_2_REG_OFFSET,
                          LAGD_CORE_COUNTER_CFG_2_CYCLE_PER_WWL_LOW_MASK,
                          LAGD_CORE_COUNTER_CFG_2_CYCLE_PER_WWL_LOW_OFFSET, ONLOAD_WWL_CYCLES);
    galena_commit_aw_configure(core);

    lagd_core_set_bit(core, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET,
                      LAGD_CORE_GLOBAL_CFG_2_DT_CFG_ENABLE_BIT);
    lagd_core_clear_bit(core, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET,
                        LAGD_CORE_GLOBAL_CFG_2_DT_CFG_ENABLE_BIT);
    lagd_core_poll_bit(core, LAGD_CORE_OUTPUT_STATUS_REG_OFFSET,
                       LAGD_CORE_OUTPUT_STATUS_DT_CFG_IDLE_BIT, /*want_set=*/1);
}

int main(void) {
    lagd_chip_init();

    printf("=== ONLOAD PROBE (accumulation line) ===\r\n");
    printf("core=%u value=+/-%d debug_wwl=%u onload_wwl=%u cols=%u repeat=%u\r\n",
           (unsigned)CORE_TESTED, (int)PROBE_VALUE, (unsigned)DEBUG_WWL_CYCLES,
           (unsigned)ONLOAD_WWL_CYCLES, (unsigned)PROBE_COLS, (unsigned)PROBE_REPEAT);

    lagd_core_apply_config(CORE_TESTED, &LAGD_BASE_CONFIG);
    galena_stage_wwl_timing(CORE_TESTED, DEBUG_WWL_CYCLES, DEBUG_WWL_CYCLES);
    galena_commit_dt_configure(CORE_TESTED);
    galena_stage_spin_write_timing(CORE_TESTED, DEBUG_WWL_CYCLES);
    galena_commit_spin_configure(CORE_TESTED);

    uint32_t zero_spins[LAGD_SPIN_NUM_WORDS] = {0};
    galena_write_spins(CORE_TESTED, zero_spins);

    printf("--- probes ---\r\n");
    galena_zero_array(CORE_TESTED);
    unsigned a_zero = probe_columns(CORE_TESTED, "A zeroed");

    write_array_uniform(CORE_TESTED, PROBE_VALUE);
    unsigned b_pos = probe_columns(CORE_TESTED, "B dbg +");

    write_array_uniform(CORE_TESTED, -PROBE_VALUE);
    unsigned c_neg = probe_columns(CORE_TESTED, "C dbg -");

    galena_zero_array(CORE_TESTED);
    fill_j_memory(PROBE_VALUE);
    run_onload(CORE_TESTED, ONLOAD_TRANS_NUM);
    unsigned d_pos = probe_columns(CORE_TESTED, "D onl +");

    galena_zero_array(CORE_TESTED);
    fill_j_memory(-PROBE_VALUE);
    run_onload(CORE_TESTED, ONLOAD_TRANS_NUM);
    unsigned e_neg = probe_columns(CORE_TESTED, "E onl -");

    // --- verdict -------------------------------------------------------------
    // The controls define what +V and -V look like; the onload has to reproduce them. Requiring
    // every column to agree is deliberate -- with a uniform array there is no legitimate reason for
    // a split, so anything in between means something other than a clean pass or fail.
    printf("--- verdict ---\r\n");
    int controls_separate = (b_pos == PROBE_COLS && c_neg == 0) ||
                            (b_pos == 0 && c_neg == PROBE_COLS);
    int onload_matches = (d_pos == b_pos) && (e_neg == c_neg);
    int onload_flat = (d_pos == e_neg);

    if (!controls_separate) {
        printf("INCONCLUSIVE: the debug-written controls did not separate (+%d gave %u ones, "
               "-%d gave %u); the probe is not tracking the array\r\n",
               PROBE_VALUE, b_pos, PROBE_VALUE, c_neg);
    } else if (onload_matches) {
        printf("ONLOAD OK at wwl=%u: both polarities reproduce the debug controls\r\n",
               (unsigned)ONLOAD_WWL_CYCLES);
    } else if (onload_flat) {
        printf("ONLOAD WROTE NOTHING at wwl=%u: both polarities gave %u ones, and the zeroed "
               "array gave %u -- the data never reached the cells\r\n",
               (unsigned)ONLOAD_WWL_CYCLES, d_pos, a_zero);
    } else {
        printf("ONLOAD PARTIAL at wwl=%u: + gave %u ones (control %u), - gave %u (control %u)\r\n",
               (unsigned)ONLOAD_WWL_CYCLES, d_pos, b_pos, e_neg, c_neg);
    }

#if RUN_BIASED
    // --- h-biased stages -----------------------------------------------------
    // Every stage zeroes the array, fills J, and only THEN writes the h bias over the top. The
    // onload runs at its production ONLOAD_TRANS_NUM, so it does write the h row from an unloaded
    // H_RDATA -- harmless, because the debug h write that follows lands on top of it.
    printf("--- h-biased probes (h=+/-%d) ---\r\n", (int)H_BIAS);

    galena_zero_array(CORE_TESTED);
    set_h_bias(CORE_TESTED, -H_BIAS);
    unsigned f_hneg = probe_columns(CORE_TESTED, "F h-  J0");

    galena_zero_array(CORE_TESTED);
    set_h_bias(CORE_TESTED, +H_BIAS);
    unsigned g_hpos = probe_columns(CORE_TESTED, "G h+  J0");

    // Against a - bias, a working +V has to push the line back up. Unlike stage D this is no longer
    // aliased to the idle state, so the positive direction finally carries information.
    galena_zero_array(CORE_TESTED);
    write_j_uniform(CORE_TESTED, PROBE_VALUE);
    set_h_bias(CORE_TESTED, -H_BIAS);
    unsigned h_dbg_pos = probe_columns(CORE_TESTED, "H h- dbg+");

    galena_zero_array(CORE_TESTED);
    fill_j_memory(PROBE_VALUE);
    run_onload(CORE_TESTED, ONLOAD_TRANS_NUM);
    set_h_bias(CORE_TESTED, -H_BIAS);
    unsigned i_onl_pos = probe_columns(CORE_TESTED, "I h- onl+");

    // And the mirror image, so the negative direction gets the same treatment.
    galena_zero_array(CORE_TESTED);
    write_j_uniform(CORE_TESTED, -PROBE_VALUE);
    set_h_bias(CORE_TESTED, +H_BIAS);
    unsigned j_dbg_neg = probe_columns(CORE_TESTED, "J h+ dbg-");

    galena_zero_array(CORE_TESTED);
    fill_j_memory(-PROBE_VALUE);
    run_onload(CORE_TESTED, ONLOAD_TRANS_NUM);
    set_h_bias(CORE_TESTED, +H_BIAS);
    unsigned k_onl_neg = probe_columns(CORE_TESTED, "K h+ onl-");

    printf("--- biased verdict ---\r\n");
    // F/G first: if the bias alone does not move the line in both directions, nothing downstream of
    // it means anything, and the honest answer is to say so rather than report a J result.
    int bias_works = (f_hneg == 0 && g_hpos == PROBE_COLS) ||
                     (f_hneg == PROBE_COLS && g_hpos == 0);
    if (!bias_works) {
        printf("BIAS LEVER DEAD: h=-%d gave %u ones, h=+%d gave %u -- raise H_BIAS and re-run; "
               "stages H..K mean nothing until these two separate\r\n",
               (int)H_BIAS, f_hneg, (int)H_BIAS, g_hpos);
    } else {
        // With the lever proven, each onload is judged against the debug control that shares its
        // bias and its J polarity -- the only fair comparison, and now a two-sided one.
        printf("bias lever OK (h- -> %u ones, h+ -> %u)\r\n", f_hneg, g_hpos);
        printf("  positive: dbg %u/%u vs onl %u/%u -> %s\r\n", h_dbg_pos, (unsigned)PROBE_COLS,
               i_onl_pos, (unsigned)PROBE_COLS,
               (i_onl_pos == h_dbg_pos) ? "match"
                   : (i_onl_pos == f_hneg) ? "ONLOAD WROTE NOTHING" : "PARTIAL");
        printf("  negative: dbg %u/%u vs onl %u/%u -> %s\r\n", j_dbg_neg, (unsigned)PROBE_COLS,
               k_onl_neg, (unsigned)PROBE_COLS,
               (k_onl_neg == j_dbg_neg) ? "match"
                   : (k_onl_neg == g_hpos) ? "ONLOAD WROTE NOTHING" : "PARTIAL");
    }
#endif

    galena_zero_array(CORE_TESTED);
    printf("FINISH\r\n");
    lagd_chip_finish();
    return 0;
}
