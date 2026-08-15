// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
// Author: Sofie De Weer <sofie.deweer@kuleuven.be>

#ifndef VERIFICATION_TEST
#define VERIFICATION_TEST 1
#endif

#ifndef ENERGY_MONITOR
#define ENERGY_MONITOR 1
#endif

#ifndef MAX_SAMPLES
#define MAX_SAMPLES 2048
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
#include "model_f_data.h"
#include "model_f_data_sec.h"
// lagd_dcompute.h must come before lagd_common.h
#include "lagd_dcompute.h"
#include "lagd_common.h"

int main(void) {
    unsigned i;
    int fail = 0;
    // UART init
    // uint64_t t0 = clint_get_mtime();
    static uint32_t log_buf1[MAX_SAMPLES];
    static uint32_t log_buf2[MAX_SAMPLES];
    uint32_t rtc_freq = *reg32(&__base_regs, CHESHIRE_RTC_FREQ_REG_OFFSET);
    uint64_t reset_freq = clint_get_core_freq(rtc_freq, 2500);
    uart_init(&__base_uart, reset_freq, __BOOT_BAUDRATE);

    // register configuration
    for (i = 0; i < NUM_ISING_CORES; i++) {
        lagd_configure_initial_spins_dual(i);
        lagd_configure_cmpt_max_num(i);
        lagd_configure_counters(i);
        lagd_configure_wwl_vdd_cfg(i);
        lagd_configure_wwl_vread_cfg(i);
        lagd_configure_spin_wwl_strobe(i);
        lagd_configure_spin_feedback(i);
        lagd_configure_h_rdata_dual(i);
        lagd_configure_global_cfg_1(i);
        lagd_configure_global_cfg_2(i);
        // clear config valid
        lagd_clear_config_valid(i);
    }
    for (i = 0; i < NUM_ISING_CORES; i++) {
        // start analog onloading
        lagd_enable_analog_onloading(i);
        // wait for analog onloading to finish
        lagd_wait_for_analog_onloading_done(i);
    }

    for (i = 0; i < NUM_ISING_CORES; i++) {
        // start computation
        lagd_enable_energy_monitor_fifo(i);
        lagd_enable_computation(i);
    }

    // All cores run concurrently, so their monitors must be interleaved in one loop: monitoring
    // core 0 to completion first would miss the whole run of core 1.
    unsigned log_cnt[NUM_ISING_CORES];
    uint32_t *const log_bufs[NUM_ISING_CORES] = {log_buf1, log_buf2};
    if (ENERGY_MONITOR) {
        lagd_monitor_energy_fifo_dbg_0_multi(NUM_ISING_CORES, MAX_SAMPLES, log_bufs, log_cnt);
    } else {
        lagd_monitor_cycle_per_iteration_multi(NUM_ISING_CORES, MAX_SAMPLES, log_bufs, log_cnt);
    }

    for (i = 0; i < NUM_ISING_CORES; i++) {
        // wait for computation to finish
        lagd_wait_for_computation_done(i);
    }

    // check final output
    if (VERIFICATION_TEST) {
        for (i = 0; i < NUM_ISING_CORES; i++) {
            fail |= lagd_check_spin_fifo_data_dual(i);
        }
        if (fail == 0) {
            printf("PASS\r\n");
        } else {
            printf("FAIL\r\n");
        }
        uart_write_flush(&__base_uart);
        return fail;
    } else {
        if (ENERGY_MONITOR) {
            // print energy monitor fifo debug register log
            lagd_print_energy_fifo_dbg(0, log_cnt[0], log_buf1);
            lagd_print_energy_fifo_dbg(1, log_cnt[1], log_buf2);
        } else {
            // print performance counter log
            lagd_print_cycle_per_iteration(0, log_cnt[0], log_buf1);
            lagd_print_cycle_per_iteration(1, log_cnt[1], log_buf2);
        }
        // print out final spins and energies
        for (i = 0; i < NUM_ISING_CORES; i++) {
            lagd_print_spin_fifo_data(i);
        }
        for (i = 0; i < NUM_ISING_CORES; i++) {
            lagd_print_energy_fifo_data(i);
        }
        uart_write_flush(&__base_uart);
        return 0;
    }
}
