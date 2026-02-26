// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Header-only LAGD register configuration.

#pragma once

#include "lagd_define.h"
#include "lagd_core_reg.h"
#include "model_1_data.h"
#include "spin_data.h"
#include "lagd_reg_params.h"
#include "util.h"
#include "printf.h"

// Configure initial spin registers for the given core index.
static void lagd_configure_initial_spins(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    // Write initial spin set 0
    for (int i = 0; i < NUM_SPIN / 32; i++) {
        *reg32(base, LAGD_CORE_CONFIG_SPIN_INITIAL_0_0_REG_OFFSET + 4 * i) = spin_initial_0[i];
    }
    // Write initial spin set 1
    for (int i = 0; i < NUM_SPIN / 32; i++) {
        *reg32(base, LAGD_CORE_CONFIG_SPIN_INITIAL_1_0_REG_OFFSET + 4 * i) = spin_initial_1[i];
    }
}

// Configure counter registers
static void lagd_configure_counters(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    // Write counter configuration 1
    uint32_t cfg1 =
        ((CFG_TRANS_NUM & LAGD_CORE_COUNTER_CFG_1_CFG_TRANS_NUM_MASK) |
         ((CYCLE_PER_WWL_HIGH & LAGD_CORE_COUNTER_CFG_1_CYCLE_PER_WWL_HIGH_MASK) << 16));
    *reg32(base, LAGD_CORE_COUNTER_CFG_1_REG_OFFSET) = cfg1;
    // Write counter configuration 2
    uint32_t cfg2 =
        ((CYCLE_PER_WWL_LOW & LAGD_CORE_COUNTER_CFG_2_CYCLE_PER_WWL_LOW_MASK) |
         ((CYCLE_PER_SPIN_WRITE & LAGD_CORE_COUNTER_CFG_2_CYCLE_PER_SPIN_WRITE_MASK) << 16));
    *reg32(base, LAGD_CORE_COUNTER_CFG_2_REG_OFFSET) = cfg2;
    // Write counter configuration 3
    uint32_t cfg3 =
        ((CYCLE_PER_SPIN_COMPUTE & LAGD_CORE_COUNTER_CFG_3_CYCLE_PER_SPIN_COMPUTE_MASK) |
         ((DEBUG_CYCLE_PER_SPIN_READ & LAGD_CORE_COUNTER_CFG_3_DEBUG_CYCLE_PER_SPIN_READ_MASK)
          << 16));
    *reg32(base, LAGD_CORE_COUNTER_CFG_3_REG_OFFSET) = cfg3;
    // Write counter configuration 4
    uint32_t cfg4 =
        ((DEBUG_SPIN_READ_NUM & LAGD_CORE_COUNTER_CFG_4_DEBUG_SPIN_READ_NUM_MASK) |
         ((ICON_LAST_RADDR_PLUS_ONE & LAGD_CORE_COUNTER_CFG_4_ICON_LAST_RADDR_PLUS_ONE_MASK)
          << 16));
    *reg32(base, LAGD_CORE_COUNTER_CFG_4_REG_OFFSET) = cfg4;
}

// Configure cmpt_max_num register
static void lagd_configure_cmpt_max_num(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    *reg32(base, LAGD_CORE_CMPT_MAX_NUM_REG_OFFSET) = CMPT_MAX_NUM;
}

// Configure wwl_vdd_cfg registers
static void lagd_configure_wwl_vdd_cfg(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    for (int i = 0; i < NUM_SPIN / 32; i++) {
        *reg32(base, LAGD_CORE_WWL_VDD_CFG_0_REG_OFFSET + 4 * i) = wwl_vdd_cfg[i];
    }
}

// Configure wwl_vread_cfg registers
static void lagd_configure_wwl_vread_cfg(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    for (int i = 0; i < NUM_SPIN / 32; i++) {
        *reg32(base, LAGD_CORE_WWL_VREAD_CFG_0_REG_OFFSET + 4 * i) = wwl_vread_cfg[i];
    }
}

// Configure spin_wwl_strobe registers
static void lagd_configure_spin_wwl_strobe(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    for (int i = 0; i < NUM_SPIN / 32; i++) {
        *reg32(base, LAGD_CORE_SPIN_WWL_STROBE_0_REG_OFFSET + 4 * i) = spin_wwl_strobe[i];
    }
}

// Configure spin_feedback registers
static void lagd_configure_spin_feedback(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    for (int i = 0; i < NUM_SPIN / 32; i++) {
        *reg32(base, LAGD_CORE_SPIN_FEEDBACK_CFG_0_REG_OFFSET + 4 * i) = spin_feedback[i];
    }
}

// Configure h_rdata registers
static void lagd_configure_h_rdata(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    for (int i = 0; i < NUM_SPIN * BIT_H / 32; i++) {
        *reg32(base, LAGD_CORE_H_RDATA_0_REG_OFFSET + 4 * i) = model_h_data[i];
    }
}

// Configure wbl_floating registers
static void lagd_configure_wbl_floating(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    for (int i = 0; i < NUM_SPIN * BIT_H / 32; i++) {
        *reg32(base, LAGD_CORE_WBL_FLOATING_0_REG_OFFSET + 4 * i) = wbl_floating[i];
    }
}

// Configure debug_j_one_hot_wwl registers
static void lagd_configure_debug_j_one_hot_wwl(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    for (int i = 0; i < NUM_SPIN / 32; i++) {
        *reg32(base, LAGD_CORE_DEBUG_J_ONE_HOT_WWL_0_REG_OFFSET + 4 * i) = debug_j_one_hot_wwl[i];
    }
}

// Configure global_cfg_1 register
static void lagd_configure_global_cfg_1(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    uint32_t cfg1 =
        (((GCFG1_FLUSH_EN & 0x1) << LAGD_CORE_GLOBAL_CFG_1_FLUSH_EN_BIT) |
         ((GCFG1_EN_AW & 0x1) << LAGD_CORE_GLOBAL_CFG_1_EN_AW_BIT) |
         ((GCFG1_EN_EM & 0x1) << LAGD_CORE_GLOBAL_CFG_1_EN_EM_BIT) |
         ((GCFG1_EN_FM & 0x1) << LAGD_CORE_GLOBAL_CFG_1_EN_FM_BIT) |
         ((GCFG1_EN_FF & 0x1) << LAGD_CORE_GLOBAL_CFG_1_EN_FF_BIT) |
         ((GCFG1_EN_EF & 0x1) << LAGD_CORE_GLOBAL_CFG_1_EN_EF_BIT) |
         ((GCFG1_EN_ANALOG_LOOP & 0x1) << LAGD_CORE_GLOBAL_CFG_1_EN_ANALOG_LOOP_BIT) |
         ((GCFG1_EN_COMPARISON & 0x1) << LAGD_CORE_GLOBAL_CFG_1_EN_COMPARISON_BIT) |
         ((GCFG1_DEBUG_DT_CONFIGURE_ENABLE & 0x1)
          << LAGD_CORE_GLOBAL_CFG_1_DEBUG_DT_CONFIGURE_ENABLE_BIT) |
         ((GCFG1_DEBUG_SPIN_CONFIGURE_ENABLE & 0x1)
          << LAGD_CORE_GLOBAL_CFG_1_DEBUG_SPIN_CONFIGURE_ENABLE_BIT) |
         ((GCFG1_EN_PERF_COUNTER & 0x1) << LAGD_CORE_GLOBAL_CFG_1_EN_PERF_COUNTER_BIT) |
         ((GCFG1_BYPASS_DATA_CONVERSION & 0x1)
          << LAGD_CORE_GLOBAL_CFG_1_BYPASS_DATA_CONVERSION_BIT) |
         ((GCFG1_HOST_READOUT & 0x1) << LAGD_CORE_GLOBAL_CFG_1_HOST_READOUT_BIT) |
         ((GCFG1_FLIP_DISABLE & 0x1) << LAGD_CORE_GLOBAL_CFG_1_FLIP_DISABLE_BIT) |
         ((GCFG1_ENABLE_FLIP_DETECTION & 0x1) << LAGD_CORE_GLOBAL_CFG_1_ENABLE_FLIP_DETECTION_BIT) |
         ((GCFG1_DEBUG_J_WRITE_EN & 0x1) << LAGD_CORE_GLOBAL_CFG_1_DEBUG_J_WRITE_EN_BIT) |
         ((GCFG1_DEBUG_J_READ_EN & 0x1) << LAGD_CORE_GLOBAL_CFG_1_DEBUG_J_READ_EN_BIT) |
         ((GCFG1_DEBUG_SPIN_WRITE_EN & 0x1) << LAGD_CORE_GLOBAL_CFG_1_DEBUG_SPIN_WRITE_EN_BIT) |
         ((GCFG1_DEBUG_SPIN_COMPUTE_EN & 0x1) << LAGD_CORE_GLOBAL_CFG_1_DEBUG_SPIN_COMPUTE_EN_BIT) |
         ((GCFG1_DEBUG_SPIN_READ_EN & 0x1) << LAGD_CORE_GLOBAL_CFG_1_DEBUG_SPIN_READ_EN_BIT) |
         ((GCFG1_CONFIG_COUNTER & LAGD_CORE_GLOBAL_CFG_1_CONFIG_COUNTER_MASK)
          << LAGD_CORE_GLOBAL_CFG_1_CONFIG_COUNTER_OFFSET) |
         ((GCFG1_WWL_VDD_CFG_256 & 0x1) << LAGD_CORE_GLOBAL_CFG_1_WWL_VDD_CFG_256_BIT) |
         ((GCFG1_WWL_VREAD_CFG_256 & 0x1) << LAGD_CORE_GLOBAL_CFG_1_WWL_VREAD_CFG_256_BIT) |
         ((GCFG1_SYNCHRONIZER_WBL_PIPE_NUM & LAGD_CORE_GLOBAL_CFG_1_SYNCHRONIZER_WBL_PIPE_NUM_MASK)
          << LAGD_CORE_GLOBAL_CFG_1_SYNCHRONIZER_WBL_PIPE_NUM_OFFSET));
    *reg32(base, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET) = cfg1;
}

// Configure global_cfg_2 register
static void lagd_configure_global_cfg_2(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    uint32_t cfg2 =
        (((GCFG2_CMPT_EN & 0x1) << LAGD_CORE_GLOBAL_CFG_2_CMPT_EN_BIT) |
         ((GCFG2_CONFIG_VALID_AW & 0x1) << LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_AW_BIT) |
         ((GCFG2_CONFIG_VALID_EM & 0x1) << LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_EM_BIT) |
         ((GCFG2_CONFIG_VALID_FM & 0x1) << LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_FM_BIT) |
         ((GCFG2_DT_CFG_ENABLE & 0x1) << LAGD_CORE_GLOBAL_CFG_2_DT_CFG_ENABLE_BIT) |
         ((GCFG2_SYNCHRONIZER_PIPE_NUM & LAGD_CORE_GLOBAL_CFG_2_SYNCHRONIZER_PIPE_NUM_MASK)
          << LAGD_CORE_GLOBAL_CFG_2_SYNCHRONIZER_PIPE_NUM_OFFSET) |
         ((GCFG2_DEBUG_H_WWL & 0x1) << LAGD_CORE_GLOBAL_CFG_2_DEBUG_H_WWL_BIT) |
         ((GCFG2_DGT_ADDR_UPPER_BOUND & LAGD_CORE_GLOBAL_CFG_2_DGT_ADDR_UPPER_BOUND_MASK)
          << LAGD_CORE_GLOBAL_CFG_2_DGT_ADDR_UPPER_BOUND_OFFSET) |
         ((GCFG2_CTNUS_FIFO_READ & 0x1) << LAGD_CORE_GLOBAL_CFG_2_CTNUS_FIFO_READ_BIT) |
         ((GCFG2_CTNUS_DGT_DEBUG & 0x1) << LAGD_CORE_GLOBAL_CFG_2_CTNUS_DGT_DEBUG_BIT) |
         ((GCFG2_INFINITE_ICON_LOOP_EN & 0x1) << LAGD_CORE_GLOBAL_CFG_2_INFINITE_ICON_LOOP_EN_BIT) |
         ((GCFG2_MULTI_CMPT_MODE_EN & 0x1) << LAGD_CORE_GLOBAL_CFG_2_MULTI_CMPT_MODE_EN_BIT) |
         ((GCFG2_CONFIG_SPIN_INITIAL_SKIP_0 & 0x1)
          << LAGD_CORE_GLOBAL_CFG_2_CONFIG_SPIN_INITIAL_SKIP_0_BIT) |
         ((GCFG2_CONFIG_SPIN_INITIAL_SKIP_1 & 0x1)
          << LAGD_CORE_GLOBAL_CFG_2_CONFIG_SPIN_INITIAL_SKIP_1_BIT) |
         ((GCFG2_DGT_HSCALING & LAGD_CORE_GLOBAL_CFG_2_DGT_HSCALING_MASK)
          << LAGD_CORE_GLOBAL_CFG_2_DGT_HSCALING_OFFSET));
    *reg32(base, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET) = cfg2;
    // printf("Core %u global_cfg_2: 0x%08x, addr 0x%08x\r\n", core, cfg2,
    //        (uintptr_t)base + LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET);
}

// Switch off config valid signals
// This includes: CONFIG_VALID_AW, CONFIG_VALID_EM, CONFIG_VALID_FM in global_cfg_2 register
// and: DEBUG_DT_CONFIGURE_ENABLE, DEBUG_SPIN_CONFIGURE_ENABLE in global_cfg_1 register (if they are
// set).
static void lagd_clear_config_valid(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    uint32_t cfg2 = *reg32(base, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET);
    cfg2 &= ~((1 << LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_AW_BIT) |
              (1 << LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_EM_BIT) |
              (1 << LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_FM_BIT));
    *reg32(base, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET) = cfg2;
    // printf("Core %u global_cfg_2 after clearing config valid: 0x%08x\r\n", core, cfg2);

    uint32_t cfg1 = *reg32(base, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET);
    cfg1 &= ~((1 << LAGD_CORE_GLOBAL_CFG_1_DEBUG_DT_CONFIGURE_ENABLE_BIT) |
              (1 << LAGD_CORE_GLOBAL_CFG_1_DEBUG_SPIN_CONFIGURE_ENABLE_BIT));
    *reg32(base, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET) = cfg1;
    // printf("Core %u global_cfg_1 after clearing debug configure enable: 0x%08x\r\n", core, cfg1);
}

// Enable analog data onloading by setting DT_CFG_ENABLE bit in global_cfg_2 register
static void lagd_enable_analog_onloading(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    uint32_t cfg2 = *reg32(base, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET);
    cfg2 |= (1 << LAGD_CORE_GLOBAL_CFG_2_DT_CFG_ENABLE_BIT);
    *reg32(base, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET) = cfg2;
    // reset the register
    cfg2 &= ~(1 << LAGD_CORE_GLOBAL_CFG_2_DT_CFG_ENABLE_BIT);
    *reg32(base, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET) = cfg2;
}

// Check and wait until analog data onloading is done by polling DT_CFG_IDLE bit in output_status
// register
static void lagd_wait_for_analog_onloading_done(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    while ((*reg32(base, LAGD_CORE_OUTPUT_STATUS_REG_OFFSET) &
            (1 << LAGD_CORE_OUTPUT_STATUS_DT_CFG_IDLE_BIT)) == 0)
        ;
}

// Enable computation by setting cmpt_en bit in global_cfg_2 register
static void lagd_enable_computation(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    uint32_t cfg2 = *reg32(base, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET);
    cfg2 |= (1 << LAGD_CORE_GLOBAL_CFG_2_CMPT_EN_BIT);
    *reg32(base, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET) = cfg2;
}

// Enable EN_EF to start energy monitor fifo after J memory onloading and before computation
static void lagd_enable_energy_monitor_fifo(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    uint32_t cfg1 = *reg32(base, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET);
    cfg1 |= (1 << LAGD_CORE_GLOBAL_CFG_1_EN_EF_BIT);
    *reg32(base, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET) = cfg1;
}

// Enable computation with multi_cmpt_mode
static void lagd_enable_computation_multi_cmpt_mode(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    uint32_t cfg2 = *reg32(base, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET);
    cfg2 |= (1 << LAGD_CORE_GLOBAL_CFG_2_CMPT_EN_BIT) |
            (1 << LAGD_CORE_GLOBAL_CFG_2_MULTI_CMPT_MODE_EN_BIT);
    *reg32(base, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET) = cfg2;
}

// Check and wait until the computation starts by polling CMPT_IDLE bit in output_status register
static void lagd_wait_for_computation_start(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    while ((*reg32(base, LAGD_CORE_OUTPUT_STATUS_REG_OFFSET) &
            (1 << LAGD_CORE_OUTPUT_STATUS_CMPT_IDLE_BIT)) != 0)
        ;
}

// Check and wait until single computation is done by polling CMPT_IDLE bit in output_status
// register
static void lagd_wait_for_computation_done(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    while ((*reg32(base, LAGD_CORE_OUTPUT_STATUS_REG_OFFSET) &
            (1 << LAGD_CORE_OUTPUT_STATUS_CMPT_IDLE_BIT)) == 0)
        ;
}

// Check and wait until computation under multi_cmpt_mode is done by polling MULTI_CMPT_MODE_IDLE
// bit in output_status register
static void lagd_wait_for_computation_multi_cmpt_mode_done(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    while ((*reg32(base, LAGD_CORE_OUTPUT_STATUS_REG_OFFSET) &
            (1 << LAGD_CORE_OUTPUT_STATUS_MULTI_CMPT_MODE_IDLE_BIT)) == 0)
        ;
}

// Read output_status register and print the status of each bit
static void lagd_print_output_status(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    uint32_t status = *reg32(base, LAGD_CORE_OUTPUT_STATUS_REG_OFFSET);
    printf("Output status for core %u: 0x%08x\r\n", core, status);
    printf("  DT_CFG_IDLE: %u\r\n", (status >> LAGD_CORE_OUTPUT_STATUS_DT_CFG_IDLE_BIT) & 0x1);
    printf("  CMPT_IDLE: %u\r\n", (status >> LAGD_CORE_OUTPUT_STATUS_CMPT_IDLE_BIT) & 0x1);
    printf("  ENERGY_FIFO_UPDATE: %u\r\n",
           (status >> LAGD_CORE_OUTPUT_STATUS_ENERGY_FIFO_UPDATE_BIT) & 0x1);
    printf("  SPIN_FIFO_UPDATE: %u\r\n",
           (status >> LAGD_CORE_OUTPUT_STATUS_SPIN_FIFO_UPDATE_BIT) & 0x1);
    printf("  DEBUG_WBL_READ_DATA_VALID: %u\r\n",
           (status >> LAGD_CORE_OUTPUT_STATUS_DEBUG_WBL_READ_DATA_VALID_BIT) & 0x1);
    printf("  DEBUG_ANALOG_DT_W_IDLE: %u\r\n",
           (status >> LAGD_CORE_OUTPUT_STATUS_DEBUG_ANALOG_DT_W_IDLE_BIT) & 0x1);
    printf("  DEBUG_ANALOG_DT_R_IDLE: %u\r\n",
           (status >> LAGD_CORE_OUTPUT_STATUS_DEBUG_ANALOG_DT_R_IDLE_BIT) & 0x1);
    printf("  DEBUG_SPIN_W_IDLE: %u\r\n",
           (status >> LAGD_CORE_OUTPUT_STATUS_DEBUG_SPIN_W_IDLE_BIT) & 0x1);
    printf("  DEBUG_SPIN_R_IDLE: %u\r\n",
           (status >> LAGD_CORE_OUTPUT_STATUS_DEBUG_SPIN_R_IDLE_BIT) & 0x1);
    printf("  DEBUG_SPIN_CMPT_IDLE: %u\r\n",
           (status >> LAGD_CORE_OUTPUT_STATUS_DEBUG_SPIN_CMPT_IDLE_BIT) & 0x1);
    printf("  DEBUG_FM_UPSTREAM_HANDSHAKE: %u\r\n",
           (status >> LAGD_CORE_OUTPUT_STATUS_DEBUG_FM_UPSTREAM_HANDSHAKE_BIT) & 0x1);
    printf("  DEBUG_FM_DOWNSTREAM_HANDSHAKE: %u\r\n",
           (status >> LAGD_CORE_OUTPUT_STATUS_DEBUG_FM_DOWNSTREAM_HANDSHAKE_BIT) & 0x1);
    printf("  DEBUG_AW_DOWNSTREAM_HANDSHAKE: %u\r\n",
           (status >> LAGD_CORE_OUTPUT_STATUS_DEBUG_AW_DOWNSTREAM_HANDSHAKE_BIT) & 0x1);
    printf("  DEBUG_EM_UPSTREAM_HANDSHAKE: %u\r\n",
           (status >> LAGD_CORE_OUTPUT_STATUS_DEBUG_EM_UPSTREAM_HANDSHAKE_BIT) & 0x1);
    printf("  MULTI_CMPT_MODE_IDLE: %u\r\n",
           (status >> LAGD_CORE_OUTPUT_STATUS_MULTI_CMPT_MODE_IDLE_BIT) & 0x1);
}

// Read out debug_fm_energy_input register and print the value
static void lagd_print_debug_fm_energy_input(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    uint32_t energy_input = *reg32(base, LAGD_CORE_DEBUG_FM_ENERGY_INPUT_REG_OFFSET);
    printf("Debug FM energy input for core %u: 0x%08x\r\n", core, energy_input);
}

// Read out energy_fifo_data register and print the value
static void lagd_print_energy_fifo_data(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    uint32_t energy_fifo_data_0 = *reg32(base, LAGD_CORE_ENERGY_FIFO_DATA_0_REG_OFFSET);
    uint32_t energy_fifo_data_1 = *reg32(base, LAGD_CORE_ENERGY_FIFO_DATA_1_REG_OFFSET);
    printf("Energy FIFO data 0 for core %u: 0x%08x\r\n", core, energy_fifo_data_0);
    printf("Energy FIFO data 1 for core %u: 0x%08x\r\n", core, energy_fifo_data_1);
}

// Read out spin_fifo_data register and print the value
static void lagd_print_spin_fifo_data(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);

    uint32_t spin_fifo_data_0[NUM_SPIN / 32], spin_fifo_data_1[NUM_SPIN / 32];
    for (int i = 0; i < NUM_SPIN / 32; i++) {
        spin_fifo_data_0[i] = *reg32(base, LAGD_CORE_SPIN_FIFO_DATA_0_0_REG_OFFSET + 4 * i);
        spin_fifo_data_1[i] = *reg32(base, LAGD_CORE_SPIN_FIFO_DATA_1_0_REG_OFFSET + 4 * i);
    }

    // Print MSB-first (word[7]=bits255:224 ... word[0]=bits31:0)
    printf("spin_fifo_data_0[%u]: ", core);
    for (int i = NUM_SPIN / 32 - 1; i >= 0; i--) printf("%08x", spin_fifo_data_0[i]);
    printf("\r\n");

    printf("spin_fifo_data_1[%u]: ", core);
    for (int i = NUM_SPIN / 32 - 1; i >= 0; i--) printf("%08x", spin_fifo_data_1[i]);
    printf("\r\n");
}

// Compare the values in spin_fifo_data registers with the expected values and print the mismatch if
// any
static void lagd_check_spin_fifo_data(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);

    uint32_t spin_fifo_data_0[NUM_SPIN / 32], spin_fifo_data_1[NUM_SPIN / 32];
    for (int i = 0; i < NUM_SPIN / 32; i++) {
        spin_fifo_data_0[i] = *reg32(base, LAGD_CORE_SPIN_FIFO_DATA_0_0_REG_OFFSET + 4 * i);
        spin_fifo_data_1[i] = *reg32(base, LAGD_CORE_SPIN_FIFO_DATA_1_0_REG_OFFSET + 4 * i);
    }

    int pass0 = 1, pass1 = 1;
    for (int i = 0; i < NUM_SPIN / 32; i++) {
        if (spin_fifo_data_0[i] != spin_ref_0[i]) {
            pass0 = 0;
            break; // stop at the first mismatch
        }
        if (spin_fifo_data_1[i] != spin_ref_1[i]) {
            pass1 = 0;
            break; // stop at the first mismatch
        }
    }

    printf("spin_fifo_data_0[%u]: %08x%08x%08x%08x%08x%08x%08x%08x ", core, spin_fifo_data_0[7],
           spin_fifo_data_0[6], spin_fifo_data_0[5], spin_fifo_data_0[4], spin_fifo_data_0[3],
           spin_fifo_data_0[2], spin_fifo_data_0[1], spin_fifo_data_0[0]);
    if (pass0) {
        printf("[PASS]\r\n");
    } else {
        printf("[FAIL] expected %08x%08x%08x%08x%08x%08x%08x%08x\r\n", spin_ref_0[7], spin_ref_0[6],
               spin_ref_0[5], spin_ref_0[4], spin_ref_0[3], spin_ref_0[2], spin_ref_0[1],
               spin_ref_0[0]);
    }

    printf("spin_fifo_data_1[%u]: %08x%08x%08x%08x%08x%08x%08x%08x ", core, spin_fifo_data_1[7],
           spin_fifo_data_1[6], spin_fifo_data_1[5], spin_fifo_data_1[4], spin_fifo_data_1[3],
           spin_fifo_data_1[2], spin_fifo_data_1[1], spin_fifo_data_1[0]);
    if (pass1) {
        printf("[PASS]\r\n");
    } else {
        printf("[FAIL] expected %08x%08x%08x%08x%08x%08x%08x%08x\r\n", spin_ref_1[7], spin_ref_1[6],
               spin_ref_1[5], spin_ref_1[4], spin_ref_1[3], spin_ref_1[2], spin_ref_1[1],
               spin_ref_1[0]);
    }
}

// Read out cmpt_idx performance counter and print the value
static void lagd_print_cmpt_idx(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    uint32_t cmpt_idx = *reg32(base, LAGD_CORE_CMPT_IDX_REG_OFFSET);
    printf("Computation index for core %u: %u\r\n", core, cmpt_idx);
}

// Printf cycle/iteration and cycle/cmpt performance counters
static void lagd_print_cycle_per_iteration(unsigned core, unsigned sample_count, uint32_t *log_buf) {
    uint32_t cycle_per_cmpt_status;
    for (unsigned i = 0; i < sample_count; i++) {
        cycle_per_cmpt_status = log_buf[i];
        printf("idx/cmpt_idle/multi_cmpt_idle/recount/cc_iter/cc_cmpt for core %u: %u %u %u %u %u %u\r\n",
            core,
            i,
            (cycle_per_cmpt_status >> LAGD_CORE_CYCLE_PER_CMPT_AND_ITER_CMPT_IDLE_BIT) & 0x1,
            (cycle_per_cmpt_status >> LAGD_CORE_CYCLE_PER_CMPT_AND_ITER_MULTI_CMPT_MODE_IDLE_BIT) & 0x1,
            (cycle_per_cmpt_status >> LAGD_CORE_CYCLE_PER_CMPT_AND_ITER_CYCLE_PER_ITER_RECOUNT_EN_BIT) & 0x1,
            (cycle_per_cmpt_status >> LAGD_CORE_CYCLE_PER_CMPT_AND_ITER_CYCLE_PER_ITERATION_OFFSET) &
            LAGD_CORE_CYCLE_PER_CMPT_AND_ITER_CYCLE_PER_ITERATION_MASK,
            (cycle_per_cmpt_status >> LAGD_CORE_CYCLE_PER_CMPT_AND_ITER_CYCLE_PER_CMPT_OFFSET) &
            LAGD_CORE_CYCLE_PER_CMPT_AND_ITER_CYCLE_PER_CMPT_MASK);
        }

}

// Read out cycle_per_cmpt performance counter and print the value
static void lagd_print_cycle_per_cmpt(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    uint32_t cycle_per_cmpt_status = *reg32(base, LAGD_CORE_CYCLE_PER_CMPT_AND_ITER_REG_OFFSET);
    uint32_t cycle_per_cmpt = (cycle_per_cmpt_status >> LAGD_CORE_CYCLE_PER_CMPT_AND_ITER_CYCLE_PER_CMPT_OFFSET) &
                              LAGD_CORE_CYCLE_PER_CMPT_AND_ITER_CYCLE_PER_CMPT_MASK;
    printf("Cycle per computation for core %u: %u\r\n", core, cycle_per_cmpt);
}

// Continuously read out cycle_per_iteration until the computation is done
static unsigned lagd_monitor_cycle_per_iteration(unsigned core, unsigned max_samples, uint32_t *log_buf) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    uint8_t loop_en = 1;
    unsigned log_idx = 0;
    while (loop_en) {
        uint32_t val = *reg32(base, LAGD_CORE_CYCLE_PER_CMPT_AND_ITER_REG_OFFSET);
        if (log_idx < max_samples) {
            if (((val >> LAGD_CORE_CYCLE_PER_CMPT_AND_ITER_CMPT_IDLE_BIT) & 0x1) == 0 &&
            ((val >> LAGD_CORE_CYCLE_PER_CMPT_AND_ITER_MULTI_CMPT_MODE_IDLE_BIT) & 0x1)) {
            log_buf[log_idx++] = val;
            }
        }
        if (((val >> LAGD_CORE_CYCLE_PER_CMPT_AND_ITER_CMPT_IDLE_BIT) & 0x1) &&
            ((val >> LAGD_CORE_CYCLE_PER_CMPT_AND_ITER_MULTI_CMPT_MODE_IDLE_BIT) & 0x1)) {
            loop_en = 0;
        }
    }
    return log_idx;
}

// Read out cycle_all_cmpt performance counters and print the values
static void lagd_print_cycle_all_cmpt(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    uint32_t cycle_all_cmpt_lsb = *reg32(base, LAGD_CORE_CYCLE_ALL_CMPT_LSB_REG_OFFSET);
    uint32_t cycle_all_cmpt_msb = *reg32(base, LAGD_CORE_CYCLE_ALL_CMPT_MSB_REG_OFFSET);
    uint64_t cycle_all_cmpt = ((uint64_t)cycle_all_cmpt_msb << 32) | cycle_all_cmpt_lsb;
    printf("Cycle for all computations for core %u: %llu\r\n", core, cycle_all_cmpt);
}
