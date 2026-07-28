// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
// Author: Sofie De Weer <sofie.deweer@kuleuven.be>

#ifndef VERIFICATION_TEST
#define VERIFICATION_TEST 0
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
#include "model_j_data.h"
#include "model_f_data.h"
#include "model_j_data_sec.h"
#include "model_f_data_sec.h"
#include "spin_data.h"
#include "spin_data_sec.h"
#include "lagd_reg_params.h"
#include "lagd_common.h"

// Forward declarations (definitions follow main())
static void lagd_configure_initial_spins_dual(unsigned core);
static void lagd_configure_h_rdata_dual(unsigned core);

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

    // print out energies
    if (ENERGY_MONITOR) {
        // print energy monitor fifo debug register log
        lagd_print_energy_fifo_dbg(0, log_cnt[0], log_buf1);
    } else {
        // print performance counter log
        lagd_print_cycle_per_iteration(0, log_cnt[0], log_buf1);
    }
    if (ENERGY_MONITOR) {
        // print energy monitor fifo debug register log
        lagd_print_energy_fifo_dbg(1, log_cnt[1], log_buf2);
    } else {
        // print performance counter log
        lagd_print_cycle_per_iteration(1, log_cnt[1], log_buf2);
    }
    for (i = 0; i < NUM_ISING_CORES; i++) {        
        lagd_print_spin_fifo_data(i);
    }
    
    // check final output
    if (VERIFICATION_TEST) {
        for (i = 0; i < NUM_ISING_CORES; i++) {
            fail |= lagd_check_energy_fifo_data(i);
        }
        if (fail == 0) {
            printf("PASS\r\n");
        } else {
            printf("FAIL\r\n");
        }
        uart_write_flush(&__base_uart);
        return fail;
    } else {
        for (i = 0; i < NUM_ISING_CORES; i++) {
            lagd_print_energy_fifo_data(i);
        }
        uart_write_flush(&__base_uart);
        return 0;
    }
}

static void lagd_configure_initial_spins_dual(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    const uint32_t *spin_0 = (core == 0) ? spin_initial_0 : spin_initial_0_sec;
    const uint32_t *spin_1 = (core == 0) ? spin_initial_1 : spin_initial_1_sec;
    // Write initial spin set 0
    for (int i = 0; i < NUM_SPIN / 32; i++) {
        *reg32(base, LAGD_CORE_CONFIG_SPIN_INITIAL_0_0_REG_OFFSET + 4 * i) = spin_0[i];
    }
    // Write initial spin set 1
    for (int i = 0; i < NUM_SPIN / 32; i++) {
        *reg32(base, LAGD_CORE_CONFIG_SPIN_INITIAL_1_0_REG_OFFSET + 4 * i) = spin_1[i];
    }
}

// Configure h_rdata registers
static void lagd_configure_h_rdata_dual(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    const uint32_t *h_data = (core == 0) ? model_h_data : model_h_data_sec;

    for (int i = 0; i < NUM_SPIN * BIT_H / 32; i++) {
        *reg32(base, LAGD_CORE_H_RDATA_0_REG_OFFSET + 4 * i) = h_data[i];
    }
}
