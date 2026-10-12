// Copyright 2026 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Toon Bettens <toon.bettens@kuleuven.be>

// Bias review: Systematically check biasing configuration against many patterns.
//
// The contract under test, for some selected column `col`:
//   total(col) = sum(CU values in col) + SCALING_FACTOR * HU(col)
//   acc_probe(col) should report the sign of total(col)
//
// Case families:
//   A) SPARSE    -  CU-only, net offset packed into as few rows as possible at magnitude 7
//   B) DENSE     -  CU-only, same net offset spread one unit per row at magnitude 1
//   C) BALANCED  -  CU-only, big alternating background plus the net offset placed in a disjoint
//                   region low in the column
//   D) MIXED     -  Different pseudo-random value per row across the full -7..+7 range, both CU &
//                   HU participate
//   E) OPPOSED   -  CU net offset pushing one way, HU pushing the other

#ifndef CORE_TESTED
#define CORE_TESTED 1
#endif
#ifndef VERBOSE
#define VERBOSE 0
#endif
#ifndef SCALING_FACTOR
#define SCALING_FACTOR 8
#endif
// Restrict the sweep to the CU-only families (SPARSE, DENSE, BALANCED): MIXED and OPPOSED are the
// only ones that drive HU, so skipping them isolates the J dial from the two H dials.
#ifndef CU_ONLY
#define CU_ONLY 1
#endif
#ifndef REPEAT
#define REPEAT 5
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

// The h row is encoded exactly like J. This die reads the sign bit opposite to the encoder's
// intent, so h is negated before encoding -- the same convention every other scenario uses. This
// used to happen inside galena_encode_cu_for_row(); it is explicit here now.
#ifndef INVERT_H
#define INVERT_H 1
#endif

#include <stdint.h>
#include "printf.h"
#include "lagd_chip.h"
#include "lagd_bringup.h"
#include "lagd_galena_recipes.h"
#include "lagd_galena_patterns.h"

// --- Case matrix -------------------------------------------------------------

static const unsigned COLUMNS[] = {0, 1, 128, 254, 255};
#define NUM_COLUMNS (sizeof(COLUMNS) / sizeof(COLUMNS[0]))

static const int OFFSETS[] = {1, -1, 2, -2, 4, -4, 7, -7, 14, -14, 28, -28};
#define NUM_OFFSETS (sizeof(OFFSETS) / sizeof(OFFSETS[0]))

// MIXED: HU codes cycled through, and the shape of the random block.
static const int MIXED_HU[] = {1, -1, 2, -2};
#define NUM_MIXED_HU (sizeof(MIXED_HU) / sizeof(MIXED_HU[0]))
#ifndef MIXED_ROWS
#define MIXED_ROWS 24
#endif
#ifndef MIXED_START_ROW
#define MIXED_START_ROW 16
#endif
#ifndef MIXED_SEED
#define MIXED_SEED 0x5EED1234u
#endif

// OPPOSED: the CU net is built as -SCALING_FACTOR*hu + delta, so the total is exactly `delta` --
// how many CU units the case sits from the CU/HU balance point, and never 0 for any
// SCALING_FACTOR. The small-|delta| cases therefore measure SCALING_FACTOR directly.
static const int OPPOSED_HU[] = {1, -1, 2, -2};
#define NUM_OPPOSED_HU (sizeof(OPPOSED_HU) / sizeof(OPPOSED_HU[0]))
static const int OPPOSED_DELTA[] = {1, -1, 4, -4};
#define NUM_OPPOSED_DELTA (sizeof(OPPOSED_DELTA) / sizeof(OPPOSED_DELTA[0]))

// BALANCED: 2*BAL_COUNT rows alternating +/-BAL_MAGNITUDE centered on NUM_SPIN/2 (net zero), with
// the net offset dropped into a disjoint region starting at BAL_OFFSET_ROW.
#ifndef BAL_COUNT
#define BAL_COUNT 32
#endif
#ifndef BAL_MAGNITUDE
#define BAL_MAGNITUDE 4
#endif
#ifndef BAL_OFFSET_ROW
#define BAL_OFFSET_ROW 8
#endif

enum {
    FAM_SPARSE = 0,
    FAM_DENSE,
    FAM_BALANCED,
    FAM_MIXED,
    FAM_OPPOSED,
    FAM_COUNT,
};
static const char *const FAMILY_NAME[FAM_COUNT] = {"SPARSE", "DENSE", "BALANCE", "MIXED", "OPPOSED"};

static const int BUCKET_MAX[] = {2, 4, 8, 16, 32, 0x7FFFFFFF};
#define NUM_BUCKETS (sizeof(BUCKET_MAX) / sizeof(BUCKET_MAX[0]))
static const char *const BUCKET_NAME[NUM_BUCKETS] = {"<=2", "<=4", "<=8", "<=16", "<=32", ">32"};

// --- Tallies -----------------------------------------------------------------

typedef struct {
    unsigned scored;   // everything except UNSTBL
    unsigned match;    // measured bit == sign of the predicted total
    unsigned mismatch; // measured bit was the wrong way round
    unsigned unstable; // repeats disagreed
} tally_t;

static void tally_reset(tally_t *t) {
    t->scored = 0;
    t->match = 0;
    t->mismatch = 0;
    t->unstable = 0;
}

static tally_t tally_all;
static tally_t tally_family[FAM_COUNT];
static tally_t tally_column[NUM_COLUMNS];
static tally_t tally_bucket[NUM_BUCKETS];

// --- Bias skew ---------------------------------------------------------------
//
// Which side stable mismatches land on. A one-sided pile means the dial's zero-point is offset; an
// even split means noise around the decision point. The worst |total| that failed in a direction
// estimates how far off the zero-point sits, in CU units. Scope is picked by the case's HU value,
// since that decides which dial is in play.
typedef struct {
    unsigned scored;
    unsigned up;    // measured 1, expected 0
    unsigned down;  // measured 0, expected 1
    int up_worst;   // largest |total| that failed upward
    int down_worst; // largest |total| that failed downward
} skew_t;

static skew_t skew_j;   // hu == 0
static skew_t skew_hup; // hu > 0
static skew_t skew_hdn; // hu < 0

static void skew_reset(skew_t *s) {
    s->scored = 0;
    s->up = 0;
    s->down = 0;
    s->up_worst = 0;
    s->down_worst = 0;
}

static void skew_record(skew_t *s, int mismatched, unsigned measured, int abs_total) {
    s->scored++;
    if (!mismatched) return;
    if (measured) {
        s->up++;
        if (abs_total > s->up_worst) s->up_worst = abs_total;
    } else {
        s->down++;
        if (abs_total > s->down_worst) s->down_worst = abs_total;
    }
}

// --- Helpers -----------------------------------------------------------------

// Excludes the self-AU row: row == col has no effect on the accumulation line.
static int column_sum(const int column[NUM_SPIN], unsigned col) {
    int sum = 0;
    for (unsigned r = 0; r < NUM_SPIN; r++)
        if (r != col) sum += column[r];
    return sum;
}

static void build_balanced(int column[NUM_SPIN], int offset, unsigned col) {
    pattern_gen_alternate(column, BAL_COUNT, BAL_MAGNITUDE, col);

    int sign = (offset < 0) ? -1 : 1;
    unsigned remaining = (unsigned)(offset < 0 ? -offset : offset);
    unsigned row = BAL_OFFSET_ROW;
    while (remaining > 0 && row < NUM_SPIN / 2 - BAL_COUNT) {
        if (row != col && column[row] == 0) {
            column[row] = sign;
            remaining--;
        }
        row++;
    }
}

// Not a true RNG, instead a fixed xorshift32 sequence, so every MIXED pattern is reproducible.
static uint32_t xorshift32(uint32_t *state) {
    uint32_t x = *state;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    *state = x;
    return x;
}

// Random values, then nudged one unit at a time until the net sum lands on `offset`. Spreading the
// correction over the whole block keeps the column heterogeneous instead of saturating a few cells.
static void build_mixed(int column[NUM_SPIN], int offset, unsigned col, uint32_t seed) {
    for (unsigned r = 0; r < NUM_SPIN; r++) column[r] = 0;

    uint32_t rng = seed ? seed : 1u; // xorshift32 is stuck at 0
    unsigned placed = 0;
    unsigned row = MIXED_START_ROW;
    while (placed < MIXED_ROWS && row < NUM_SPIN) {
        if (row != col) {
            column[row] = (int)(xorshift32(&rng) % 15u) - 7; // -7..+7 inclusive
            placed++;
        }
        row++;
    }

    int delta = offset - column_sum(column, col);
    while (delta != 0) {
        int progressed = 0;
        unsigned touched = 0;
        unsigned r = MIXED_START_ROW;
        while (touched < MIXED_ROWS && r < NUM_SPIN && delta != 0) {
            if (r != col) {
                if (delta > 0 && column[r] < 7) {
                    column[r]++;
                    delta--;
                    progressed = 1;
                } else if (delta < 0 && column[r] > -7) {
                    column[r]--;
                    delta++;
                    progressed = 1;
                }
                touched++;
            }
            r++;
        }
        if (!progressed) break; // every cell saturated -- cannot reach the target exactly
    }
}

static void tally_case(tally_t *t, int scored, int matched, int mismatched, int unstable) {
    if (unstable) t->unstable++;
    if (scored) {
        t->scored++;
        if (matched) t->match++;
        if (mismatched) t->mismatch++;
    }
}

static unsigned skipped_zero = 0;

static void run_case(unsigned case_id, unsigned family, unsigned col_idx, const int column[NUM_SPIN],
                     int hu_value, const char *shape) {
    unsigned col = COLUMNS[col_idx];

    // Predicted from what was actually built, not from the requested offset: the generators skip
    // the self-AU row and clamp magnitudes, so the two can differ.
    int cu_net = column_sum(column, col);
    int total = cu_net + SCALING_FACTOR * hu_value;
    int abs_total = (total < 0) ? -total : total;

    if (total == 0) {
        printf("WARNING: case %u (%s col=%u %s cu=%+d hu=%+d) has total 0 -- no sign to check, "
               "skipped\r\n",
               case_id, FAMILY_NAME[family], col, shape, cu_net, hu_value);
        skipped_zero++;
        return;
    }

    uint32_t zero_spins[LAGD_SPIN_NUM_WORDS] = {0};
    galena_write_spins(CORE_TESTED, zero_spins);

    galena_write_column(CORE_TESTED, col, /*cu_values=*/column, /*hu_value=*/INVERT_H ? -hu_value : hu_value);

    unsigned ones = 0;
    for (unsigned r = 0; r < REPEAT; r++)
        ones += galena_acc_probe(CORE_TESTED, col, CYCLE_PER_READ, READ_NUM);

    int unstable = (ones != 0 && ones != REPEAT);
    unsigned measured = (ones * 2 >= REPEAT) ? 1u : 0u; // majority vote

    unsigned expected = (total > 0) ? 1u : 0u;
    int scored = !unstable;
    int matched = (scored && measured == expected);
    int mismatched = (scored && measured != expected);

    const char *verdict = unstable ? "UNSTBL" : matched ? "MATCH" : "MISMATCH";

    if (VERBOSE)
        printf("%3u %-10s col=%3u %-14s cu=%+5d hu=%+2d tot=%+6d exp=%u got=%u (%u/%u) %s\r\n",
               case_id, FAMILY_NAME[family], col, shape, cu_net, hu_value, total, expected, measured,
               ones, REPEAT, verdict);

    tally_case(&tally_all, scored, matched, mismatched, unstable);
    tally_case(&tally_family[family], scored, matched, mismatched, unstable);
    tally_case(&tally_column[col_idx], scored, matched, mismatched, unstable);
    for (unsigned b = 0; b < NUM_BUCKETS; b++) {
        if (abs_total <= BUCKET_MAX[b]) {
            tally_case(&tally_bucket[b], scored, matched, mismatched, unstable);
            break;
        }
    }

    if (scored) {
        skew_t *s = (hu_value > 0) ? &skew_hup : (hu_value < 0) ? &skew_hdn : &skew_j;
        skew_record(s, mismatched, measured, abs_total);
    }
}

// --- Report ------------------------------------------------------------------

// Total printed width of a summary-table row, so group dividers can span it exactly.
#define TALLY_WIDTH 53

static void print_tally_header(void) {
    printf("  %-10s | %6s | %5s | %5s | %4s | %6s\r\n", "scope", "scored", "match", "rate", "mism",
           "unstbl");
    printf("  -----------+--------+-------+-------+------+-------\r\n");
}

static void print_group(const char *name) {
    unsigned used = 6; // "  --- "
    for (const char *p = name; *p; p++) used++;
    used++; // the space after the name
    printf("  --- %s ", name);
    for (unsigned i = used; i < TALLY_WIDTH; i++) printf("-");
    printf("\r\n");
}

static void print_tally(const char *label, const tally_t *t) {
    unsigned rate = t->scored ? (100u * t->match) / t->scored : 0u;
    printf("  %-10s | %6u | %5u | %4u%% | %4u | %6u\r\n", label, t->scored, t->match, rate,
           t->mismatch, t->unstable);
}

static void print_skew_header(void) {
    printf("  %-4s | %6s | %4s | %6s | %4s | %6s | %s\r\n", "dial", "scored", "up", "uworst", "down",
           "dworst", "assessment");
    printf("  -----+--------+------+--------+------+--------+--------------------\r\n");
}

// HDN's labels are swapped relative to HUP: a negative HU pulling down harder than modelled shows
// up as a down-error, not an up-error.
static void print_skew(const char *label, const skew_t *s, const char *up_label,
                       const char *down_label) {
    const char *assessment = (s->up > s->down)   ? up_label
                             : (s->down > s->up) ? down_label
                                                 : "balanced";
    printf("  %-4s | %6u | %4u | %6d | %4u | %6d | %s\r\n", label, s->scored, s->up, s->up_worst,
           s->down, s->down_worst, assessment);
}

// --- Main --------------------------------------------------------------------

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

    tally_reset(&tally_all);
    for (unsigned i = 0; i < FAM_COUNT; i++) tally_reset(&tally_family[i]);
    for (unsigned i = 0; i < NUM_COLUMNS; i++) tally_reset(&tally_column[i]);
    for (unsigned i = 0; i < NUM_BUCKETS; i++) tally_reset(&tally_bucket[i]);
    skew_reset(&skew_j);
    skew_reset(&skew_hup);
    skew_reset(&skew_hdn);

    printf("=== BIAS REVIEW ===\r\n");
    printf("SCALING_FACTOR=%d%s\r\n", SCALING_FACTOR,
           CU_ONLY ? " (CU_ONLY: MIXED/OPPOSED skipped)" : "");
    printf("REPEAT=%d CYCLE_PER_READ=%d READ_NUM=%d\r\n", REPEAT, CYCLE_PER_READ, READ_NUM);
    printf("columns=%u offsets=%u balanced background=%ux+/-%d\r\n", (unsigned)NUM_COLUMNS,
           (unsigned)NUM_OFFSETS, 2 * BAL_COUNT, BAL_MAGNITUDE);
    if (VERBOSE) printf("--- cases ---\r\n");

    unsigned case_id = 0;
    int column[NUM_SPIN];

    for (unsigned c = 0; c < NUM_COLUMNS; c++) {
        unsigned col = COLUMNS[c];

        for (unsigned o = 0; o < NUM_OFFSETS; o++) {
            pattern_gen_offset(column, OFFSETS[o], /*magnitude=*/7, /*skip=*/col);
            run_case(case_id++, FAM_SPARSE, c, column, /*hu_value=*/0, "mag7-packed");
        }
        for (unsigned o = 0; o < NUM_OFFSETS; o++) {
            pattern_gen_offset(column, OFFSETS[o], /*magnitude=*/1, /*skip=*/col);
            run_case(case_id++, FAM_DENSE, c, column, /*hu_value=*/0, "mag1-spread");
        }
        for (unsigned o = 0; o < NUM_OFFSETS; o++) {
            build_balanced(column, OFFSETS[o], col);
            run_case(case_id++, FAM_BALANCED, c, column, /*hu_value=*/0, "alt-bg+net");
        }
        if (CU_ONLY) continue;

        for (unsigned o = 0; o < NUM_OFFSETS; o++) {
            // The CU side makes up whatever HU does not, so the total still lands on OFFSETS[o].
            int hu = MIXED_HU[o % NUM_MIXED_HU];
            uint32_t seed = (uint32_t)MIXED_SEED ^ (col * 2654435761u) ^ (o * 40503u);
            build_mixed(column, OFFSETS[o] - SCALING_FACTOR * hu, col, seed);
            run_case(case_id++, FAM_MIXED, c, column, hu, "rand-7..+7+hu");
        }
        for (unsigned h = 0; h < NUM_OPPOSED_HU; h++) {
            for (unsigned d = 0; d < NUM_OPPOSED_DELTA; d++) {
                int hu = OPPOSED_HU[h];
                int cu_target = -SCALING_FACTOR * hu + OPPOSED_DELTA[d];
                pattern_gen_offset(column, cu_target, /*magnitude=*/7, /*skip=*/col);
                run_case(case_id++, FAM_OPPOSED, c, column, hu, "cu-vs-hu");
            }
        }
    }

    if (skipped_zero)
        printf("WARNING: %u case(s) skipped for having a predicted total of 0\r\n", skipped_zero);

    printf("--- summary ---\r\n");
    print_tally_header();
    print_tally("TOTAL", &tally_all);
    print_group("by family");
    for (unsigned f = 0; f < FAM_COUNT; f++)
        if (tally_family[f].scored || tally_family[f].unstable)
            print_tally(FAMILY_NAME[f], &tally_family[f]);
    print_group("by column");
    for (unsigned c = 0; c < NUM_COLUMNS; c++) {
        char label[12];
        unsigned col = COLUMNS[c];
        label[0] = 'c';
        label[1] = 'o';
        label[2] = 'l';
        label[3] = (char)('0' + (col / 100) % 10);
        label[4] = (char)('0' + (col / 10) % 10);
        label[5] = (char)('0' + col % 10);
        label[6] = '\0';
        print_tally(label, &tally_column[c]);
    }
    print_group("by |total|");
    for (unsigned b = 0; b < NUM_BUCKETS; b++)
        if (tally_bucket[b].scored || tally_bucket[b].unstable)
            print_tally(BUCKET_NAME[b], &tally_bucket[b]);

    printf("--- bias skew ---\r\n");
    print_skew_header();
    print_skew("J", &skew_j, "PULL-UP stronger", "PULL-DOWN stronger");
    if (skew_hup.scored)
        print_skew("HUP", &skew_hup, "STRONGER than modelled", "WEAKER than modelled");
    if (skew_hdn.scored)
        print_skew("HDN", &skew_hdn, "WEAKER than modelled", "STRONGER than modelled");

    galena_zero_array(CORE_TESTED);
    galena_write_spins(CORE_TESTED, zero_spins);
    printf("array + spins zeroed on exit\r\n");

    printf("FINISH\r\n");

    lagd_chip_finish();
    return 0;
}
