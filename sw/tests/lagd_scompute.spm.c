// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Jiacong Sun <jiacong.sun@kuleuven.be>

#ifndef CORE_TESTED
#define CORE_TESTED 0
#endif

#ifndef MAX_SAMPLES
#define MAX_SAMPLES 5
#endif

#include "regs/cheshire.h"
#include "dif/clint.h"
#include "dif/uart.h"
#include "dif/dma.h"
#include "params.h"
#include "util.h"
#include "printf.h"
#include "model_1_data.h"
#include "model_f_data.h"
#include "lagd_reg_params.h"
#include "lagd_reg_cfg.h"

int main(void) {
    static uint32_t log_buf[MAX_SAMPLES];
    // UART init
    // uint64_t t0 = clint_get_mtime();
    uint32_t rtc_freq = *reg32(&__base_regs, CHESHIRE_RTC_FREQ_REG_OFFSET);
    uint64_t reset_freq = clint_get_core_freq(rtc_freq, 2500);
    uart_init(&__base_uart, reset_freq, __BOOT_BAUDRATE);

    // register configuration
    lagd_configure_initial_spins(CORE_TESTED);
    lagd_configure_cmpt_max_num(CORE_TESTED);
    lagd_configure_counters(CORE_TESTED);
    lagd_configure_wwl_vdd_cfg(CORE_TESTED);
    lagd_configure_wwl_vread_cfg(CORE_TESTED);
    lagd_configure_spin_wwl_strobe(CORE_TESTED);
    lagd_configure_spin_feedback(CORE_TESTED);
    lagd_configure_h_rdata(CORE_TESTED);
    lagd_configure_wbl_floating(CORE_TESTED);
    lagd_configure_debug_j_one_hot_wwl(CORE_TESTED);
    lagd_configure_global_cfg_1(CORE_TESTED);
    lagd_configure_global_cfg_2(CORE_TESTED);
    // clear config valid
    lagd_clear_config_valid(CORE_TESTED);
    // start analog onloading
    // lagd_enable_analog_onloading(CORE_TESTED);
    // wait for analog onloading to finish
    // lagd_wait_for_analog_onloading_done(CORE_TESTED);

    // start computation
    lagd_enable_energy_monitor_fifo(CORE_TESTED);
    lagd_enable_computation(CORE_TESTED);
    unsigned log_cnt = lagd_monitor_cycle_per_iteration(CORE_TESTED, MAX_SAMPLES, log_buf);
    // wait for computation to finish
    lagd_wait_for_computation_done(CORE_TESTED);
    // print output
    lagd_print_energy_fifo_data(CORE_TESTED);
    // print performance counter log
    lagd_print_cycle_per_iteration(CORE_TESTED, log_cnt, log_buf);

    printf("=== DONE ===\r\n");
    uart_write_flush(&__base_uart);
    return 0;
}
