// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Jiacong Sun <jiacong.sun@kuleuven.be>

// Test write-then-read of all LAGD Ising core registers.
// For each core it sweeps every register offset of the block (0x000..0x448, densely mapped),
// learns which bits of each register actually follow what software writes, and checks two
// complementary patterns against that mask. Registers the hardware owns are detected and reported
// separately instead of being counted as failures. global_cfg_1 and global_cfg_2 are swept with a
// restricted mask: writing an arbitrary pattern into them would start the computation and turn on
// the debug paths, which would disturb every register read afterwards.

#ifndef VERBOSE
#define VERBOSE 0 // 1: print one line per register, 0: print the failures only
#endif

#include "regs/cheshire.h"
#include "dif/clint.h"
#include "dif/uart.h"
#include "params.h"
#include "util.h"
#include "printf.h"
#include "lagd_define.h"
#include "lagd_core_reg.h"

// Complementary patterns: a bit stuck at the value of the first one is caught by the second
#define PATTERN_A 0xA5A5A5A5U
#define PATTERN_B 0x5A5A5A5AU

#define LAST_REG_OFFSET LAGD_CORE_ENERGY_FIFO_DBG_1_REG_OFFSET

#define FIELD_MASK(reg, field) \
    ((uint32_t)LAGD_CORE_##reg##_##field##_MASK << LAGD_CORE_##reg##_##field##_OFFSET)

// Value-only fields of the control registers: every enable, config_valid and debug bit is left
// out, so sweeping these two registers cannot start the core.
#define GCFG1_SAFE_MASK \
    (FIELD_MASK(GLOBAL_CFG_1, CONFIG_COUNTER) | FIELD_MASK(GLOBAL_CFG_1, SYNCHRONIZER_WBL_PIPE_NUM))
#define GCFG2_SAFE_MASK \
    (FIELD_MASK(GLOBAL_CFG_2, SYNCHRONIZER_PIPE_NUM) | \
     FIELD_MASK(GLOBAL_CFG_2, DGT_ADDR_UPPER_BOUND) | FIELD_MASK(GLOBAL_CFG_2, DGT_HSCALING))

// Bits of the given register that software may write during the sweep
static uint32_t writable_bits(uint32_t off) {
    if (off == LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET) return GCFG1_SAFE_MASK;
    if (off == LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET) return GCFG2_SAFE_MASK;
    return 0xFFFFFFFFU;
}

// Write the two patterns into one register and compare the read-back over the bits that software
// owns. Returns the number of failing patterns; sets *hw_owned when nothing software writes sticks,
// which is the case for the status and performance-counter registers the hardware keeps updating.
static int check_reg(void *base, uint32_t off, int *hw_owned) {
    const uint32_t allowed = writable_bits(off);

    // A register the hardware is updating changes on its own between two reads
    uint32_t first = *reg32(base, off);
    uint32_t second = *reg32(base, off);
    if (first != second) {
        *hw_owned = 1;
        return 0;
    }

    // Learn which bits follow what we write: unimplemented, read-only and hardware-driven bits
    // read back the same value no matter what we put in
    *reg32(base, off) = allowed;
    uint32_t after_ones = *reg32(base, off);
    *reg32(base, off) = 0;
    uint32_t after_zeros = *reg32(base, off);
    uint32_t mask = after_ones & ~after_zeros & allowed;
    if (mask == 0) {
        *hw_owned = 1;
        return 0;
    }

    int fail = 0;
    const uint32_t patterns[2] = {PATTERN_A, PATTERN_B};
    for (int i = 0; i < 2; i++) {
        uint32_t expected = patterns[i] & mask;
        *reg32(base, off) = patterns[i] & allowed;
        uint32_t read = *reg32(base, off) & mask;
        if (read != expected) {
            printf("  [0x%03x] 0x%08x [MISMATCH] expected 0x%08x (writable mask 0x%08x)\r\n", off,
                   read, expected, mask);
            fail++;
        }
    }
    if (VERBOSE && fail == 0) {
        printf("  [0x%03x] [PASS] writable mask 0x%08x\r\n", off, mask);
    }
    return fail;
}

int main(void) {
    // UART init
    uint64_t t0 = clint_get_mtime();
    uint32_t rtc_freq = *reg32(&__base_regs, CHESHIRE_RTC_FREQ_REG_OFFSET);
    uint64_t reset_freq = clint_get_core_freq(rtc_freq, 2500);
    uart_init(&__base_uart, reset_freq, __BOOT_BAUDRATE);
    uint64_t t1 = clint_get_mtime();

    printf("=== LAGD Register R/W Test ===\r\n");
    printf("UART init           : %llu us\r\n", (t1 - t0) * 1000000ULL / rtc_freq);

    int total = 0, failed = 0, hw_owned_cnt = 0;

    for (int core = 0; core < NUM_ISING_CORES; core++) {
        void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
        printf("--- Core %d (base 0x%08x) ---\r\n", core, (unsigned)(uintptr_t)base);

        int core_failed = 0, core_hw_owned = 0;
        for (uint32_t off = 0; off <= LAST_REG_OFFSET; off += 4) {
            int hw_owned = 0;
            total++;
            if (check_reg(base, off, &hw_owned) != 0) {
                core_failed++;
            }
            if (hw_owned) {
                core_hw_owned++;
                if (VERBOSE) {
                    printf("  [0x%03x] [HW-OWNED] not writable by software, skipped\r\n", off);
                }
            }
        }
        failed += core_failed;
        hw_owned_cnt += core_hw_owned;
        printf("  core %d: %d registers, %d mismatch, %d hardware-owned\r\n", core,
               (int)(LAST_REG_OFFSET / 4 + 1), core_failed, core_hw_owned);

        // Clean up: reset all registers to 0 so the core remains idle
        for (uint32_t off = 0; off <= LAST_REG_OFFSET; off += 4) *reg32(base, off) = 0;
    }

    printf("=== DONE: %d/%d PASS, %d MISMATCH, %d HW-OWNED ===\r\n", total - failed - hw_owned_cnt,
           total, failed, hw_owned_cnt);
    uart_write_flush(&__base_uart);
    return failed;
}
