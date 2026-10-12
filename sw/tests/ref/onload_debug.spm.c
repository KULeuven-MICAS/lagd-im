// Copyright 2026 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Load J/h into the array through the debug path and STOP -- the loading half of the two-ELF
// flow, where a second ELF (run_capture / monitor_capture) then computes on what this left behind.
//
// WHY THIS EXISTS. tests/galena/perf/load_problem_l1.spm.c does the same job through our own
// galena_* recipes, with WWL_CYCLES defaulting to 100. This one does it through the reference
// path instead -- byte-for-byte the register configuration and the loader that
// lagd_scompute_debug.spm.c uses, including its 5-cycle WWL timing from lagd_reg_params.h and its
// per-row supply cycling. Everything up to and including debug_load_jh() is identical to that
// scenario; the only difference is that it stops rather than starting a computation.
//
// So the two loaders can be compared with one variable changed at a time: same problem (generate
// with DATA_FOLDER pointing at the same folder), same array, different write path.
//
// J comes from this core's l1_j_spm, where the linker placed model_j_data and the ELF loader
// filled it; h comes from the H_RDATA CSRs. Neither is read back -- this die has no J/h readback
// precharge circuit -- so a clean run means the write sequence completed, not that the analog
// cells hold what was intended.

#ifndef CORE_TESTED
#define CORE_TESTED 0
#endif

// cheshire headers
#include "regs/cheshire.h"
#include "dif/clint.h"
#include "dif/uart.h"
#include "dif/dma.h"
#include "params.h"
#include "util.h"
#include "printf.h"
// lagd headers
// lagd_scompute.h must come before lagd_common.h
#include "lagd_scompute.h"
#include "lagd_common.h"
#include "lagd_debug_load.h"

int main(void) {
    uint32_t rtc_freq = *reg32(&__base_regs, CHESHIRE_RTC_FREQ_REG_OFFSET);
    uint64_t reset_freq = clint_get_core_freq(rtc_freq, 2500);
    uart_init(&__base_uart, reset_freq, __BOOT_BAUDRATE);

    printf("=== ONLOAD (reference debug path) ===\r\n");
    printf("core=%u, %u spins, reference WWL timing (cycle_per_wwl_high=%u)\r\n",
           (unsigned)CORE_TESTED, (unsigned)NUM_SPIN, (unsigned)CYCLE_PER_WWL_HIGH);

    // Identical to lagd_scompute_debug.spm.c from here to debug_load_jh().
    lagd_configure_initial_spins(CORE_TESTED);
    lagd_configure_cmpt_max_num(CORE_TESTED);
    lagd_configure_counters(CORE_TESTED);
    lagd_configure_wwl_vdd_cfg(CORE_TESTED);
    lagd_configure_wwl_vread_cfg(CORE_TESTED);
    lagd_configure_spin_wwl_strobe(CORE_TESTED);
    lagd_configure_spin_feedback(CORE_TESTED);
    lagd_configure_h_rdata(CORE_TESTED);
    lagd_configure_global_cfg_1(CORE_TESTED);
    lagd_configure_global_cfg_2(CORE_TESTED);
    lagd_clear_config_valid(CORE_TESTED);

    if (debug_load_jh(CORE_TESTED)) {
        printf("J/h loading FAIL\r\n");
        uart_write_flush(&__base_uart);
        return 1;
    }
    printf("J/h write sequence done for %u rows + h (readback unsupported)\r\n",
           (unsigned)NUM_SPIN);

    // The initial spins the register configuration staged, so the next ELF knows what it starts
    // from. Reading the spin FIFO does not drive feedback, so this does not disturb the array.
    lagd_print_spin_fifo_data(CORE_TESTED);

    printf("LOADED\r\n");
    printf("FINISH\r\n");
    uart_write_flush(&__base_uart);
    return 0;
}
