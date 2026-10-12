// Copyright 2026 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Toon Bettens <toon.bettens@kuleuven.be>

// Settle the array and read the answer back. The other half of load_problem_l1.spm.c.
//
// This scenario writes NOTHING to the array: no J, no H, no spins, no zeroing. It assumes
// load_problem_l1.spm.c has already put the problem there and that it survived the chip reset in
// between. All it does is turn feedback on, read while feedback is live, and report the state.
//
// That split is what makes it useful for performance work: the load is paid once, and this part --
// the only part whose duration is interesting -- can be repeated and timed on its own, or swept
// over CYCLE_PER_READ / READ_NUM without reloading a 64x64 matrix every time.
//
// It reads the problem so it can report an ENERGY rather than a bare bitstring. That costs nothing
// in program size: the matrix lives in the core's l1_j_spm, which the linker fills and the ELF
// loader writes directly, so l2_spm still holds only the code. The one consequence is that this
// has to be rebuilt when the problem changes, same as monitor_capture -- `make perf` does all
// three together for exactly that reason.
//
// The capture happens WITH feedback still asserted; a bare feedback pulse captures nothing, which
// is why the read is what drives it (galena_compute_and_read_spins' own note).

#ifndef CORE_TESTED
#define CORE_TESTED 0
#endif
#ifndef CYCLE_PER_READ
#define CYCLE_PER_READ 2
#endif
#ifndef READ_NUM
#define READ_NUM 2
#endif
// Repeat the settle-and-read this many times, reporting each. Galena is analog and noisy, so the
// spread across repeats is data, not error.
#ifndef REPEATS
#define REPEATS 1
#endif
// Feedback on the reported window only (0) or all NUM_SPIN (1).
#ifndef FEEDBACK_ALL
#define FEEDBACK_ALL 0
#endif

#include <stdint.h>
#include "printf.h"
#include "lagd_chip.h"
#include "lagd_bringup.h"
#include "lagd_galena_recipes.h"

// The matrix rides in this core's l1_j_spm, not in the program image.
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

int main(void) {
    lagd_chip_init();

    printf("=== RUN + CAPTURE ===\r\n");
    printf("core=%u spins=%u at hw [%u,%u) cycle_per_read=%u read_num=%u repeats=%u\r\n",
           (unsigned)CORE_TESTED, (unsigned)BLOCK_SIZE, (unsigned)BLOCK_BASE, (unsigned)BLOCK_END,
           (unsigned)CYCLE_PER_READ, (unsigned)READ_NUM, (unsigned)REPEATS);

    // Host-side configuration only. lagd_core_apply_config touches CSRs, not the array, so the
    // problem loaded by load_problem_l1.spm.c is left intact.
    lagd_core_apply_config(CORE_TESTED, &LAGD_BASE_CONFIG);

    // Read back what is actually in the spin cache before doing anything, so a retention failure
    // between the two ELFs is visible rather than being mistaken for a bad result.
    uint32_t before[LAGD_SPIN_NUM_WORDS];
    galena_read_spins(CORE_TESTED, before);
    printf("--- initial state (as left by the loader) ---\r\n");
    refmodel_print_state("initial", before);

    uint32_t feedback[LAGD_SPIN_NUM_WORDS] = {0};
    for (unsigned i = 0; i < NUM_SPIN; i++)
        if (FEEDBACK_ALL || (i >= BLOCK_BASE && i < BLOCK_END))
            feedback[i / 32] |= (1u << (i % 32));

    printf("--- runs ---\r\n");
    printf("  %-4s | %8s | %s\r\n", "run", "energy", "spins");
    printf("  -----+----------+-------------------\r\n");

    for (unsigned r = 0; r < REPEATS; r++) {
        galena_stage_spin_feedback_pattern(CORE_TESTED, feedback);
        galena_stage_spin_read_timing(CORE_TESTED, CYCLE_PER_READ, READ_NUM);
        galena_enable_spin_out(CORE_TESTED, 1);
        galena_commit_spin_configure(CORE_TESTED);

        galena_trigger_spin_read(CORE_TESTED);
        galena_poll_spin_read_idle(CORE_TESTED);

        uint32_t out[LAGD_SPIN_NUM_WORDS];
        galena_read_spin_out(CORE_TESTED, out);

        printf("  %4u | %8d | ", r, refmodel_energy(out));
        refmodel_print_hex(out);
        printf("\r\n");
    }

    // Leave feedback off so the array is not left settling after the run.
    galena_stage_spin_feedback(CORE_TESTED, 0);
    galena_commit_spin_configure(CORE_TESTED);

    printf("FINISH\r\n");

    lagd_chip_finish();
    return 0;
}
