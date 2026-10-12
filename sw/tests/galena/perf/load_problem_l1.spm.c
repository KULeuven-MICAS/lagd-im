// Copyright 2026 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Toon Bettens <toon.bettens@kuleuven.be>

// Load the problem into Galena through our own galena_* debug recipes, and stop. The loading half
// of the two-ELF flow; run_capture.spm.c or monitor_capture.spm.c then computes on what this left.
//
// SAME PROBLEM, SAME PLACES AS THE REFERENCE PATH. J and h come from model_j_data / model_h_data,
// which sw/tools/gen_ising_problem.py wrote into tests/ref/data/<DATA_FOLDER>/, gen_model_data.py
// packed, the linker placed in this core's l1_j_spm and the ELF loader filled. The initial state
// comes from spin_data.h. That is exactly what tests/ref/onload_debug.spm.c loads, and the same
// hardware permutation is used -- logical spin i at hardware index NUM_SPIN-1-i -- so the array
// ends up holding the same problem in the same cells either way.
//
// THE DIFFERENCE, and the only one: this writes through galena_write_row_values() at WWL_CYCLES
// timing, where onload_debug.spm.c writes through debug_load_jh() at the reference timing with
// per-row supply cycling. That makes the two directly comparable with one variable changed.
//
// ENCODING. galena_encode_cu() sets bit 0 for a POSITIVE value; the reference chip_encode_word()
// sets it for a NEGATIVE one. INVERT_J negates before encoding, which makes the two produce
// identical codes -- so leave it on unless you are deliberately probing the polarity.

#ifndef CORE_TESTED
#define CORE_TESTED 0
#endif
// Reference WWL timing (lagd_reg_params.h uses CYCLE_PER_WWL_HIGH/LOW = 5). A step_counter value
// v runs v+1 cycles, so this is 6 cycles high and 6 low per write.
#ifndef WWL_CYCLES
#define WWL_CYCLES 100
#endif
#ifndef SPIN_WRITE_CYCLES
#define SPIN_WRITE_CYCLES 100
#endif
// Negate before encoding, matching the reference encoder's sign convention. See above.
#ifndef INVERT_J
#define INVERT_J 1
#endif
#ifndef INVERT_H
#define INVERT_H 1
#endif
// The top-left corner of the logical matrix, printed as a sanity check on what came out of L1:
// PRINT_ROWS rows of PRINT_COLS couplings each, in logical indices. 0 rows prints none.
#ifndef PRINT_ROWS
#define PRINT_ROWS 8
#endif
#ifndef PRINT_COLS
#define PRINT_COLS 8
#endif

#include <stdint.h>
#include "printf.h"
#include "lagd_chip.h"
#include "lagd_bringup.h"
#include "lagd_galena_recipes.h"
#include "lagd_l1_model.h"


int main(void) {
    lagd_chip_init();

    printf("=== LOAD PROBLEM (galena recipes, J from L1) ===\r\n");
    printf("core=%u spins=%u wwl_cycles=%u invert_j=%u invert_h=%u\r\n", (unsigned)CORE_TESTED,
           (unsigned)REFMODEL_SIZE, (unsigned)WWL_CYCLES, (unsigned)INVERT_J, (unsigned)INVERT_H);
    printf("J at 0x%08x, checksum 0x%08x (compare with the generator's)\r\n",
           (unsigned)(uintptr_t)REFMODEL_J, (unsigned)refmodel_j_checksum());

    lagd_core_apply_config(CORE_TESTED, &LAGD_BASE_CONFIG);
    galena_stage_wwl_timing(CORE_TESTED, WWL_CYCLES, WWL_CYCLES);
    galena_commit_dt_configure(CORE_TESTED);
    galena_stage_spin_write_timing(CORE_TESTED, SPIN_WRITE_CYCLES);
    galena_commit_spin_configure(CORE_TESTED);

    // Clean slate before anything is written. The array keeps its contents across ELF runs, so
    // without this a leftover J row or spin from a previous load reads back as though this run had
    // produced it. Clearing spins is worth doing even though the debug spin write is unreliable:
    // it fails at SETTING bits, not clearing them, so a residual here means a genuinely stuck cell
    // rather than a write that did not take -- which is what makes the diff at the end readable.
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

    // The h row is not permuted -- it is a dedicated selector, not a logical row -- but its
    // columns are, exactly as debug_load_jh() treats H_ROW.
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

    uint32_t written[LAGD_SPIN_NUM_WORDS];
    galena_read_spins(CORE_TESTED, written);

    // FYI ONLY -- this does not gate the LOADED verdict below. The debug spin write does not hold
    // reliably on this die, and its failures grow with hardware index, but reading spins back DOES
    // work, so the diff is a trustworthy account of what actually landed. J is loaded by a
    // different mechanism and is unaffected by any of this.
    uint32_t diff[LAGD_SPIN_NUM_WORDS];
    unsigned mismatches = 0;
    unsigned bucket[4] = {0, 0, 0, 0};
    for (unsigned w = 0; w < LAGD_SPIN_NUM_WORDS; w++) diff[w] = start[w] ^ written[w];
    for (unsigned i = 0; i < NUM_SPIN; i++)
        if ((diff[i / 32] >> (i % 32)) & 1u) {
            mismatches++;
            bucket[i / 64]++;
        }

    printf("--- initial state (FYI: the debug spin write is known to be unreliable) ---\r\n");
    refmodel_print_state("wanted", start);
    refmodel_print_state("onchip", written);
    printf("  %-7s: ", "diff");
    refmodel_print_hex(diff);
    printf("  %u of %u differ\r\n", mismatches, (unsigned)NUM_SPIN);
    printf("  by hardware index: [0-63]=%u [64-127]=%u [128-191]=%u [192-255]=%u\r\n", bucket[0],
           bucket[1], bucket[2], bucket[3]);

    printf("LOADED\r\n");
    printf("FINISH\r\n");

    lagd_chip_finish();
    return 0;
}
