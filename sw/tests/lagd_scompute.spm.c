// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Jiacong Sun <jiacong.sun@kuleuven.be>

// Override NUM_ISING_CORES before including lagd_define.h so the #ifndef guard
// in lagd_config.h preserves this test-specific value (1 core instead of 2).
#define NUM_ISING_CORES 1

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

    printf("=== Ising Model Data Verification ===\r\n");
    printf("UART init           : %llu us\r\n", (t1 - t0) * 1000000ULL / rtc_freq);

    // Print data summary
    printf("model_j_data addr   : %p\r\n", (void *)model_j_data);
    printf("MODEL_J_LEN         : %u\r\n", (unsigned)MODEL_J_LEN);
    printf("MODEL_H_U32_LEN     : %u\r\n", (unsigned)MODEL_H_U32_LEN);
    printf("model_scaling_factor: %u\r\n", (unsigned)model_scaling_factor);
    printf("model_offset        : %f\r\n", model_offset);
    printf("model_f_data addr   : %p\r\n", (void *)model_f_data);
    printf("MODEL_F_LEN         : %u\r\n", (unsigned)MODEL_F_LEN);

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

    // Core 0's l1_j_spm is pre-loaded by the ELF loader (no DMA needed).
    // DMA J matrix from core 0's l1_j_spm to each remaining core's l1_j_spm.
    uint64_t j_dma_src = IC_MEM_BASE_ADDR;
    uint64_t j_dma_size = MODEL_J_LEN * sizeof(uint64_t);
    for (unsigned core = 1; core < NUM_ISING_CORES; core++) {
        uint64_t j_dma_dst = IC_MEM_BASE_ADDR + (uint64_t)core * IC_L1_MEM_LIMIT;
        uint64_t t6 = clint_get_mtime();
        sys_dma_blk_memcpy(j_dma_dst, j_dma_src, j_dma_size, DMA_CONF_DECOUPLE_ALL);
        uint64_t t7 = clint_get_mtime();
        printf("DMA J l1c0->l1c%u   : %llu us\r\n", core, (t7 - t6) * 1000000ULL / rtc_freq);
    }

    // Core 0's l1_f_spm is pre-loaded by the ELF loader (no DMA needed).
    // DMA flip data from core 0's l1_f_spm to each remaining core's l1_f_spm.
    uint64_t f_dma_src = IC_J_MEM_END_ADDR;
    uint64_t f_dma_size = MODEL_F_LEN * sizeof(uint64_t);
    for (unsigned core = 1; core < NUM_ISING_CORES; core++) {
        uint64_t f_dma_dst = IC_J_MEM_END_ADDR + (uint64_t)core * IC_L1_MEM_LIMIT;
        uint64_t t8 = clint_get_mtime();
        sys_dma_blk_memcpy(f_dma_dst, f_dma_src, f_dma_size, DMA_CONF_DECOUPLE_ALL);
        uint64_t t9 = clint_get_mtime();
        printf("DMA F l1c0->l1c%u   : %llu us\r\n", core, (t9 - t8) * 1000000ULL / rtc_freq);
    }

    uint64_t t10 = clint_get_mtime();
    printf("=== LAGD Register Configuration ===\r\n");
    lagd_configure_initial_spins(0);
    lagd_configure_cmpt_max_num(0);
    lagd_configure_counters(0);
    lagd_configure_wwl_vdd_cfg(0);
    lagd_configure_wwl_vread_cfg(0);
    lagd_configure_spin_wwl_strobe(0);
    lagd_configure_spin_feedback(0);
    lagd_configure_h_rdata(0);
    lagd_configure_wbl_floating(0);
    lagd_configure_debug_j_one_hot_wwl(0);
    lagd_configure_global_cfg_1(0);
    lagd_configure_global_cfg_2(0);
    // clear config valid
    lagd_clear_config_valid(0);
    uint64_t t11 = clint_get_mtime();
    printf("LAGD reg config: %llu us\r\n", (t11 - t10) * 1000000ULL / rtc_freq);
    printf("=== LAGD Analog Onloading ===\r\n");
    // start analog onloading
    lagd_enable_analog_onloading(0);
    // wait for analog onloading to finish
    lagd_wait_for_analog_onloading_done(0);
    uint64_t t12 = clint_get_mtime();
    printf("LAGD analog onloading: %llu us\r\n", (t12 - t11) * 1000000ULL / rtc_freq);
    printf("=== LAGD Computation Start ===\r\n");
    // start computation
    lagd_enable_energy_monitor_fifo(0);
    lagd_enable_computation(0);
    printf("=== LAGD Waiting for Computation to Finish ===\r\n");
    // wait for computation to start
    lagd_wait_for_computation_start(0);
    // wait for computation to finish
    lagd_wait_for_computation_done(0);
    uint64_t t13 = clint_get_mtime();
    printf("LAGD computation time: %llu us\r\n", (t13 - t12) * 1000000ULL / rtc_freq);
    // print output
    lagd_print_output_status(0);
    lagd_print_energy_fifo_data(0);
    lagd_print_spin_fifo_data(0);
    // checks
    lagd_check_spin_fifo_data(0);

    printf("=== DONE ===\r\n");
    uart_write_flush(&__base_uart);
    return 0;
}
