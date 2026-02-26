// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Jiacong Sun <jiacong.sun@kuleuven.be>

#ifndef CORE_TESTED
#define CORE_TESTED 0
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
    // UART init
    uint64_t t0 = clint_get_mtime();
    uint32_t rtc_freq = *reg32(&__base_regs, CHESHIRE_RTC_FREQ_REG_OFFSET);
    uint64_t reset_freq = clint_get_core_freq(rtc_freq, 2500);
    uart_init(&__base_uart, reset_freq, __BOOT_BAUDRATE);
    uint64_t t1 = clint_get_mtime();
    printf("UART init           : %llu us\r\n", (t1 - t0) * 1000000ULL / rtc_freq);

#ifdef ENABLE_XOR_CHECK
    // Compute and verify J matrix XOR checksum
    uint64_t t2 = clint_get_mtime();
    uint64_t j_xor = 0;
    for (unsigned i = 0; i < MODEL_J_LEN; i++) j_xor ^= model_j_data[i];
    uint64_t t3 = clint_get_mtime();
    printf("J XOR checksum      : 0x%016llx ", (unsigned long long)j_xor);
    if (j_xor == MODEL_J_XOR_CHECKSUM)
        printf("[PASS]\r\n");
    else
        printf("[FAIL] expected 0x%016llx\r\n", (unsigned long long)MODEL_J_XOR_CHECKSUM);
    printf("J XOR time          : %llu us\r\n", (t3 - t2) * 1000000ULL / rtc_freq);

    // Compute and verify h vector XOR checksum
    uint64_t t4 = clint_get_mtime();
    uint32_t h_xor = 0;
    for (unsigned i = 0; i < MODEL_H_U32_LEN; i++) h_xor ^= model_h_data[i];
    uint64_t t5 = clint_get_mtime();
    printf("H XOR checksum      : 0x%08x ", h_xor);
    if (h_xor == MODEL_H_XOR_CHECKSUM)
        printf("[PASS]\r\n");
    else
        printf("[FAIL] expected 0x%08x\r\n", MODEL_H_XOR_CHECKSUM);
    printf("H XOR time          : %llu us\r\n", (t5 - t4) * 1000000ULL / rtc_freq);
#endif // ENABLE_XOR_CHECK

    uint64_t t10 = clint_get_mtime();
    printf("=== LAGD Register Configuration ===\r\n");
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
    uint64_t t11 = clint_get_mtime();
    printf("LAGD reg config: %llu us\r\n", (t11 - t10) * 1000000ULL / rtc_freq);
    // printf("=== LAGD Analog Onloading ===\r\n");
    // start analog onloading
    // lagd_enable_analog_onloading(CORE_TESTED);
    // wait for analog onloading to finish
    // lagd_wait_for_analog_onloading_done(CORE_TESTED);
    // uint64_t t12 = clint_get_mtime();
    // printf("LAGD analog onloading: %llu us\r\n", (t12 - t11) * 1000000ULL / rtc_freq);
    printf("=== LAGD Computation Start ===\r\n");
    uart_write_flush(&__base_uart);
    // start computation
    lagd_enable_energy_monitor_fifo(CORE_TESTED);
    lagd_enable_computation(CORE_TESTED);
    printf("=== LAGD Waiting for Computation to Finish ===\r\n");
    uart_write_flush(&__base_uart);
    // wait for computation to finish
    lagd_wait_for_computation_done(CORE_TESTED);
    uint64_t t13 = clint_get_mtime();
    printf("LAGD computation time: %llu us\r\n", (t13 - t11) * 1000000ULL / rtc_freq);
    // print output
    lagd_print_output_status(CORE_TESTED);
    lagd_print_energy_fifo_data(CORE_TESTED);
    // lagd_print_spin_fifo_data(CORE_TESTED);
    // checks
    lagd_check_spin_fifo_data(CORE_TESTED);
    // print performance counters
    lagd_print_cmpt_idx(CORE_TESTED);
    lagd_print_cycle_per_iteration(CORE_TESTED);
    lagd_print_cycle_per_cmpt(CORE_TESTED);
    lagd_print_cycle_all_cmpt(CORE_TESTED);

    printf("=== DONE ===\r\n");
    uart_write_flush(&__base_uart);
    return 0;
}
