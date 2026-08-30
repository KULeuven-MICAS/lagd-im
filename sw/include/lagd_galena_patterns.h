#pragma once

#include "lagd_galena.h"

// ---------------------------------------------------------------------------------------------
// Generators
//
// Each of these fills a values[NUM_SPIN] array of per-row J-CU coupling values, meant to be
// programmed onto one column via galena_write_column/galena_write_all_columns. `skip` excludes a
// row index from being written (typically the target column itself, to leave out self-coupling).
// ---------------------------------------------------------------------------------------------

// Balanced/one-sided step: neg_count rows of -magnitude followed by pos_count rows of +magnitude,
// centered around NUM_SPIN/2. Equal neg_count/pos_count gives a balanced (zero-sum) pattern;
// making one of them 0 gives a one-sided pattern with a net nonzero sum. Used for bias
// calibration (see galena_calibrate.spm.c): balanced pattern + H_VALUE=0 exercises j_up/j_dn, a
// one-sided pattern exercises h_up/h_dn.
static void pattern_gen_step(int values[NUM_SPIN], unsigned neg_count, unsigned pos_count,
                             int magnitude, unsigned skip) {
    for (unsigned i = 0; i < NUM_SPIN; i++) values[i] = 0;

    unsigned row = NUM_SPIN / 2 - neg_count;
    unsigned placed = 0;
    while (placed < neg_count) {
        if (row != skip) {
            values[row] = -magnitude;
            placed++;
        }
        row++;
    }
    placed = 0;
    while (placed < pos_count) {
        if (row != skip) {
            values[row] = magnitude;
            placed++;
        }
        row++;
    }
}

// Solid block: 2*count consecutive rows centered around NUM_SPIN/2, all set to the same
// +/-magnitude (sign taken from `magnitude`'s sign). Same shape/footprint as pattern_gen_step, but
// one uniform block instead of a neg-half/pos-half split -- net sum scales with count instead of
// staying balanced or one-sided.
static void pattern_gen_block(int values[NUM_SPIN], unsigned count, int magnitude, unsigned skip) {
    for (unsigned i = 0; i < NUM_SPIN; i++) values[i] = 0;

    unsigned row = NUM_SPIN / 2 - count;
    unsigned placed = 0;
    while (placed < 2 * count) {
        if (row != skip) {
            values[row] = magnitude;
            placed++;
        }
        row++;
    }
}

// Alternating +/-magnitude values on 2*count rows centered around NUM_SPIN/2, starting with
// -magnitude and flipping sign each placed row. Net sum is always zero regardless of count;
// unlike pattern_gen_step's single block of each sign, this interleaves them row-by-row, useful
// for probing crosstalk between physically adjacent rows.
static void pattern_gen_alternate(int values[NUM_SPIN], unsigned count, int magnitude, unsigned skip) {
    for (unsigned i = 0; i < NUM_SPIN; i++) values[i] = 0;

    unsigned row = NUM_SPIN / 2 - count;
    unsigned placed = 0;
    int sign = -1;
    while (placed < 2 * count) {
        if (row != skip) {
            values[row] = sign * magnitude;
            sign = -sign;
            placed++;
        }
        row++;
    }
}

// Spreads a total signed `offset` across as few rows as possible, each row taking up to
// +/-magnitude (all rows the same sign as offset), starting from NUM_SPIN/2. Unlike the other
// generators this targets a specific net coupling total rather than a fixed shape -- used for
// gradient sweeps where the desired net J/H strength is swept in fine steps but each CU can only
// hold a limited per-row magnitude.
static void pattern_gen_offset(int values[NUM_SPIN], int offset, unsigned magnitude, unsigned skip) {
    for (unsigned i = 0; i < NUM_SPIN; i++) values[i] = 0;

    int sign = (offset < 0) ? -1 : 1;
    unsigned remaining = (unsigned)(offset < 0 ? -offset : offset);
    unsigned row = NUM_SPIN / 2;

    while (remaining > 0) {
        if (row != skip) {
            unsigned mag = (remaining >= magnitude) ? magnitude : remaining;
            values[row] = sign * (int)mag;
            remaining -= mag;
        }
        row++;
    }
}

// ---------------------------------------------------------------------------------------------
// Named patterns
// ---------------------------------------------------------------------------------------------

// No coupling on any row -- baseline/reset pattern.
static const int pattern_zero[NUM_SPIN] = {0};

// -5 on rows 1 through 16 inclusive, every other row 0.
static const int pattern_neg5_rows_1_16[NUM_SPIN] = {
    [1] = 5,  [2] = 5,  [3] = 5,  [4] = 5,  [5] = 5,  [6] = 5,  [7] = 5,  [8] = 5,
    [9] = 5,  [10] = 5, [11] = 5, [12] = 5, [13] = 5, [14] = 5, [15] = 5, [16] = 5,
};
