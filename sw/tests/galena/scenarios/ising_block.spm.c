// Copyright 2026 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Toon Bettens <toon.bettens@kuleuven.be>

// Solve a hand-written Ising problem on a small window of the array, using the debug write path.
//
// Only part of the array is reliably writeable, so the problem is confined to a BLOCK_SIZE window
// at BLOCK_BASE. Everything else in the array is zeroed and left alone. On this sample the LOW
// spins are the trustworthy ones, hence BLOCK_BASE 0; on the previous one it was the high end, so
// that was BLOCK_BASE (NUM_SPIN - BLOCK_SIZE).
//
// Index convention -- logical spin i is simply the i-th spin of the window:
//
//     hw(i) = BLOCK_BASE + i        i = 0 .. BLOCK_SIZE-1
//
// J, H and SPINS below are all indexed logically, and the readback is reported the same way.
//
// J[i][j] is the coupling from logical spin i onto logical spin j's accumulation line, which lands
// on the CU at hardware row hw(i), column hw(j). For a symmetric J the distinction does not matter.
// J[i][i] is the column's own AU rather than a CU and has no effect, so it must be 0.
//
// Sequence: zero everything -> write J and H -> write the starting spins -> verify the write ->
// turn feedback on for the whole block at once -> read back the converged state.

#ifndef CORE_TESTED
#define CORE_TESTED 0
#endif
// Lowest hardware spin the problem occupies; the window is [BLOCK_BASE, BLOCK_BASE+BLOCK_SIZE).
// 0 puts it at the low end of the array, (NUM_SPIN - BLOCK_SIZE) at the high end.
#ifndef BLOCK_BASE
#define BLOCK_BASE 0
#endif
// Changing this means rewriting J, H and SPINS below to match -- they are literal tables, not
// generated, so it is not a -D knob in any useful sense.
#ifndef BLOCK_SIZE
#define BLOCK_SIZE 5
#endif
// Feedback on the block only (0) or on all NUM_SPIN spins (1). The rest of the array is zeroed
// either way, so the two should agree; the block-only default leaves untouched spins undisturbed.
#ifndef FEEDBACK_ALL
#define FEEDBACK_ALL 0
#endif
// Sign polarity. A value written into a CU reaches the array with its sign inverted -- this is the
// same effect the ferromagnetic scenarios ran into, where a -1 coupling had to be written to get
// ferromagnetic behaviour. J is therefore negated on the way in, so the tables below hold the
// physics you actually want.
//
// H is negated on exactly the same footing as J: the shared plumbing encodes the H-row with
// galena_encode_cu(), the same call every J row goes through, so there is no hidden correction
// and INVERT_H means what it says. Set INVERT_H to 0 if the H-row turns out to be wired the
// this die too -- but do not set both without checking, or H ends up double-negated and unchanged.
#ifndef INVERT_J
#define INVERT_J 1
#endif
#ifndef INVERT_H
#define INVERT_H 1
#endif

// Host-side energy of the initial and final states, for comparison against what the array settles
// on. Set to 0 to leave it out entirely.
#ifndef HOST_ENERGY
#define HOST_ENERGY 1
#endif
// The energy is an O(BLOCK_SIZE^2) integer sum over every spin pair. Cheap at these sizes, but the
// cap keeps it from quietly turning into real work on a larger block.
#ifndef HOST_ENERGY_MAX_SIZE
#define HOST_ENERGY_MAX_SIZE 32
#endif

#ifndef WWL_CYCLES
#define WWL_CYCLES 100
#endif
#ifndef SPIN_WRITE_CYCLES
#define SPIN_WRITE_CYCLES 100
#endif
#ifndef CYCLE_PER_READ
#define CYCLE_PER_READ 100
#endif
#ifndef READ_NUM
#define READ_NUM 1
#endif

#include <stdint.h>
#include "printf.h"
#include "lagd_chip.h"
#include "lagd_bringup.h"
#include "lagd_galena_recipes.h"

// --- The problem -------------------------------------------------------------
// All entries -7..+7. Row i is logical spin i. The diagonal must stay 0.

static const int J[BLOCK_SIZE][BLOCK_SIZE] = {
    {0,  -1, -1, 0,  0},
    {-1, 0,  0,  -1, 0},
    {-1, 0,  0,  -1, -1},
    {0,  -1, -1, 0,  -1},
    {0,  0,  -1, -1, 0},
};

static const int H[BLOCK_SIZE] = {0, 0, 0, 0, 0};

static const int SPINS[BLOCK_SIZE] = {0, 0, 1, 1, 0};

#if HOST_ENERGY && (BLOCK_SIZE > HOST_ENERGY_MAX_SIZE)
#error "BLOCK_SIZE exceeds HOST_ENERGY_MAX_SIZE: raise the cap or build with -DHOST_ENERGY=0"
#endif

// --- Index mapping -----------------------------------------------------------

// Logical spin index -> hardware spin index.
static unsigned hw(unsigned logical) { return BLOCK_BASE + logical; }

// One past the window's highest hardware spin.
#define BLOCK_END (BLOCK_BASE + BLOCK_SIZE)

// --- Helpers -----------------------------------------------------------------

// Print BLOCK_SIZE bits in logical order: leftmost character is logical spin 0.
static void print_block(const char *label, const uint32_t spins[LAGD_SPIN_NUM_WORDS]) {
    printf("%s: ", label);
    for (unsigned i = 0; i < BLOCK_SIZE; i++) {
        unsigned h = hw(i);
        printf("%u", (spins[h / 32] >> (h % 32)) & 1u);
    }
    printf("\r\n");
}

#if HOST_ENERGY
// A stored bit of 1 means spin +1, a 0 means spin -1.
static int spin_value(const uint32_t spins[LAGD_SPIN_NUM_WORDS], unsigned logical) {
    unsigned h = hw(logical);
    return ((spins[h / 32] >> (h % 32)) & 1u) ? 1 : -1;
}

// Ising energy of a state, in the usual convention
//
//     E = - sum_{i<j} J[i][j] * s_i * s_j  -  sum_i H[i] * s_i
//
// Each unordered pair is counted once, using the upper-triangle entry. That is only unambiguous
// for a symmetric J -- the array itself applies J[i][j] and J[j][i] independently as the fields on
// spins j and i, so an asymmetric matrix has no single energy and check_problem() says so.
// Whether this sign convention matches the chip's own energy engine is not established here. The
// energy uses J and H as written in the tables -- the intended physics -- not the inverted values
// that go onto the wires, so it stays meaningful regardless of INVERT_J/INVERT_H.
static int host_energy(const uint32_t spins[LAGD_SPIN_NUM_WORDS]) {
    int energy = 0;
    for (unsigned i = 0; i < BLOCK_SIZE; i++) {
        int si = spin_value(spins, i);
        for (unsigned j = i + 1; j < BLOCK_SIZE; j++)
            energy -= J[i][j] * si * spin_value(spins, j);
        energy -= H[i] * si;
    }
    return energy;
}
#endif

// Range-check the problem before touching the chip, since an out-of-range magnitude would be
// silently truncated by the 4-bit encoding into something else entirely.
static unsigned check_problem(void) {
    unsigned bad = 0;
    for (unsigned i = 0; i < BLOCK_SIZE; i++) {
        for (unsigned j = 0; j < BLOCK_SIZE; j++) {
            if (J[i][j] < -7 || J[i][j] > 7) {
                printf("BAD: J[%u][%u] = %d outside -7..+7\r\n", i, j, J[i][j]);
                bad++;
            }
            if (i == j && J[i][j] != 0) {
                printf("BAD: J[%u][%u] = %d, the diagonal is the AU and must be 0\r\n", i, j,
                       J[i][j]);
                bad++;
            }
        }
#if HOST_ENERGY
        for (unsigned j = i + 1; j < BLOCK_SIZE; j++)
            if (J[i][j] != J[j][i])
                printf("NOTE: J[%u][%u]=%d and J[%u][%u]=%d differ; the host energy uses the "
                       "upper-triangle entry only\r\n",
                       i, j, J[i][j], j, i, J[j][i]);
#endif
        if (H[i] < -7 || H[i] > 7) {
            printf("BAD: H[%u] = %d outside -7..+7\r\n", i, H[i]);
            bad++;
        }
        if (SPINS[i] != 0 && SPINS[i] != 1) {
            printf("BAD: SPINS[%u] = %d, expected 0 or 1\r\n", i, SPINS[i]);
            bad++;
        }
    }
    return bad;
}

int main(void) {
    lagd_chip_init();

    printf("=== ISING BLOCK %u ===\r\n", (unsigned)BLOCK_SIZE);
    printf("block at hw [%u, %u): logical 0 -> hw %u, logical %u -> hw %u\r\n",
           (unsigned)BLOCK_BASE, (unsigned)BLOCK_END, hw(0), (unsigned)BLOCK_SIZE - 1,
           hw(BLOCK_SIZE - 1));

    if (check_problem()) {
        printf("problem rejected, nothing written\r\n");
        printf("FINISH\r\n");
        lagd_chip_finish();
        return 1;
    }

    lagd_core_apply_config(CORE_TESTED, &LAGD_BASE_CONFIG);
    galena_stage_wwl_timing(CORE_TESTED, WWL_CYCLES, WWL_CYCLES);
    galena_commit_dt_configure(CORE_TESTED);
    galena_stage_spin_write_timing(CORE_TESTED, SPIN_WRITE_CYCLES);
    galena_commit_spin_configure(CORE_TESTED);

    galena_zero_array(CORE_TESTED);
    uint32_t zero_spins[LAGD_SPIN_NUM_WORDS] = {0};
    galena_write_spins(CORE_TESTED, zero_spins);

    // One hardware row per logical row of J. galena_write_row_values takes the window's columns in
    // order from BLOCK_BASE, which with this mapping is logical column order.
    for (unsigned i = 0; i < BLOCK_SIZE; i++) {
        int row_values[BLOCK_SIZE];
        for (unsigned j = 0; j < BLOCK_SIZE; j++) row_values[j] = INVERT_J ? -J[i][j] : J[i][j];
        galena_write_row_values(CORE_TESTED, hw(i), row_values, BLOCK_BASE, BLOCK_SIZE);
    }

    // The h-row is row NUM_SPIN, one HU per column. galena_write_row_values already routes through
    // galena_encode_cu(), the same encoder every J row uses, so INVERT_H is the only correction on
    // top of that and is off by default.
    {
        int h_values[BLOCK_SIZE];
        for (unsigned i = 0; i < BLOCK_SIZE; i++) h_values[i] = INVERT_H ? -H[i] : H[i];
        galena_write_row_values(CORE_TESTED, NUM_SPIN, h_values, BLOCK_BASE, BLOCK_SIZE);
    }

    printf("J (%ux%u) and H loaded (invert_j=%u invert_h=%u)\r\n", (unsigned)BLOCK_SIZE,
           (unsigned)BLOCK_SIZE, (unsigned)INVERT_J, (unsigned)INVERT_H);

    uint32_t start_spins[LAGD_SPIN_NUM_WORDS] = {0};
    for (unsigned i = 0; i < BLOCK_SIZE; i++)
        if (SPINS[i]) start_spins[hw(i) / 32] |= (1u << (hw(i) % 32));
    galena_write_spins(CORE_TESTED, start_spins);
    print_block("start   ", start_spins);

    // Read the spin cache straight back, before any feedback, to confirm what actually landed.
    uint32_t written[LAGD_SPIN_NUM_WORDS];
    galena_read_spins(CORE_TESTED, written);
    print_block("written ", written);

    unsigned mismatches = 0;
    for (unsigned i = 0; i < NUM_SPIN; i++) {
        unsigned expected = (start_spins[i / 32] >> (i % 32)) & 1u;
        unsigned actual = (written[i / 32] >> (i % 32)) & 1u;
        if (expected != actual) {
            printf("mismatch at hw spin %u: expected %u, got %u\r\n", i, expected, actual);
            mismatches++;
        }
    }
    if (mismatches)
        printf("WRITE CHECK FAIL (%u mismatches)\r\n", mismatches);
    else
        printf("WRITE CHECK PASS\r\n");

#if HOST_ENERGY
    // Computed from the state read back, not the one requested, so a partial write shows up in the
    // number rather than being papered over.
    int energy_initial = host_energy(written);
#endif

    // Feedback on for the whole block at once, then read while it is still driving -- a bare
    // feedback pulse captures nothing, the read has to happen with feedback live.
    uint32_t feedback[LAGD_SPIN_NUM_WORDS] = {0};
    for (unsigned i = 0; i < NUM_SPIN; i++)
        if (FEEDBACK_ALL || (i >= BLOCK_BASE && i < BLOCK_END))
            feedback[i / 32] |= (1u << (i % 32));
    galena_stage_spin_feedback_pattern(CORE_TESTED, feedback);
    galena_stage_spin_read_timing(CORE_TESTED, CYCLE_PER_READ, READ_NUM);
    galena_enable_spin_out(CORE_TESTED, 1);
    galena_commit_spin_configure(CORE_TESTED);

    galena_trigger_spin_read(CORE_TESTED);
    galena_poll_spin_read_idle(CORE_TESTED);

    uint32_t converged[LAGD_SPIN_NUM_WORDS];
    galena_read_spin_out(CORE_TESTED, converged);
    print_block("converged", converged);

#if HOST_ENERGY
    int energy_final = host_energy(converged);
    printf("host energy: initial %d -> final %d (delta %d)\r\n", energy_initial, energy_final,
           energy_final - energy_initial);
#endif

    galena_stage_spin_feedback(CORE_TESTED, 0);
    galena_commit_spin_configure(CORE_TESTED);

    printf("FINISH\r\n");

    lagd_chip_finish();
    return 0;
}
