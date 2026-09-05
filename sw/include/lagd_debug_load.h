// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once

// Include after the caller's configuration header (e.g. lagd_scompute.h).
#include "lagd_common.h"

// Real-chip J/h encoding differs from analog_cfg.sv and the simulation model:
// bits [3:1] hold magnitude, bit [0] is 1 for negative and 0 for positive.
// This die has no J/h readback precharge circuit. Only write J/h; completion
// polling confirms the controller finished, not the contents of the analog cells.
#ifndef DEBUG_DT_TIMEOUT_CYCLES
#define DEBUG_DT_TIMEOUT_CYCLES 1000000ULL
#endif

#define WBL_WORDS (NUM_SPIN * BIT_H / 32)
#define WWL_WORDS (NUM_SPIN / 32)
#define H_ROW NUM_SPIN
#define NO_ROW (NUM_SPIN + 1)

_Static_assert(BIT_J == 4 && BIT_H == 4, "Debug loader requires 4-bit J/h");
_Static_assert(NUM_SPIN % 32 == 0, "Debug loader requires whole CSR words");
_Static_assert(CORE_TESTED >= 0 && CORE_TESTED < NUM_ISING_CORES, "Invalid core");

// Convert eight two's-complement coefficients without moving their nibble positions.
// -8 cannot be represented by the macro's three magnitude bits.
static int chip_encode_word(uint32_t raw, uint32_t *encoded) {
    uint32_t result = 0;
    for (unsigned shift = 0; shift < 32; shift += 4) {
        unsigned nibble = (raw >> shift) & 0xfU;
        if (nibble == 8) return 1;
        int value = (nibble & 8U) ? (int)nibble - 16 : (int)nibble;
        if (value == -8) return 1;
        unsigned magnitude = value < 0 ? (unsigned)-value : (unsigned)value;
        result |= ((magnitude << 1) | (value < 0)) << shift;
    }
    *encoded = result;
    return 0;
}

// Core AXI and Ising logic share clk_i. Allow trigger/status and readback pipelines
// to settle. Busy/valid can pulse entirely between CPU reads; do not require the
// CPU to observe either pulse. fence orders MMIO writes before the cycle delay.
static void debug_settle(void) {
    fence();
    uint64_t start = get_mcycle();
    while (get_mcycle() - start < 32) {}
}

static int debug_wait_idle(void *base, unsigned core, unsigned row, unsigned bit) {
    debug_settle();
    uint64_t start = get_mcycle();
    while ((*reg32(base, LAGD_CORE_OUTPUT_STATUS_REG_OFFSET) & (1U << bit)) == 0) {
        if (get_mcycle() - start >= DEBUG_DT_TIMEOUT_CYCLES) {
            printf("Core %u row %u: debug timeout (status bit %u)\r\n", core, row, bit);
            return 1;
        }
    }
    // Read-idle can precede the last synchronized readback CSR update.
    debug_settle();
    return 0;
}

static void debug_select_row(void *base, unsigned row) {
    // gen_model_data.py preserves logical row order, but packs logical column j
    // and spin j at hardware index NUM_SPIN-1-j. Apply the same permutation to
    // J rows, so J[i][j] connects hardware spins NUM_SPIN-1-i and NUM_SPIN-1-j.
    // H_ROW and NO_ROW are dedicated selectors, not logical J row indices.
    unsigned hw_row = row < NUM_SPIN ? NUM_SPIN - 1 - row : row;
    for (unsigned i = 0; i < WWL_WORDS; i++) {
        *reg32(base, LAGD_CORE_DEBUG_J_ONE_HOT_WWL_0_REG_OFFSET + 4 * i) =
            (hw_row < NUM_SPIN && i == hw_row / 32) ? (1U << (hw_row % 32)) : 0U;
    }
    uint32_t cfg2 = *reg32(base, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET);
    cfg2 &= ~(1U << LAGD_CORE_GLOBAL_CFG_2_DEBUG_H_WWL_BIT);
    if (row == H_ROW) cfg2 |= 1U << LAGD_CORE_GLOBAL_CFG_2_DEBUG_H_WWL_BIT;
    *reg32(base, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET) = cfg2;
}

static void debug_commit_dt(unsigned core) {
    lagd_enable_debug_dt_configure_enable(core);
    debug_settle();
    lagd_disable_all_debug_enable(core);
    debug_settle();
}

static void debug_configure_write(void *base, unsigned core) {
    // Use VDD for writing. Commit both supplies OFF first: their enables
    // must never overlap, including the separate supply selection for the h row.
    for (unsigned i = 0; i < WWL_WORDS; i++) {
        *reg32(base, LAGD_CORE_WWL_VDD_CFG_0_REG_OFFSET + 4 * i) = 0;
        *reg32(base, LAGD_CORE_WWL_VREAD_CFG_0_REG_OFFSET + 4 * i) = 0;
    }
    uint32_t cfg1 = *reg32(base, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET);
    cfg1 &= ~((1U << LAGD_CORE_GLOBAL_CFG_1_WWL_VDD_CFG_256_BIT) |
              (1U << LAGD_CORE_GLOBAL_CFG_1_WWL_VREAD_CFG_256_BIT));
    *reg32(base, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET) = cfg1;
    debug_commit_dt(core);

    for (unsigned i = 0; i < WWL_WORDS; i++) {
        *reg32(base, LAGD_CORE_WWL_VDD_CFG_0_REG_OFFSET + 4 * i) = 0xffffffffU;
    }
    cfg1 = *reg32(base, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET);
    cfg1 |= 1U << LAGD_CORE_GLOBAL_CFG_1_WWL_VDD_CFG_256_BIT;
    *reg32(base, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET) = cfg1;
    for (unsigned i = 0; i < WBL_WORDS; i++) {
        *reg32(base, LAGD_CORE_WBL_FLOATING_0_REG_OFFSET + 4 * i) = 0xffffffffU;
    }
    debug_commit_dt(core);
}

static int debug_load_jh(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    volatile uint32_t *j_mem = (volatile uint32_t *)
        ((uintptr_t)IC_MEM_BASE_ADDR + (uintptr_t)core * IC_L1_MEM_SIZE_B);
    uint32_t row_data[WBL_WORDS];
    int fail = 0;
    lagd_disable_all_debug_enable(core);
    if (debug_wait_idle(base, core, NO_ROW,
                        LAGD_CORE_OUTPUT_STATUS_DEBUG_ANALOG_DT_W_IDLE_BIT) ||
        debug_wait_idle(base, core, NO_ROW,
                        LAGD_CORE_OUTPUT_STATUS_DEBUG_ANALOG_DT_R_IDLE_BIT)) return 1;

    for (unsigned row = 0; row <= H_ROW; row++) {
        // Each wide J memory word holds four consecutive 128-byte rows.
        // h is read from the CSRs initialized by lagd_configure_h_rdata().
        for (unsigned i = 0; i < WBL_WORDS; i++) {
            uint32_t raw = row == H_ROW
                ? *reg32(base, LAGD_CORE_H_RDATA_0_REG_OFFSET + 4 * i)
                : j_mem[row * WBL_WORDS + i];
            if (chip_encode_word(raw, &row_data[i])) {
                printf("Core %u row %u word %u: unrepresentable -8 in %08x\r\n",
                       core, row, i, raw);
                fail = 1;
                goto cleanup;
            }
        }
        debug_select_row(base, row);
        for (unsigned i = 0; i < WBL_WORDS; i++) {
            *reg32(base, LAGD_CORE_DEBUG_WBL_CONFIG_0_REG_OFFSET + 4 * i) = row_data[i];
        }
        debug_configure_write(base, core);
        lagd_enable_debug_j_write_en(core);
        debug_settle();
        lagd_disable_all_debug_enable(core);
        if (debug_wait_idle(base, core, row,
                            LAGD_CORE_OUTPUT_STATUS_DEBUG_ANALOG_DT_W_IDLE_BIT)) {
            // A stuck operation must not be reconfigured; caller aborts computation.
            return 1;
        }
    }

cleanup:
    lagd_disable_all_debug_enable(core);
    debug_select_row(base, NO_ROW);
    // Restore normal spin-write bitline drive (all ones, as after reset).
    debug_configure_write(base, core);
    return fail;
}
