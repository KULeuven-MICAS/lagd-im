#pragma once

#include "lagd_galena.h"

// Write a full 1024-bit WBL pattern into a given row.
static void galena_write_row(unsigned core, unsigned row, const uint32_t pattern[LAGD_WBL_NUM_WORDS]) {
    galena_stage_wbl_floating(core, 1);
    galena_stage_wbl_pattern(core, pattern);
    galena_select_wwl_row(core, row);
    galena_commit_dt_configure(core);
    galena_trigger_dt_write(core);
    galena_poll_dt_write_idle(core);
}

// Read back a full row.
static void galena_read_row(unsigned core, unsigned row, uint32_t wbl_out[LAGD_WBL_NUM_WORDS], uint32_t wblb_out[LAGD_WBL_NUM_WORDS]) {
    galena_stage_wbl_floating(core, 0);
    galena_select_wwl_row(core, row);
    galena_commit_dt_configure(core);
    galena_trigger_dt_read(core);
    galena_poll_dt_read_idle(core);

    galena_read_wbl(core, wbl_out);
    galena_read_wblb(core, wblb_out);
}

// Write a 256-bit spin pattern into the spin cache.
static void galena_write_spins(unsigned core, const uint32_t spins[LAGD_SPIN_NUM_WORDS]) {
    galena_stage_wbl_floating(core, 1);
    galena_stage_wbl_spins(core, spins);
    galena_stage_spin_wwl(core, 1);
    galena_commit_spin_configure(core);
    galena_trigger_spin_write(core);
    galena_poll_spin_write_idle(core);

    // Leave no strobe staged, so a later configure cannot latch spins by accident.
    galena_stage_spin_wwl(core, 0);
    galena_commit_spin_configure(core);
}

// Snapshot the 256 spins.
static void galena_read_spins(unsigned core, uint32_t out[LAGD_SPIN_NUM_WORDS]) {
    galena_stage_spin_feedback(core, 0);
    galena_stage_spin_read_timing(core, /*cycle_per_read=*/1, /*read_num=*/1);
    galena_enable_spin_out(core, 1);
    galena_commit_spin_configure(core);

    galena_trigger_spin_read(core);
    galena_poll_spin_read_idle(core);

    galena_read_spin_out(core, out);
}

// Safely switch which of the wwl_vdd/wwl_vread pair drives the array.
static void galena_switch_wwl_supply(unsigned core, int vdd_active) {
    galena_stage_wwl_vdd(core, 0);
    galena_stage_wwl_vread(core, 0);
    galena_commit_dt_configure(core);

    if (vdd_active) galena_stage_wwl_vdd(core, 1);
    else             galena_stage_wwl_vread(core, 1);
    galena_commit_dt_configure(core);
}
