// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Jiacong Sun <jiacong.sun@kuleuven.be>

// Test write-then-read of all LAGD Ising core registers.
// For each core, writes 0xA5A5A5A5 to every register offset (0x000..0x344),
// reads back, and prints [PASS] or [MISMATCH] per register.

#include "regs/cheshire.h"
#include "dif/clint.h"
#include "dif/uart.h"
#include "params.h"
#include "util.h"
#include "printf.h"
#include "lagd_define.h"
#include "lagd_core_reg.h"

#define TEST_PATTERN  0xA5A5A5A5U

int main(void) {
    // UART init
    uint64_t t0 = clint_get_mtime();
    uint32_t rtc_freq = *reg32(&__base_regs, CHESHIRE_RTC_FREQ_REG_OFFSET);
    uint64_t reset_freq = clint_get_core_freq(rtc_freq, 2500);
    uart_init(&__base_uart, reset_freq, __BOOT_BAUDRATE);
    uint64_t t1 = clint_get_mtime();

    printf("=== LAGD Register R/W Test ===\r\n");
    printf("UART init           : %llu us\r\n", (t1 - t0) * 1000000ULL / rtc_freq);

    int total = 0, mismatches = 0;

    for (int core = 0; core < NUM_ISING_CORES; core++) {
        void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR +
                              (uintptr_t)core * IC_NUM_REGS);
        printf("--- Core %d (base 0x%08x) ---\r\n", core, (unsigned)(uintptr_t)base);

        // Write phase: write TEST_PATTERN to every register offset
        for (uint32_t off = 0; off <= LAGD_CORE_J_MEM_REN_RADDR_REG_OFFSET; off += 4)
            *reg32(base, off) = TEST_PATTERN;

        // Read-back phase: compare and report
        for (uint32_t off = 0; off <= LAGD_CORE_J_MEM_REN_RADDR_REG_OFFSET; off += 4) {
            uint32_t val = *reg32(base, off);
            total++;
            if (val == TEST_PATTERN)
                printf("  [0x%03x] 0x%08x [PASS]\r\n", off, val);
            else {
                printf("  [0x%03x] 0x%08x [MISMATCH] expected 0x%08x\r\n",
                       off, val, TEST_PATTERN);
                mismatches++;
            }
        }
    }

    // Clean up: reset all registers to 0 so cores remain idle
    for (int core = 0; core < NUM_ISING_CORES; core++) {
        void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR +
                              (uintptr_t)core * IC_NUM_REGS);
        for (uint32_t off = 0; off <= LAGD_CORE_J_MEM_REN_RADDR_REG_OFFSET; off += 4)
            *reg32(base, off) = 0;
    }

    printf("=== DONE: %d/%d PASS, %d MISMATCH ===\r\n",
           total - mismatches, total, mismatches);
    uart_write_flush(&__base_uart);
    return mismatches;
}
