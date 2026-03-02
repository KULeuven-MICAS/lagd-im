// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// LAGD register initial configuration parameters

#pragma once
#include <stdint.h>

// Global configuration signals 1
#define GCFG1_FLUSH_EN 0
#define GCFG1_EN_AW 1
#define GCFG1_EN_EM 1
#define GCFG1_EN_FM 1
#define GCFG1_EN_FF 1
#define GCFG1_EN_EF 0
#define GCFG1_EN_ANALOG_LOOP 1
#define GCFG1_EN_COMPARISON 1
#define GCFG1_DEBUG_DT_CONFIGURE_ENABLE 1
#define GCFG1_DEBUG_SPIN_CONFIGURE_ENABLE 1
#define GCFG1_EN_PERF_COUNTER 1
#define GCFG1_BYPASS_DATA_CONVERSION 0
#define GCFG1_HOST_READOUT 0
#define GCFG1_FLIP_DISABLE 0
#define GCFG1_ENABLE_FLIP_DETECTION 1
#define GCFG1_DEBUG_J_WRITE_EN 0
#define GCFG1_DEBUG_J_READ_EN 0
#define GCFG1_DEBUG_SPIN_WRITE_EN 0
#define GCFG1_DEBUG_SPIN_COMPUTE_EN 0
#define GCFG1_DEBUG_SPIN_READ_EN 0
#define GCFG1_WWL_VDD_CFG_256 1
#define GCFG1_WWL_VREAD_CFG_256 0
#define GCFG1_CONFIG_COUNTER 0xFF           // max: 0xFF (255)
#define GCFG1_SYNCHRONIZER_WBL_PIPE_NUM 0x3 // max: 0x3 (3)

// Global configuration signals 2
#define GCFG2_CMPT_EN 0
#define GCFG2_CONFIG_VALID_AW 1
#define GCFG2_CONFIG_VALID_EM 1
#define GCFG2_CONFIG_VALID_FM 1
#define GCFG2_DT_CFG_ENABLE 0
#define GCFG2_SYNCHRONIZER_PIPE_NUM 0x3 // max: 0x3 (3)
#define GCFG2_DEBUG_H_WWL 0
#define GCFG2_DGT_ADDR_UPPER_BOUND 0x3F // max: 0x3F (63)
#define GCFG2_CTNUS_FIFO_READ 0
#define GCFG2_CTNUS_DGT_DEBUG 0
#define GCFG2_INFINITE_ICON_LOOP_EN 0
#define GCFG2_MULTI_CMPT_MODE_EN 0
#define GCFG2_CONFIG_SPIN_INITIAL_SKIP_0 0
#define GCFG2_CONFIG_SPIN_INITIAL_SKIP_1 0
#define GCFG2_DGT_HSCALING model_scaling_factor // max: 0x3F (63)
#define GCFG2_ENERGY_FIFO_SEL 0 // 0: low 16 bits of energy, 1: high 16 bits of energy

// Computation max number configuration under multi_cmpt_mode
#define CMPT_MAX_NUM 0x00000001 // max: 0xFFFFFFFF (1 means 2 computation)

// Registers for counter configuration 1
#define CFG_TRANS_NUM 0x0040      // max: 0xFFFF
#define CYCLE_PER_WWL_HIGH 0x0005 // max: 0xFFFF (1 means 2 cycles)

// Registers for counter configuration 2
#define CYCLE_PER_WWL_LOW 0x0005    // max: 0xFFFF (1 means 2 cycles)
#define CYCLE_PER_SPIN_WRITE 0x0005 // max: 0xFFFF (1 means 2 cycles)

// Registers for counter configuration 3
#define CYCLE_PER_SPIN_COMPUTE 0x0005    // max: 0xFFFF (1 means 2 cycles)
#define DEBUG_CYCLE_PER_SPIN_READ 0x0005 // max: 0xFFFF (1 means 2 cycles)

// Registers for counter configuration 4
#define DEBUG_SPIN_READ_NUM 0x0005      // max: 0x03FF (1023)
#define ICON_LAST_RADDR_PLUS_ONE 0x0400 // max: 0x0400 (1024)

// wwl_vdd_cfg values
static const uint32_t wwl_vdd_cfg[8] = {0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU,
                                        0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU};

// wwl_vread_cfg values
static const uint32_t wwl_vread_cfg[8] = {0x00000000U, 0x00000000U, 0x00000000U, 0x00000000U,
                                          0x00000000U, 0x00000000U, 0x00000000U, 0x00000000U};

// spin_wwl_strobe values
static const uint32_t spin_wwl_strobe[8] = {0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU,
                                            0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU};

// spin_feedback values
static const uint32_t spin_feedback[8] = {0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU,
                                          0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU};

// wbl_floating values
static const uint32_t wbl_floating[32] = {
    0x00000000U, 0x00000000U, 0x00000000U, 0x00000000U, 0x00000000U, 0x00000000U, 0x00000000U,
    0x00000000U, 0x00000000U, 0x00000000U, 0x00000000U, 0x00000000U, 0x00000000U, 0x00000000U,
    0x00000000U, 0x00000000U, 0x00000000U, 0x00000000U, 0x00000000U, 0x00000000U, 0x00000000U,
    0x00000000U, 0x00000000U, 0x00000000U, 0x00000000U, 0x00000000U, 0x00000000U, 0x00000000U,
    0x00000000U, 0x00000000U, 0x00000000U, 0x00000000U};

// debug_wbl_config values
static const uint32_t debug_wbl_config[32] = {
    0x00000000U, 0xFFFFFFFFU, 0x00000000U, 0xFFFFFFFFU, 0x00000000U, 0xFFFFFFFFU, 0xFFFFFFFFU,
    0x00000000U, 0xFFFFFFFFU, 0x00000000U, 0xFFFFFFFFU, 0x00000000U, 0xFFFFFFFFU, 0xFFFFFFFFU,
    0x00000000U, 0xFFFFFFFFU, 0x00000000U, 0xFFFFFFFFU, 0x00000000U, 0xFFFFFFFFU, 0xFFFFFFFFU,
    0x00000000U, 0xFFFFFFFFU, 0x00000000U, 0xFFFFFFFFU, 0x00000000U, 0xFFFFFFFFU, 0xFFFFFFFFU,
    0x00000000U, 0xFFFFFFFFU, 0x00000000U, 0xFFFFFFFFU};

// debug_j_one_hot_wwl values: [31:0], [63:32], ..., [255:224]
static const uint32_t debug_j_one_hot_wwl[8] = {0x00000001U, 0x00000000U, 0x00000000U, 0x00000000U,
                                                0x00000000U, 0x00000000U, 0x00000000U, 0x00000000U};
