// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Jiacong Sun <jiacong.sun@kuleuven.be>

// Test the data write and data read operation of a single Galena macro.
// Every word line of the array is covered: the NUM_SPIN J rows selected one-hot through
// debug_j_one_hot_wwl, plus the h row selected through global_cfg_2.debug_h_wwl. Each row is
// written with a row-specific pattern through the debug write path and read back through the debug
// read path

#ifndef CORE_TESTED
#define CORE_TESTED 0
#endif

#ifndef VERIFICATION_TEST
#define VERIFICATION_TEST 1
#endif

#ifndef ROW_STRIDE
#define ROW_STRIDE 1 // test every J row; raise it to shorten the simulation
#endif

#include <stdint.h>

// No computation runs in this test, so the h scaling factor only has to complete the global_cfg_2
// write. Defined before lagd_reg_params.h
#define GCFG2_DGT_HSCALING(core) 4

// cheshire headers
#include "regs/cheshire.h"
#include "dif/clint.h"
#include "dif/uart.h"
#include "dif/dma.h"
#include "params.h"
#include "util.h"
#include "printf.h"
// lagd headers
#include "lagd_reg_params.h"
#include "lagd_common.h"

#define WBL_WORDS (NUM_SPIN * BIT_H / 32) // registers holding one word line of data
#define WWL_WORDS (NUM_SPIN / 32)         // registers holding the one-hot J word line select
#define H_ROW NUM_SPIN                    // the h word line, the last one of the array

// Data written into word i of the given row. The row index is mixed in so that every word line
// holds a different value.
static uint32_t row_pattern(unsigned row, int i) {
    return debug_wbl_config[i] ^ ((uint32_t)row * 0x01010101U);
}

// wbl_floating: all-ones (default when reboot) for writing and all-zeros for reading.
static void dt_configure(unsigned core, uint32_t wbl_floating_value) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    for (int i = 0; i < WBL_WORDS; i++) {
        *reg32(base, LAGD_CORE_WBL_FLOATING_0_REG_OFFSET + 4 * i) = wbl_floating_value;
    }
    lagd_enable_debug_dt_configure_enable(core);
    lagd_disable_all_debug_enable(core);
}

// Select one word line: a one-hot J row, or the h row
static void select_wwl(unsigned core, unsigned row) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    for (int i = 0; i < WWL_WORDS; i++) {
        uint32_t word = (row < NUM_SPIN && (unsigned)i == row / 32) ? (1U << (row % 32)) : 0U;
        *reg32(base, LAGD_CORE_DEBUG_J_ONE_HOT_WWL_0_REG_OFFSET + 4 * i) = word;
    }
    uint32_t cfg2 = *reg32(base, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET);
    if (row == H_ROW) {
        cfg2 |= 1U << LAGD_CORE_GLOBAL_CFG_2_DEBUG_H_WWL_BIT;
    } else {
        cfg2 &= ~(1U << LAGD_CORE_GLOBAL_CFG_2_DEBUG_H_WWL_BIT);
    }
    *reg32(base, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET) = cfg2;
}

// Put the pattern of the given row into the debug data registers
static void load_row_data(unsigned core, unsigned row) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    for (int i = 0; i < WBL_WORDS; i++) {
        *reg32(base, LAGD_CORE_DEBUG_WBL_CONFIG_0_REG_OFFSET + 4 * i) = row_pattern(row, i);
    }
}

static unsigned mismatches_found = 0;
static unsigned mismatches_printed = 0;

static void report_mismatch(unsigned row, int word, const char *line, uint32_t got, uint32_t exp) {
    mismatches_found++;
    if (mismatches_printed < MAX_MISMATCH_PRINTS) {
        printf("  wwl %3u word %2d: %-4s 0x%08x [MISMATCH] expected 0x%08x\r\n", row, word, line,
               got, exp);
        mismatches_printed++;
    }
}

// Read the selected row into the debug CSRs and compare both polarities against what was written.
// Returns 0 when the whole row matches.
static int read_and_check_row(unsigned core, unsigned row) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    lagd_enable_debug_j_read_en(core);
    lagd_disable_all_debug_enable(core);

    int fail = 0;
    for (int i = 0; i < WBL_WORDS; i++) {
        uint32_t expected = row_pattern(row, i);
        uint32_t wbl = *reg32(base, LAGD_CORE_DEBUG_WBL_READ_DATA_0_REG_OFFSET + 4 * i);
        uint32_t wblb = *reg32(base, LAGD_CORE_DEBUG_WBLB_READ_DATA_0_REG_OFFSET + 4 * i);
        if (wbl != expected) {
            report_mismatch(row, i, "wbl", wbl, expected);
            fail = 1;
        }
        if (wblb != ~expected) {
            report_mismatch(row, i, "wblb", wblb, ~expected);
            fail = 1;
        }
    }
    return fail;
}

// Write one word line and read it back. Returns 0 when the row matches.
static int test_row(unsigned core, unsigned row) {
    select_wwl(core, row);
    load_row_data(core, row);
    dt_configure(core, 0xFFFFFFFFU); // latch the data, the array latches the write bit lines
    lagd_enable_debug_j_write_en(core);
    lagd_disable_all_debug_enable(core);
    dt_configure(core, 0x00000000U); // the array drives the read bit lines
    return read_and_check_row(core, row);
}

int main(void) {
    unsigned tested = 0, failed = 0;
    // UART init
    uint32_t rtc_freq = *reg32(&__base_regs, CHESHIRE_RTC_FREQ_REG_OFFSET);
    uint64_t reset_freq = clint_get_core_freq(rtc_freq, 2500);
    uart_init(&__base_uart, reset_freq, __BOOT_BAUDRATE);

    // register configuration
    lagd_configure_cmpt_max_num(CORE_TESTED);
    lagd_configure_counters(CORE_TESTED);
    lagd_configure_wwl_vdd_cfg(CORE_TESTED);
    lagd_configure_wwl_vread_cfg(CORE_TESTED);
    lagd_configure_spin_wwl_strobe(CORE_TESTED);
    lagd_configure_spin_feedback(CORE_TESTED);

    lagd_configure_global_cfg_1(CORE_TESTED);
    lagd_configure_global_cfg_2(CORE_TESTED);
    // clear config valid
    lagd_clear_config_valid(CORE_TESTED);

    /////////////////////////////////////////////////////////////////
    /////////////////////// WORD LINE SWEEP /////////////////////////
    /////////////////////////////////////////////////////////////////
    if (VERIFICATION_TEST) {
        printf("Galena J/h Test, core %u\r\n", (unsigned)CORE_TESTED);
        for (unsigned row = 0; row < NUM_SPIN; row += ROW_STRIDE) {
            failed += (unsigned)test_row(CORE_TESTED, row);
            tested++;
        }
        // the h word line is covered whatever the stride is
        failed += (unsigned)test_row(CORE_TESTED, H_ROW);
        tested++;

        if (mismatches_found > mismatches_printed) {
            printf("  %u more mismatching words not printed\r\n",
                   mismatches_found - mismatches_printed);
        }
        printf("%u/%u wordlines PASS, %u FAIL\r\n", tested - failed, tested, failed);
        if (failed == 0) {
            printf("PASS\r\n");
        } else {
            printf("FAIL\r\n");
        }
        uart_write_flush(&__base_uart);
        return (int)failed;
    } else {
        // Dump one word line instead of comparing, for debugging the analog data path
        (void)test_row(CORE_TESTED, 0);
        lagd_print_debug_wbl_read_data(CORE_TESTED);
        lagd_print_debug_wblb_read_data(CORE_TESTED);
        uart_write_flush(&__base_uart);
        return 0;
    }
}
