// Copyright 2026 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// The problem, read out of the arrays the reference flow builds. This is the ONLY problem source
// the galena scenarios use: sw/tools/gen_ising_problem.py writes tests/ref/data/<DATA_FOLDER>/,
// utils/gen_model_data.py turns that into model_j_data.h, the linker places it in this core's
// l1_j_spm, and the ELF loader fills it. Same bytes for tests/ref/ and tests/galena/perf/.
//
// INDEX SPACES -- the one thing to keep straight. gen_model_data.py stores logical column j and
// logical spin j at HARDWARE index NUM_SPIN-1-j, and lagd_debug_load.h applies the matching
// permutation to rows. Everything here is LOGICAL: refmodel_j(i,j) is the coupling between
// logical spins i and j. Spin vectors read off the chip are HARDWARE-indexed, so go through
// refmodel_hw() to read them in logical order. Any loader writing this problem into the array
// must use the same permutation, or the array holds a different problem than the host scores.

#pragma once

#include <stdint.h>
#include "printf.h"
#include "lagd_define.h"

#ifndef CORE_TESTED
#define CORE_TESTED 0
#endif

// gen_model_data.py emits one set of arrays per core, each placed in that core's own l1_j_spm.
#if CORE_TESTED == 0
#include "model_j_data.h"
#include "spin_data.h"
#define REFMODEL_J model_j_data
#define REFMODEL_H model_h_data
#define REFMODEL_INITIAL spin_initial_0
#define REFMODEL_SCALING_H model_scaling_factor
#else
#include "model_j_data_sec.h"
#include "spin_data_sec.h"
#define REFMODEL_J model_j_data_sec
#define REFMODEL_H model_h_data_sec
#define REFMODEL_INITIAL spin_initial_0_sec
#define REFMODEL_SCALING_H model_scaling_factor_sec
#endif

#define REFMODEL_SIZE NUM_SPIN

// Must match MIRROR_TO_LOW_SPINS in sw/tools/gen_ising_problem.py. The generator reverses the
// arrays so that gen_model_data.py's own NUM_SPIN-1-j reversal cancels out and logical spin i
// lands at HARDWARE index i -- which keeps small problems in the low cells, where the debug spin
// write actually works. Flip both together, or the host will score a different problem than the
// one in the array.
#ifndef REFMODEL_MIRROR
#define REFMODEL_MIRROR 1
#endif

// Index of logical spin i within the packed file arrays...
#if REFMODEL_MIRROR
#define REFMODEL_FILE(i) (NUM_SPIN - 1u - (unsigned)(i))
#else
#define REFMODEL_FILE(i) ((unsigned)(i))
#endif
// ...and its hardware index: gen_model_data.py puts file index f at hardware NUM_SPIN-1-f.
#define REFMODEL_HW(i) (NUM_SPIN - 1u - REFMODEL_FILE(i))

// model_j_data is uint64_t[4096]: 16 words per row, 16 couplings per word. Within a row the
// 16-column groups are stored in REVERSED order, and within a group the first column sits in the
// most significant nibble.
#define REFMODEL_WORDS_PER_ROW (NUM_SPIN / 16)
#define REFMODEL_J_WORDS (NUM_SPIN * REFMODEL_WORDS_PER_ROW)

// Coupling between logical spins i and j, sign-extended from its 4-bit field.
static inline int refmodel_j(unsigned i, unsigned j) {
    unsigned fi = REFMODEL_FILE(i), fj = REFMODEL_FILE(j);
    uint64_t word = REFMODEL_J[fi * REFMODEL_WORDS_PER_ROW + (15u - (fj >> 4))];
    unsigned nib = (unsigned)((word >> ((15u - (fj & 15u)) * 4u)) & 0xFu);
    return (nib & 0x8u) ? (int)nib - 16 : (int)nib;
}

// Field on logical spin i. model_h_data packs 8 per uint32_t, MSB first, with the words
// themselves emitted from the top of the vector downwards -- so logical i lands in word
// (NUM_SPIN-1-i)/8 at nibble ((NUM_SPIN-1-i)%8).
static inline int refmodel_h(unsigned i) {
    unsigned k = (NUM_SPIN - 1u - REFMODEL_FILE(i));
    unsigned nib = (unsigned)((REFMODEL_H[k >> 3] >> ((k & 7u) * 4u)) & 0xFu);
    return (nib & 0x8u) ? (int)nib - 16 : (int)nib;
}

// Is this logical spin part of the problem at all? A problem smaller than the array is
// zero-padded, and the padding has no couplings and no field -- so it contributes nothing to the
// energy, so driving them with feedback settles them on nothing, costs power, and lets them drift
// run to run. Used to bound the feedback mask; printing and energy still cover the whole array.
//
// A genuinely isolated spin (no couplings, no field) in a real problem would be classified as
// padding too. That is the right call here -- feedback on it means nothing either way.
static inline int refmodel_active(unsigned i) {
    if (refmodel_h(i) != 0) return 1;
    for (unsigned j = 0; j < REFMODEL_SIZE; j++)
        if (j != i && refmodel_j(i, j) != 0) return 1;
    return 0;
}

// One past the highest active logical spin: the real problem size. Padding sits at the end, so
// this is the length of the meaningful prefix. Computed once and cached -- the scan is O(n^2).
static inline unsigned refmodel_size(void) {
    static unsigned cached = 0;
    static int done = 0;
    if (!done) {
        for (unsigned i = 0; i < REFMODEL_SIZE; i++)
            if (refmodel_active(i)) cached = i + 1;
        done = 1;
    }
    return cached;
}

// Hardware index of a logical spin.
static inline unsigned refmodel_hw(unsigned logical) { return REFMODEL_HW(logical); }

// The starting state, already in HARDWARE bit order (gen_spin_data.py packs the last character
// of the state line into bit 0), so it can be handed straight to galena_write_spins().
static inline int refmodel_initial_spin(unsigned logical) {
    unsigned h = refmodel_hw(logical);
    return ((REFMODEL_INITIAL[h / 32] >> (h % 32)) & 1u) ? 1 : -1;
}

// Rolling checksum over the packed J words, so a loader can report that what it read out of L1
// is what the generator put there. gen_ising_problem.py prints the expected value.
static inline uint32_t refmodel_j_checksum(void) {
    uint32_t chk = 0;
    for (unsigned w = 0; w < REFMODEL_J_WORDS; w++) {
        chk = chk * 31u + (uint32_t)(REFMODEL_J[w] & 0xFFFFFFFFu);
        chk = chk * 31u + (uint32_t)(REFMODEL_J[w] >> 32);
    }
    return chk;
}

// E = - sum_{i<j} J[i][j] s_i s_j - scaling_h * sum_i H[i] s_i, over a HARDWARE-indexed vector.
// The generator's convention, so these numbers compare directly with what it prints.
static inline int refmodel_energy(const uint32_t spins[NUM_SPIN / 32]) {
    int energy = 0;
    for (unsigned i = 0; i < REFMODEL_SIZE; i++) {
        unsigned hi = refmodel_hw(i);
        int si = ((spins[hi / 32] >> (hi % 32)) & 1u) ? 1 : -1;
        for (unsigned j = i + 1; j < REFMODEL_SIZE; j++) {
            unsigned hj = refmodel_hw(j);
            int sj = ((spins[hj / 32] >> (hj % 32)) & 1u) ? 1 : -1;
            energy -= refmodel_j(i, j) * si * sj;
        }
        // The h term carries the model's scaling factor, matching the digital engine:
        // partial_energy_calc.sv:85 computes hbias * hscaling before summing. It arrives from the
        // model file's line 518 via model_scaling_factor, so nothing extra has to be passed in.
        energy -= refmodel_h(i) * (int)REFMODEL_SCALING_H * si;
    }
    return energy;
}

// --- state printing ---------------------------------------------------------
// States print as hex in LOGICAL order: the leftmost hex digit holds logical spins 0..3, spin 0
// in its most significant bit, so a hex line reads left-to-right the same way the bit string did
// -- just four times denser. Digits are grouped in eights, one group per 32 logical spins, so the
// same column in two lines is the same spin.

static inline void refmodel_print_hex(const uint32_t spins[NUM_SPIN / 32]) {
    for (unsigned d = 0; d < REFMODEL_SIZE / 4; d++) {
        unsigned nib = 0;
        for (unsigned b = 0; b < 4; b++) {
            unsigned h = refmodel_hw(d * 4 + b);
            nib = (nib << 1) | ((spins[h / 32] >> (h % 32)) & 1u);
        }
        printf("%x", nib);
        if ((d & 7u) == 7u && d + 1 < REFMODEL_SIZE / 4) printf(" ");
    }
}

static inline void refmodel_print_state(const char *label, const uint32_t spins[NUM_SPIN / 32]) {
    printf("  %-7s: ", label);
    refmodel_print_hex(spins);
    printf("  energy=%d\r\n", refmodel_energy(spins));
}
