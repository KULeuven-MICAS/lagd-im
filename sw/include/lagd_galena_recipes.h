#pragma once

#include "lagd_galena.h"

// Write a full 1024-bit WBL pattern into a given row.
static void galena_write_row(unsigned core, unsigned row,
                             const uint32_t pattern[LAGD_WBL_NUM_WORDS]) {
    galena_stage_wbl_floating(core, 1);
    galena_stage_wbl_pattern(core, pattern);
    galena_select_wwl_row(core, row);
    galena_commit_dt_configure(core);
    galena_trigger_dt_write(core);
    galena_poll_dt_write_idle(core);
}

// Read back a full row.
static void galena_read_row(unsigned core, unsigned row, uint32_t wbl_out[LAGD_WBL_NUM_WORDS],
                            uint32_t wblb_out[LAGD_WBL_NUM_WORDS]) {
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

// Write exactly one spin's flip-flop using a caller-supplied WBL vector, leaving every other
// spin's stored value untouched. Unlike the WBL/dt row path (which always drives the full
// 1024-bit vector), the spin write path has a genuine per-spin strobe (spin_wwl), so a single spin
// can be targeted without disturbing the rest -- but nothing stops the caller from also driving
// other (adjacent, or otherwise unrelated) WBL bits high in the same pulse, e.g. to probe for
// crosstalk; only the strobed spin's flip-flop actually latches anything.
static void galena_write_single_spin_raw(unsigned core, unsigned spin_index,
                                         const uint32_t wbl[LAGD_WBL_NUM_WORDS]) {
    uint32_t strobe[LAGD_SPIN_NUM_WORDS] = {0};
    strobe[spin_index / 32] |= (1u << (spin_index % 32));

    galena_stage_wbl_floating(core, 1);
    galena_stage_wbl_pattern(core, wbl);
    lagd_core_write_vector(core, LAGD_CORE_SPIN_WWL_STROBE_0_REG_OFFSET, strobe,
                           LAGD_SPIN_NUM_WORDS);
    galena_commit_spin_configure(core);
    galena_trigger_spin_write(core);
    galena_poll_spin_write_idle(core);

    // Leave no strobe staged, so a later configure cannot latch spins by accident.
    galena_stage_spin_wwl(core, 0);
    galena_commit_spin_configure(core);
}

// Write exactly one spin's flip-flop to 0/1, leaving every other WBL bit low.
static void galena_write_single_spin(unsigned core, unsigned spin_index, int value) {
    uint32_t wbl[LAGD_WBL_NUM_WORDS] = {0};
    if (value) {
        unsigned bit = BIT_H * spin_index + SPIN_WBL_OFFSET;
        wbl[bit / 32] |= (1u << (bit % 32));
    }
    galena_write_single_spin_raw(core, spin_index, wbl);
}

// Snapshot the 256 spins.
static void galena_read_spins(unsigned core, uint32_t out[LAGD_SPIN_NUM_WORDS]) {
    galena_stage_spin_feedback(core, 0);
    // cycle_per_read=1 was found unreliable on real hardware (never actually samples); 5 is safe.
    galena_stage_spin_read_timing(core, /*cycle_per_read=*/5, /*read_num=*/1);
    galena_enable_spin_out(core, 1);
    galena_commit_spin_configure(core);

    galena_trigger_spin_read(core);
    galena_poll_spin_read_idle(core);

    galena_read_spin_out(core, out);
}


// Turn feedback on for exactly one spin (every other spin's feedback line left low), drive it for
// cycle_per_read*read_num cycles, and read back the resulting 256 spins. Mirrors
// galena_compute_and_read_spins, but feedback is scoped to a single spin instead of all of them.
static void galena_compute_and_read_single_spin_feedback(unsigned core, unsigned spin_index,
                                                         uint32_t out[LAGD_SPIN_NUM_WORDS],
                                                         unsigned cycle_per_read,
                                                         unsigned read_num) {
    uint32_t feedback[LAGD_SPIN_NUM_WORDS] = {0};
    feedback[spin_index / 32] |= (1u << (spin_index % 32));

    galena_stage_spin_feedback_pattern(core, feedback);
    galena_stage_spin_read_timing(core, cycle_per_read, read_num);
    galena_enable_spin_out(core, 1);
    galena_commit_spin_configure(core);

    galena_trigger_spin_read(core);
    galena_poll_spin_read_idle(core);

    galena_read_spin_out(core, out);

    // Leave feedback staged off so a later plain galena_read_spins() doesn't compute by accident.
    galena_stage_spin_feedback(core, 0);
    galena_commit_spin_configure(core);
}

// Probe the accumulation-line value for a single spin: turns feedback on for just that spin
// (letting its accumulation line drive spin_out), drives it for cycle_per_read*read_num cycles,
// and returns that one spin's bit (0/1). Thin wrapper around
// galena_compute_and_read_single_spin_feedback for when you only care about the one bit and don't
// need the rest of the 256-spin readout.
static unsigned galena_acc_probe(unsigned core, unsigned spin_index, unsigned cycle_per_read,
                                 unsigned read_num) {
    uint32_t out[LAGD_SPIN_NUM_WORDS];
    galena_compute_and_read_single_spin_feedback(core, spin_index, out, cycle_per_read, read_num);
    return (out[spin_index / 32] >> (spin_index % 32)) & 1u;
}

// Zero every databit in the array: all NUM_SPIN J rows plus the h-row (row index NUM_SPIN).
static void galena_zero_array(unsigned core) {
    uint32_t zero[LAGD_WBL_NUM_WORDS] = {0};
    for (unsigned row = 0; row <= NUM_SPIN; row++) galena_write_row(core, row, zero);
}

// Encode a signed CU/HU strength (-7..+7) into its 4-bit code:
// - bit0 is the sign (1 = positive, 0 = negative)
// - bits1..3 are |value| in plain binary, LSB first
static uint32_t galena_encode_cu(int value) {
    unsigned mag = (unsigned)(value < 0 ? -value : value);
    return (value > 0 ? 1u : 0u) | ((mag & 1u) << 1) | ((mag & 2u) << 1) | ((mag & 4u) << 1);
}

// HU (row == NUM_SPIN) has its sign wired up backwards relative to CU rows on this die: writing
// -N onto the H-row yields an effective +N strength, and vice versa. Centralized here so every
// H-bias write path (galena_write_cu when targeting the H-row, galena_write_row_broadcast,
// galena_write_row_range) gets the correction automatically instead of every caller having to
// remember to negate its own h_value.
static uint32_t galena_encode_cu_for_row(unsigned row, int value) {
    return galena_encode_cu(row == NUM_SPIN ? -value : value);
}

// Program a single CU (or HU) with a signed strength (-7..+7), leaving every other column on that row at 0.
// NOTE: row == col is the column's own AU, not a CU; the write will not have any effect.
static void galena_write_cu(unsigned core, unsigned row, unsigned col, int value) {
    uint32_t code = galena_encode_cu_for_row(row, value);
    uint32_t pattern[LAGD_WBL_NUM_WORDS] = {0};
    unsigned base_bit = BIT_J * col;
    for (unsigned b = 0; b < BIT_J; b++) {
        unsigned bit = base_bit + b;
        if ((code >> b) & 1u) pattern[bit / 32] |= (1u << (bit % 32));
    }
    galena_write_row(core, row, pattern);
}

// Program a single column leaving all others 0.
static void galena_write_column(unsigned core, unsigned col, const int values[NUM_SPIN], int h_value) {
    for (unsigned row = 0; row < NUM_SPIN; row++) galena_write_cu(core, row, col, values[row]);
    galena_write_cu(core, NUM_SPIN, col, h_value);
}

// Program the same CU/HU value onto every column of one row in parallel (one write, all columns).
static void galena_write_row_broadcast(unsigned core, unsigned row, int value) {
    uint32_t code = galena_encode_cu_for_row(row, value);
    uint32_t pattern[LAGD_WBL_NUM_WORDS] = {0};
    for (unsigned col = 0; col < NUM_SPIN; col++) {
        unsigned base_bit = BIT_J * col;
        for (unsigned b = 0; b < BIT_J; b++) {
            unsigned bit = base_bit + b;
            if ((code >> b) & 1u) pattern[bit / 32] |= (1u << (bit % 32));
        }
    }
    galena_write_row(core, row, pattern);
}

// Program the same column pattern onto every column in parallel: values[row] is broadcast to
// every column on that row, h_value broadcast onto every column's HU.
static void galena_write_all_columns(unsigned core, const int values[NUM_SPIN], int h_value) {
    for (unsigned row = 0; row < NUM_SPIN; row++) galena_write_row_broadcast(core, row, values[row]);
    galena_write_row_broadcast(core, NUM_SPIN, h_value);
}

// Program the same CU/HU value onto columns [col_start, col_start+col_count) of one row, leaving
// every other column on that row at 0 -- e.g. to build an all-pairs coupling submatrix among a
// subset of spins (call once per row in the subset with the same col_start/col_count).
static void galena_write_row_range(unsigned core, unsigned row, int value, unsigned col_start,
                                   unsigned col_count) {
    uint32_t code = galena_encode_cu_for_row(row, value);
    uint32_t pattern[LAGD_WBL_NUM_WORDS] = {0};
    for (unsigned col = col_start; col < col_start + col_count; col++) {
        unsigned base_bit = BIT_J * col;
        for (unsigned b = 0; b < BIT_J; b++) {
            unsigned bit = base_bit + b;
            if ((code >> b) & 1u) pattern[bit / 32] |= (1u << (bit % 32));
        }
    }
    galena_write_row(core, row, pattern);
}

// Run feedback (annealing) for the duration of a spin-read burst, then snapshot the result.
// Per galena_trigger_feedback_pulse's own warning, a bare feedback pulse captures nothing --
// feedback has to be staged on *during* a spin-read burst for the settled result to be
// observable, which is what this does instead of toggling feedback and reading separately.
static void galena_compute_and_read_spins(unsigned core, unsigned cycle_per_read,
                                          unsigned read_num, uint32_t out[LAGD_SPIN_NUM_WORDS]) {
    galena_stage_spin_feedback(core, 1);
    galena_stage_spin_read_timing(core, cycle_per_read, read_num);
    galena_enable_spin_out(core, 1);
    galena_commit_spin_configure(core);

    galena_trigger_spin_read(core);
    galena_poll_spin_read_idle(core);

    galena_read_spin_out(core, out);

    // Leave feedback staged off so a later plain galena_read_spins() doesn't compute by accident.
    galena_stage_spin_feedback(core, 0);
    galena_commit_spin_configure(core);
}

// Safely switch which of the wwl_vdd/wwl_vread pair drives the array.
static void galena_switch_wwl_supply(unsigned core, int vdd_active) {
    galena_stage_wwl_vdd(core, 0);
    galena_stage_wwl_vread(core, 0);
    galena_commit_dt_configure(core);

    if (vdd_active)
        galena_stage_wwl_vdd(core, 1);
    else
        galena_stage_wwl_vread(core, 1);
    galena_commit_dt_configure(core);
}
