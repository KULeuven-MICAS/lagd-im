// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Jiacong Sun <jiacong.sun@kuleuven.be>

#ifndef CORE_TESTED
#define CORE_TESTED 0
#endif

static const uint8_t  model_scaling_factor = 4;

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

int main(void) {
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
    lagd_configure_global_cfg_1(CORE_TESTED);
    lagd_configure_global_cfg_2(CORE_TESTED);
    // clear config valid
    lagd_clear_config_valid(CORE_TESTED);

    /////////////////////////////////////////////////////////////////
    /////////////////////// DEBUG CONFIGURATION /////////////////////
    /////////////////////////////////////////////////////////////////
    // generate debug patterns
    static const uint32_t debug_j_one_hot_wwl[8] = {0x00000000U, 0x00000000U, 0x00000000U, 0x00000000U,
                                                    0x00000000U, 0x00000000U, 0x00000000U, 0x00000001U};
    static const uint32_t debug_wbl_config[32] = {
        0x00000000U, 0xFFFFFFFFU, 0x00000000U, 0xFFFFFFFFU, 0x00000000U, 0xFFFFFFFFU, 0xFFFFFFFFU,
        0x00000000U, 0xFFFFFFFFU, 0x00000000U, 0xFFFFFFFFU, 0x00000000U, 0xFFFFFFFFU, 0xFFFFFFFFU,
        0x00000000U, 0xFFFFFFFFU, 0x00000000U, 0xFFFFFFFFU, 0x00000000U, 0xFFFFFFFFU, 0xFFFFFFFFU,
        0x00000000U, 0xFFFFFFFFU, 0x00000000U, 0xFFFFFFFFU, 0x00000000U, 0xFFFFFFFFU, 0xFFFFFFFFU,
        0x00000000U, 0xFFFFFFFFU, 0x00000000U, 0xFFFFFFFFU};
    lagd_configure_debug_j_one_hot_wwl(CORE_TESTED);
    lagd_configure_debug_wbl_config(CORE_TESTED);
    // load debug patterns into the core
    lagd_enable_debug_dt_configure_enable(CORE_TESTED);
    lagd_disable_all_debug_enable(CORE_TESTED);
    // start dt debugging write
    lagd_enable_debug_j_write_en(CORE_TESTED);
    lagd_disable_all_debug_enable(CORE_TESTED);
    /////////////////////////////////////////////////////////////////
    /////////////////////// DEBUG READING ///////////////////////////
    /////////////////////////////////////////////////////////////////
    // generate wbl_floating pattern
    static const uint32_t wbl_floating[32] = {
        0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU,
        0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU,
        0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU,
        0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU,
        0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU};
    lagd_configure_wbl_floating(CORE_TESTED);
    // load debug patterns into the core
    lagd_enable_debug_dt_configure_enable(CORE_TESTED);
    lagd_disable_all_debug_enable(CORE_TESTED);
    // start dt read to csr
    lagd_enable_debug_j_read_en(CORE_TESTED);
    lagd_disable_all_debug_enable(CORE_TESTED);
    // read csr values and print
    lagd_print_debug_wbl_read_data(CORE_TESTED);
    lagd_print_debug_wblb_read_data(CORE_TESTED);
    
    printf("=== DONE ===\r\n");
    uart_write_flush(&__base_uart);
    return 0;
}