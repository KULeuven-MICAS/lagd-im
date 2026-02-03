// Generated register defines for lagd_core

// Copyright information found in source file:
// Copyright 2025 KU Leuven.

// Licensing information found in source file:
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef _LAGD_CORE_REG_DEFS_
#define _LAGD_CORE_REG_DEFS_

#ifdef __cplusplus
extern "C" {
#endif
// Register width
#define LAGD_CORE_PARAM_REG_WIDTH 32

// Global configuration signals 1
#define LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET 0x0
#define LAGD_CORE_GLOBAL_CFG_1_FLUSH_EN_BIT 0
#define LAGD_CORE_GLOBAL_CFG_1_EN_AW_BIT 1
#define LAGD_CORE_GLOBAL_CFG_1_EN_EM_BIT 2
#define LAGD_CORE_GLOBAL_CFG_1_EN_FM_BIT 3
#define LAGD_CORE_GLOBAL_CFG_1_EN_FF_BIT 4
#define LAGD_CORE_GLOBAL_CFG_1_EN_EF_BIT 5
#define LAGD_CORE_GLOBAL_CFG_1_EN_ANALOG_LOOP_BIT 6
#define LAGD_CORE_GLOBAL_CFG_1_EN_COMPARISON_BIT 7
#define LAGD_CORE_GLOBAL_CFG_1_DEBUG_DT_CONFIGURE_ENABLE_BIT 8
#define LAGD_CORE_GLOBAL_CFG_1_DEBUG_SPIN_CONFIGURE_ENABLE_BIT 9
#define LAGD_CORE_GLOBAL_CFG_1_CONFIG_SPIN_INITIAL_SKIP_BIT 10
#define LAGD_CORE_GLOBAL_CFG_1_BYPASS_DATA_CONVERSION_BIT 11
#define LAGD_CORE_GLOBAL_CFG_1_HOST_READOUT_BIT 12
#define LAGD_CORE_GLOBAL_CFG_1_FLIP_DISABLE_BIT 13
#define LAGD_CORE_GLOBAL_CFG_1_ENABLE_FLIP_DETECTION_BIT 14
#define LAGD_CORE_GLOBAL_CFG_1_DEBUG_J_WRITE_EN_BIT 15
#define LAGD_CORE_GLOBAL_CFG_1_DEBUG_J_READ_EN_BIT 16
#define LAGD_CORE_GLOBAL_CFG_1_DEBUG_SPIN_WRITE_EN_BIT 17
#define LAGD_CORE_GLOBAL_CFG_1_DEBUG_SPIN_COMPUTE_EN_BIT 18
#define LAGD_CORE_GLOBAL_CFG_1_DEBUG_SPIN_READ_EN_BIT 19
#define LAGD_CORE_GLOBAL_CFG_1_CONFIG_COUNTER_MASK 0xff
#define LAGD_CORE_GLOBAL_CFG_1_CONFIG_COUNTER_OFFSET 20
#define LAGD_CORE_GLOBAL_CFG_1_CONFIG_COUNTER_FIELD \
  ((bitfield_field32_t) { .mask = LAGD_CORE_GLOBAL_CFG_1_CONFIG_COUNTER_MASK, .index = LAGD_CORE_GLOBAL_CFG_1_CONFIG_COUNTER_OFFSET })
#define LAGD_CORE_GLOBAL_CFG_1_WWL_VDD_CFG_256_BIT 28
#define LAGD_CORE_GLOBAL_CFG_1_WWL_VREAD_CFG_256_BIT 29
#define LAGD_CORE_GLOBAL_CFG_1_SYNCHRONIZER_WBL_PIPE_NUM_MASK 0x3
#define LAGD_CORE_GLOBAL_CFG_1_SYNCHRONIZER_WBL_PIPE_NUM_OFFSET 30
#define LAGD_CORE_GLOBAL_CFG_1_SYNCHRONIZER_WBL_PIPE_NUM_FIELD \
  ((bitfield_field32_t) { .mask = LAGD_CORE_GLOBAL_CFG_1_SYNCHRONIZER_WBL_PIPE_NUM_MASK, .index = LAGD_CORE_GLOBAL_CFG_1_SYNCHRONIZER_WBL_PIPE_NUM_OFFSET })

// Global configuration signals 2
#define LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET 0x4
#define LAGD_CORE_GLOBAL_CFG_2_CMPT_EN_BIT 0
#define LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_AW_BIT 1
#define LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_EM_BIT 2
#define LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_FM_BIT 3
#define LAGD_CORE_GLOBAL_CFG_2_DT_CFG_ENABLE_BIT 4
#define LAGD_CORE_GLOBAL_CFG_2_SYNCHRONIZER_PIPE_NUM_MASK 0x3
#define LAGD_CORE_GLOBAL_CFG_2_SYNCHRONIZER_PIPE_NUM_OFFSET 5
#define LAGD_CORE_GLOBAL_CFG_2_SYNCHRONIZER_PIPE_NUM_FIELD \
  ((bitfield_field32_t) { .mask = LAGD_CORE_GLOBAL_CFG_2_SYNCHRONIZER_PIPE_NUM_MASK, .index = LAGD_CORE_GLOBAL_CFG_2_SYNCHRONIZER_PIPE_NUM_OFFSET })
#define LAGD_CORE_GLOBAL_CFG_2_DEBUG_H_WWL_BIT 7
#define LAGD_CORE_GLOBAL_CFG_2_DGT_ADDR_UPPER_BOUND_MASK 0x3f
#define LAGD_CORE_GLOBAL_CFG_2_DGT_ADDR_UPPER_BOUND_OFFSET 8
#define LAGD_CORE_GLOBAL_CFG_2_DGT_ADDR_UPPER_BOUND_FIELD \
  ((bitfield_field32_t) { .mask = LAGD_CORE_GLOBAL_CFG_2_DGT_ADDR_UPPER_BOUND_MASK, .index = LAGD_CORE_GLOBAL_CFG_2_DGT_ADDR_UPPER_BOUND_OFFSET })
#define LAGD_CORE_GLOBAL_CFG_2_CTNUS_FIFO_READ_BIT 14
#define LAGD_CORE_GLOBAL_CFG_2_CTNUS_DGT_DEBUG_BIT 15

// Registers for setting initial spin values (common parameters)
#define LAGD_CORE_CONFIG_SPIN_INITIAL_CONFIG_SPIN_INITIAL_FIELD_WIDTH 32
#define LAGD_CORE_CONFIG_SPIN_INITIAL_CONFIG_SPIN_INITIAL_FIELDS_PER_REG 1
#define LAGD_CORE_CONFIG_SPIN_INITIAL_MULTIREG_COUNT 8

// Registers for setting initial spin values
#define LAGD_CORE_CONFIG_SPIN_INITIAL_0_REG_OFFSET 0x8

// Registers for setting initial spin values
#define LAGD_CORE_CONFIG_SPIN_INITIAL_1_REG_OFFSET 0xc

// Registers for setting initial spin values
#define LAGD_CORE_CONFIG_SPIN_INITIAL_2_REG_OFFSET 0x10

// Registers for setting initial spin values
#define LAGD_CORE_CONFIG_SPIN_INITIAL_3_REG_OFFSET 0x14

// Registers for setting initial spin values
#define LAGD_CORE_CONFIG_SPIN_INITIAL_4_REG_OFFSET 0x18

// Registers for setting initial spin values
#define LAGD_CORE_CONFIG_SPIN_INITIAL_5_REG_OFFSET 0x1c

// Registers for setting initial spin values
#define LAGD_CORE_CONFIG_SPIN_INITIAL_6_REG_OFFSET 0x20

// Registers for setting initial spin values
#define LAGD_CORE_CONFIG_SPIN_INITIAL_7_REG_OFFSET 0x24

// Registers for counter configuration 1
#define LAGD_CORE_COUNTER_CFG_1_REG_OFFSET 0x28
#define LAGD_CORE_COUNTER_CFG_1_CFG_TRANS_NUM_MASK 0xffff
#define LAGD_CORE_COUNTER_CFG_1_CFG_TRANS_NUM_OFFSET 0
#define LAGD_CORE_COUNTER_CFG_1_CFG_TRANS_NUM_FIELD \
  ((bitfield_field32_t) { .mask = LAGD_CORE_COUNTER_CFG_1_CFG_TRANS_NUM_MASK, .index = LAGD_CORE_COUNTER_CFG_1_CFG_TRANS_NUM_OFFSET })
#define LAGD_CORE_COUNTER_CFG_1_CYCLE_PER_WWL_HIGH_MASK 0xffff
#define LAGD_CORE_COUNTER_CFG_1_CYCLE_PER_WWL_HIGH_OFFSET 16
#define LAGD_CORE_COUNTER_CFG_1_CYCLE_PER_WWL_HIGH_FIELD \
  ((bitfield_field32_t) { .mask = LAGD_CORE_COUNTER_CFG_1_CYCLE_PER_WWL_HIGH_MASK, .index = LAGD_CORE_COUNTER_CFG_1_CYCLE_PER_WWL_HIGH_OFFSET })

// Registers for counter configuration 2
#define LAGD_CORE_COUNTER_CFG_2_REG_OFFSET 0x2c
#define LAGD_CORE_COUNTER_CFG_2_CYCLE_PER_WWL_LOW_MASK 0xffff
#define LAGD_CORE_COUNTER_CFG_2_CYCLE_PER_WWL_LOW_OFFSET 0
#define LAGD_CORE_COUNTER_CFG_2_CYCLE_PER_WWL_LOW_FIELD \
  ((bitfield_field32_t) { .mask = LAGD_CORE_COUNTER_CFG_2_CYCLE_PER_WWL_LOW_MASK, .index = LAGD_CORE_COUNTER_CFG_2_CYCLE_PER_WWL_LOW_OFFSET })
#define LAGD_CORE_COUNTER_CFG_2_CYCLE_PER_SPIN_WRITE_MASK 0xffff
#define LAGD_CORE_COUNTER_CFG_2_CYCLE_PER_SPIN_WRITE_OFFSET 16
#define LAGD_CORE_COUNTER_CFG_2_CYCLE_PER_SPIN_WRITE_FIELD \
  ((bitfield_field32_t) { .mask = LAGD_CORE_COUNTER_CFG_2_CYCLE_PER_SPIN_WRITE_MASK, .index = LAGD_CORE_COUNTER_CFG_2_CYCLE_PER_SPIN_WRITE_OFFSET })

// Registers for counter configuration 3
#define LAGD_CORE_COUNTER_CFG_3_REG_OFFSET 0x30
#define LAGD_CORE_COUNTER_CFG_3_CYCLE_PER_SPIN_COMPUTE_MASK 0xffff
#define LAGD_CORE_COUNTER_CFG_3_CYCLE_PER_SPIN_COMPUTE_OFFSET 0
#define LAGD_CORE_COUNTER_CFG_3_CYCLE_PER_SPIN_COMPUTE_FIELD \
  ((bitfield_field32_t) { .mask = LAGD_CORE_COUNTER_CFG_3_CYCLE_PER_SPIN_COMPUTE_MASK, .index = LAGD_CORE_COUNTER_CFG_3_CYCLE_PER_SPIN_COMPUTE_OFFSET })
#define LAGD_CORE_COUNTER_CFG_3_DEBUG_CYCLE_PER_SPIN_READ_MASK 0xffff
#define LAGD_CORE_COUNTER_CFG_3_DEBUG_CYCLE_PER_SPIN_READ_OFFSET 16
#define LAGD_CORE_COUNTER_CFG_3_DEBUG_CYCLE_PER_SPIN_READ_FIELD \
  ((bitfield_field32_t) { .mask = LAGD_CORE_COUNTER_CFG_3_DEBUG_CYCLE_PER_SPIN_READ_MASK, .index = LAGD_CORE_COUNTER_CFG_3_DEBUG_CYCLE_PER_SPIN_READ_OFFSET })

// Registers for counter configuration 4
#define LAGD_CORE_COUNTER_CFG_4_REG_OFFSET 0x34
#define LAGD_CORE_COUNTER_CFG_4_DEBUG_SPIN_READ_NUM_MASK 0xffff
#define LAGD_CORE_COUNTER_CFG_4_DEBUG_SPIN_READ_NUM_OFFSET 0
#define LAGD_CORE_COUNTER_CFG_4_DEBUG_SPIN_READ_NUM_FIELD \
  ((bitfield_field32_t) { .mask = LAGD_CORE_COUNTER_CFG_4_DEBUG_SPIN_READ_NUM_MASK, .index = LAGD_CORE_COUNTER_CFG_4_DEBUG_SPIN_READ_NUM_OFFSET })
#define LAGD_CORE_COUNTER_CFG_4_ICON_LAST_RADDR_PLUS_ONE_MASK 0x7ff
#define LAGD_CORE_COUNTER_CFG_4_ICON_LAST_RADDR_PLUS_ONE_OFFSET 16
#define LAGD_CORE_COUNTER_CFG_4_ICON_LAST_RADDR_PLUS_ONE_FIELD \
  ((bitfield_field32_t) { .mask = LAGD_CORE_COUNTER_CFG_4_ICON_LAST_RADDR_PLUS_ONE_MASK, .index = LAGD_CORE_COUNTER_CFG_4_ICON_LAST_RADDR_PLUS_ONE_OFFSET })
#define LAGD_CORE_COUNTER_CFG_4_DGT_HSCALING_MASK 0x1f
#define LAGD_CORE_COUNTER_CFG_4_DGT_HSCALING_OFFSET 27
#define LAGD_CORE_COUNTER_CFG_4_DGT_HSCALING_FIELD \
  ((bitfield_field32_t) { .mask = LAGD_CORE_COUNTER_CFG_4_DGT_HSCALING_MASK, .index = LAGD_CORE_COUNTER_CFG_4_DGT_HSCALING_OFFSET })

// wwl_vdd_cfg values (common parameters)
#define LAGD_CORE_WWL_VDD_CFG_WWL_VDD_CFG_FIELD_WIDTH 32
#define LAGD_CORE_WWL_VDD_CFG_WWL_VDD_CFG_FIELDS_PER_REG 1
#define LAGD_CORE_WWL_VDD_CFG_MULTIREG_COUNT 8

// wwl_vdd_cfg values
#define LAGD_CORE_WWL_VDD_CFG_0_REG_OFFSET 0x38

// wwl_vdd_cfg values
#define LAGD_CORE_WWL_VDD_CFG_1_REG_OFFSET 0x3c

// wwl_vdd_cfg values
#define LAGD_CORE_WWL_VDD_CFG_2_REG_OFFSET 0x40

// wwl_vdd_cfg values
#define LAGD_CORE_WWL_VDD_CFG_3_REG_OFFSET 0x44

// wwl_vdd_cfg values
#define LAGD_CORE_WWL_VDD_CFG_4_REG_OFFSET 0x48

// wwl_vdd_cfg values
#define LAGD_CORE_WWL_VDD_CFG_5_REG_OFFSET 0x4c

// wwl_vdd_cfg values
#define LAGD_CORE_WWL_VDD_CFG_6_REG_OFFSET 0x50

// wwl_vdd_cfg values
#define LAGD_CORE_WWL_VDD_CFG_7_REG_OFFSET 0x54

// wwl_vread_cfg values (common parameters)
#define LAGD_CORE_WWL_VREAD_CFG_WWL_VREAD_CFG_FIELD_WIDTH 32
#define LAGD_CORE_WWL_VREAD_CFG_WWL_VREAD_CFG_FIELDS_PER_REG 1
#define LAGD_CORE_WWL_VREAD_CFG_MULTIREG_COUNT 8

// wwl_vread_cfg values
#define LAGD_CORE_WWL_VREAD_CFG_0_REG_OFFSET 0x58

// wwl_vread_cfg values
#define LAGD_CORE_WWL_VREAD_CFG_1_REG_OFFSET 0x5c

// wwl_vread_cfg values
#define LAGD_CORE_WWL_VREAD_CFG_2_REG_OFFSET 0x60

// wwl_vread_cfg values
#define LAGD_CORE_WWL_VREAD_CFG_3_REG_OFFSET 0x64

// wwl_vread_cfg values
#define LAGD_CORE_WWL_VREAD_CFG_4_REG_OFFSET 0x68

// wwl_vread_cfg values
#define LAGD_CORE_WWL_VREAD_CFG_5_REG_OFFSET 0x6c

// wwl_vread_cfg values
#define LAGD_CORE_WWL_VREAD_CFG_6_REG_OFFSET 0x70

// wwl_vread_cfg values
#define LAGD_CORE_WWL_VREAD_CFG_7_REG_OFFSET 0x74

// spin_wwl_strobe values (common parameters)
#define LAGD_CORE_SPIN_WWL_STROBE_SPIN_WWL_STROBE_FIELD_WIDTH 32
#define LAGD_CORE_SPIN_WWL_STROBE_SPIN_WWL_STROBE_FIELDS_PER_REG 1
#define LAGD_CORE_SPIN_WWL_STROBE_MULTIREG_COUNT 8

// spin_wwl_strobe values
#define LAGD_CORE_SPIN_WWL_STROBE_0_REG_OFFSET 0x78

// spin_wwl_strobe values
#define LAGD_CORE_SPIN_WWL_STROBE_1_REG_OFFSET 0x7c

// spin_wwl_strobe values
#define LAGD_CORE_SPIN_WWL_STROBE_2_REG_OFFSET 0x80

// spin_wwl_strobe values
#define LAGD_CORE_SPIN_WWL_STROBE_3_REG_OFFSET 0x84

// spin_wwl_strobe values
#define LAGD_CORE_SPIN_WWL_STROBE_4_REG_OFFSET 0x88

// spin_wwl_strobe values
#define LAGD_CORE_SPIN_WWL_STROBE_5_REG_OFFSET 0x8c

// spin_wwl_strobe values
#define LAGD_CORE_SPIN_WWL_STROBE_6_REG_OFFSET 0x90

// spin_wwl_strobe values
#define LAGD_CORE_SPIN_WWL_STROBE_7_REG_OFFSET 0x94

// spin_feedback_cfg values (common parameters)
#define LAGD_CORE_SPIN_FEEDBACK_CFG_SPIN_FEEDBACK_CFG_FIELD_WIDTH 32
#define LAGD_CORE_SPIN_FEEDBACK_CFG_SPIN_FEEDBACK_CFG_FIELDS_PER_REG 1
#define LAGD_CORE_SPIN_FEEDBACK_CFG_MULTIREG_COUNT 8

// spin_feedback_cfg values
#define LAGD_CORE_SPIN_FEEDBACK_CFG_0_REG_OFFSET 0x98

// spin_feedback_cfg values
#define LAGD_CORE_SPIN_FEEDBACK_CFG_1_REG_OFFSET 0x9c

// spin_feedback_cfg values
#define LAGD_CORE_SPIN_FEEDBACK_CFG_2_REG_OFFSET 0xa0

// spin_feedback_cfg values
#define LAGD_CORE_SPIN_FEEDBACK_CFG_3_REG_OFFSET 0xa4

// spin_feedback_cfg values
#define LAGD_CORE_SPIN_FEEDBACK_CFG_4_REG_OFFSET 0xa8

// spin_feedback_cfg values
#define LAGD_CORE_SPIN_FEEDBACK_CFG_5_REG_OFFSET 0xac

// spin_feedback_cfg values
#define LAGD_CORE_SPIN_FEEDBACK_CFG_6_REG_OFFSET 0xb0

// spin_feedback_cfg values
#define LAGD_CORE_SPIN_FEEDBACK_CFG_7_REG_OFFSET 0xb4

// h_rdata values (common parameters)
#define LAGD_CORE_H_RDATA_H_RDATA_FIELD_WIDTH 32
#define LAGD_CORE_H_RDATA_H_RDATA_FIELDS_PER_REG 1
#define LAGD_CORE_H_RDATA_MULTIREG_COUNT 32

// h_rdata values
#define LAGD_CORE_H_RDATA_0_REG_OFFSET 0xb8

// h_rdata values
#define LAGD_CORE_H_RDATA_1_REG_OFFSET 0xbc

// h_rdata values
#define LAGD_CORE_H_RDATA_2_REG_OFFSET 0xc0

// h_rdata values
#define LAGD_CORE_H_RDATA_3_REG_OFFSET 0xc4

// h_rdata values
#define LAGD_CORE_H_RDATA_4_REG_OFFSET 0xc8

// h_rdata values
#define LAGD_CORE_H_RDATA_5_REG_OFFSET 0xcc

// h_rdata values
#define LAGD_CORE_H_RDATA_6_REG_OFFSET 0xd0

// h_rdata values
#define LAGD_CORE_H_RDATA_7_REG_OFFSET 0xd4

// h_rdata values
#define LAGD_CORE_H_RDATA_8_REG_OFFSET 0xd8

// h_rdata values
#define LAGD_CORE_H_RDATA_9_REG_OFFSET 0xdc

// h_rdata values
#define LAGD_CORE_H_RDATA_10_REG_OFFSET 0xe0

// h_rdata values
#define LAGD_CORE_H_RDATA_11_REG_OFFSET 0xe4

// h_rdata values
#define LAGD_CORE_H_RDATA_12_REG_OFFSET 0xe8

// h_rdata values
#define LAGD_CORE_H_RDATA_13_REG_OFFSET 0xec

// h_rdata values
#define LAGD_CORE_H_RDATA_14_REG_OFFSET 0xf0

// h_rdata values
#define LAGD_CORE_H_RDATA_15_REG_OFFSET 0xf4

// h_rdata values
#define LAGD_CORE_H_RDATA_16_REG_OFFSET 0xf8

// h_rdata values
#define LAGD_CORE_H_RDATA_17_REG_OFFSET 0xfc

// h_rdata values
#define LAGD_CORE_H_RDATA_18_REG_OFFSET 0x100

// h_rdata values
#define LAGD_CORE_H_RDATA_19_REG_OFFSET 0x104

// h_rdata values
#define LAGD_CORE_H_RDATA_20_REG_OFFSET 0x108

// h_rdata values
#define LAGD_CORE_H_RDATA_21_REG_OFFSET 0x10c

// h_rdata values
#define LAGD_CORE_H_RDATA_22_REG_OFFSET 0x110

// h_rdata values
#define LAGD_CORE_H_RDATA_23_REG_OFFSET 0x114

// h_rdata values
#define LAGD_CORE_H_RDATA_24_REG_OFFSET 0x118

// h_rdata values
#define LAGD_CORE_H_RDATA_25_REG_OFFSET 0x11c

// h_rdata values
#define LAGD_CORE_H_RDATA_26_REG_OFFSET 0x120

// h_rdata values
#define LAGD_CORE_H_RDATA_27_REG_OFFSET 0x124

// h_rdata values
#define LAGD_CORE_H_RDATA_28_REG_OFFSET 0x128

// h_rdata values
#define LAGD_CORE_H_RDATA_29_REG_OFFSET 0x12c

// h_rdata values
#define LAGD_CORE_H_RDATA_30_REG_OFFSET 0x130

// h_rdata values
#define LAGD_CORE_H_RDATA_31_REG_OFFSET 0x134

// wbl_floating values (common parameters)
#define LAGD_CORE_WBL_FLOATING_WBL_FLOATING_FIELD_WIDTH 32
#define LAGD_CORE_WBL_FLOATING_WBL_FLOATING_FIELDS_PER_REG 1
#define LAGD_CORE_WBL_FLOATING_MULTIREG_COUNT 32

// wbl_floating values
#define LAGD_CORE_WBL_FLOATING_0_REG_OFFSET 0x138

// wbl_floating values
#define LAGD_CORE_WBL_FLOATING_1_REG_OFFSET 0x13c

// wbl_floating values
#define LAGD_CORE_WBL_FLOATING_2_REG_OFFSET 0x140

// wbl_floating values
#define LAGD_CORE_WBL_FLOATING_3_REG_OFFSET 0x144

// wbl_floating values
#define LAGD_CORE_WBL_FLOATING_4_REG_OFFSET 0x148

// wbl_floating values
#define LAGD_CORE_WBL_FLOATING_5_REG_OFFSET 0x14c

// wbl_floating values
#define LAGD_CORE_WBL_FLOATING_6_REG_OFFSET 0x150

// wbl_floating values
#define LAGD_CORE_WBL_FLOATING_7_REG_OFFSET 0x154

// wbl_floating values
#define LAGD_CORE_WBL_FLOATING_8_REG_OFFSET 0x158

// wbl_floating values
#define LAGD_CORE_WBL_FLOATING_9_REG_OFFSET 0x15c

// wbl_floating values
#define LAGD_CORE_WBL_FLOATING_10_REG_OFFSET 0x160

// wbl_floating values
#define LAGD_CORE_WBL_FLOATING_11_REG_OFFSET 0x164

// wbl_floating values
#define LAGD_CORE_WBL_FLOATING_12_REG_OFFSET 0x168

// wbl_floating values
#define LAGD_CORE_WBL_FLOATING_13_REG_OFFSET 0x16c

// wbl_floating values
#define LAGD_CORE_WBL_FLOATING_14_REG_OFFSET 0x170

// wbl_floating values
#define LAGD_CORE_WBL_FLOATING_15_REG_OFFSET 0x174

// wbl_floating values
#define LAGD_CORE_WBL_FLOATING_16_REG_OFFSET 0x178

// wbl_floating values
#define LAGD_CORE_WBL_FLOATING_17_REG_OFFSET 0x17c

// wbl_floating values
#define LAGD_CORE_WBL_FLOATING_18_REG_OFFSET 0x180

// wbl_floating values
#define LAGD_CORE_WBL_FLOATING_19_REG_OFFSET 0x184

// wbl_floating values
#define LAGD_CORE_WBL_FLOATING_20_REG_OFFSET 0x188

// wbl_floating values
#define LAGD_CORE_WBL_FLOATING_21_REG_OFFSET 0x18c

// wbl_floating values
#define LAGD_CORE_WBL_FLOATING_22_REG_OFFSET 0x190

// wbl_floating values
#define LAGD_CORE_WBL_FLOATING_23_REG_OFFSET 0x194

// wbl_floating values
#define LAGD_CORE_WBL_FLOATING_24_REG_OFFSET 0x198

// wbl_floating values
#define LAGD_CORE_WBL_FLOATING_25_REG_OFFSET 0x19c

// wbl_floating values
#define LAGD_CORE_WBL_FLOATING_26_REG_OFFSET 0x1a0

// wbl_floating values
#define LAGD_CORE_WBL_FLOATING_27_REG_OFFSET 0x1a4

// wbl_floating values
#define LAGD_CORE_WBL_FLOATING_28_REG_OFFSET 0x1a8

// wbl_floating values
#define LAGD_CORE_WBL_FLOATING_29_REG_OFFSET 0x1ac

// wbl_floating values
#define LAGD_CORE_WBL_FLOATING_30_REG_OFFSET 0x1b0

// wbl_floating values
#define LAGD_CORE_WBL_FLOATING_31_REG_OFFSET 0x1b4

// debug_j_one_hot_wwl values (common parameters)
#define LAGD_CORE_DEBUG_J_ONE_HOT_WWL_DEBUG_J_ONE_HOT_WWL_FIELD_WIDTH 32
#define LAGD_CORE_DEBUG_J_ONE_HOT_WWL_DEBUG_J_ONE_HOT_WWL_FIELDS_PER_REG 1
#define LAGD_CORE_DEBUG_J_ONE_HOT_WWL_MULTIREG_COUNT 8

// debug_j_one_hot_wwl values
#define LAGD_CORE_DEBUG_J_ONE_HOT_WWL_0_REG_OFFSET 0x1b8

// debug_j_one_hot_wwl values
#define LAGD_CORE_DEBUG_J_ONE_HOT_WWL_1_REG_OFFSET 0x1bc

// debug_j_one_hot_wwl values
#define LAGD_CORE_DEBUG_J_ONE_HOT_WWL_2_REG_OFFSET 0x1c0

// debug_j_one_hot_wwl values
#define LAGD_CORE_DEBUG_J_ONE_HOT_WWL_3_REG_OFFSET 0x1c4

// debug_j_one_hot_wwl values
#define LAGD_CORE_DEBUG_J_ONE_HOT_WWL_4_REG_OFFSET 0x1c8

// debug_j_one_hot_wwl values
#define LAGD_CORE_DEBUG_J_ONE_HOT_WWL_5_REG_OFFSET 0x1cc

// debug_j_one_hot_wwl values
#define LAGD_CORE_DEBUG_J_ONE_HOT_WWL_6_REG_OFFSET 0x1d0

// debug_j_one_hot_wwl values
#define LAGD_CORE_DEBUG_J_ONE_HOT_WWL_7_REG_OFFSET 0x1d4

// Output status signals
#define LAGD_CORE_OUTPUT_STATUS_REG_OFFSET 0x1d8
#define LAGD_CORE_OUTPUT_STATUS_DT_CFG_IDLE_BIT 0
#define LAGD_CORE_OUTPUT_STATUS_CMPT_IDLE_BIT 1
#define LAGD_CORE_OUTPUT_STATUS_ENERGY_FIFO_UPDATE_BIT 2
#define LAGD_CORE_OUTPUT_STATUS_SPIN_FIFO_UPDATE_BIT 3
#define LAGD_CORE_OUTPUT_STATUS_DEBUG_J_READ_DATA_VALID_BIT 4
#define LAGD_CORE_OUTPUT_STATUS_DEBUG_ANALOG_DT_W_IDLE_BIT 5
#define LAGD_CORE_OUTPUT_STATUS_DEBUG_ANALOG_DT_R_IDLE_BIT 6
#define LAGD_CORE_OUTPUT_STATUS_DEBUG_SPIN_W_IDLE_BIT 7
#define LAGD_CORE_OUTPUT_STATUS_DEBUG_SPIN_R_IDLE_BIT 8
#define LAGD_CORE_OUTPUT_STATUS_DEBUG_SPIN_CMPT_IDLE_BIT 9
#define LAGD_CORE_OUTPUT_STATUS_DEBUG_FM_UPSTREAM_HANDSHAKE_BIT 10
#define LAGD_CORE_OUTPUT_STATUS_DEBUG_FM_DOWNSTREAM_HANDSHAKE_BIT 11
#define LAGD_CORE_OUTPUT_STATUS_DEBUG_AW_DOWNSTREAM_HANDSHAKE_BIT 12
#define LAGD_CORE_OUTPUT_STATUS_DEBUG_EM_UPSTREAM_HANDSHAKE_BIT 13

// debug_fm_energy_input signals
#define LAGD_CORE_DEBUG_FM_ENERGY_INPUT_REG_OFFSET 0x1dc

// Registers for energy fifo data 0
#define LAGD_CORE_ENERGY_FIFO_DATA_0_REG_OFFSET 0x1e0

// Registers for energy fifo data 1
#define LAGD_CORE_ENERGY_FIFO_DATA_1_REG_OFFSET 0x1e4

// spin_fifo_data_0 values (common parameters)
#define LAGD_CORE_SPIN_FIFO_DATA_0_SPIN_FIFO_DATA_0_FIELD_WIDTH 32
#define LAGD_CORE_SPIN_FIFO_DATA_0_SPIN_FIFO_DATA_0_FIELDS_PER_REG 1
#define LAGD_CORE_SPIN_FIFO_DATA_0_MULTIREG_COUNT 8

// spin_fifo_data_0 values
#define LAGD_CORE_SPIN_FIFO_DATA_0_0_REG_OFFSET 0x1e8

// spin_fifo_data_0 values
#define LAGD_CORE_SPIN_FIFO_DATA_0_1_REG_OFFSET 0x1ec

// spin_fifo_data_0 values
#define LAGD_CORE_SPIN_FIFO_DATA_0_2_REG_OFFSET 0x1f0

// spin_fifo_data_0 values
#define LAGD_CORE_SPIN_FIFO_DATA_0_3_REG_OFFSET 0x1f4

// spin_fifo_data_0 values
#define LAGD_CORE_SPIN_FIFO_DATA_0_4_REG_OFFSET 0x1f8

// spin_fifo_data_0 values
#define LAGD_CORE_SPIN_FIFO_DATA_0_5_REG_OFFSET 0x1fc

// spin_fifo_data_0 values
#define LAGD_CORE_SPIN_FIFO_DATA_0_6_REG_OFFSET 0x200

// spin_fifo_data_0 values
#define LAGD_CORE_SPIN_FIFO_DATA_0_7_REG_OFFSET 0x204

// spin_fifo_data_1 values (common parameters)
#define LAGD_CORE_SPIN_FIFO_DATA_1_SPIN_FIFO_DATA_1_FIELD_WIDTH 32
#define LAGD_CORE_SPIN_FIFO_DATA_1_SPIN_FIFO_DATA_1_FIELDS_PER_REG 1
#define LAGD_CORE_SPIN_FIFO_DATA_1_MULTIREG_COUNT 8

// spin_fifo_data_1 values
#define LAGD_CORE_SPIN_FIFO_DATA_1_0_REG_OFFSET 0x208

// spin_fifo_data_1 values
#define LAGD_CORE_SPIN_FIFO_DATA_1_1_REG_OFFSET 0x20c

// spin_fifo_data_1 values
#define LAGD_CORE_SPIN_FIFO_DATA_1_2_REG_OFFSET 0x210

// spin_fifo_data_1 values
#define LAGD_CORE_SPIN_FIFO_DATA_1_3_REG_OFFSET 0x214

// spin_fifo_data_1 values
#define LAGD_CORE_SPIN_FIFO_DATA_1_4_REG_OFFSET 0x218

// spin_fifo_data_1 values
#define LAGD_CORE_SPIN_FIFO_DATA_1_5_REG_OFFSET 0x21c

// spin_fifo_data_1 values
#define LAGD_CORE_SPIN_FIFO_DATA_1_6_REG_OFFSET 0x220

// spin_fifo_data_1 values
#define LAGD_CORE_SPIN_FIFO_DATA_1_7_REG_OFFSET 0x224

// debug_j_read_data values (common parameters)
#define LAGD_CORE_DEBUG_J_READ_DATA_DEBUG_J_READ_DATA_FIELD_WIDTH 32
#define LAGD_CORE_DEBUG_J_READ_DATA_DEBUG_J_READ_DATA_FIELDS_PER_REG 1
#define LAGD_CORE_DEBUG_J_READ_DATA_MULTIREG_COUNT 32

// debug_j_read_data values
#define LAGD_CORE_DEBUG_J_READ_DATA_0_REG_OFFSET 0x228

// debug_j_read_data values
#define LAGD_CORE_DEBUG_J_READ_DATA_1_REG_OFFSET 0x22c

// debug_j_read_data values
#define LAGD_CORE_DEBUG_J_READ_DATA_2_REG_OFFSET 0x230

// debug_j_read_data values
#define LAGD_CORE_DEBUG_J_READ_DATA_3_REG_OFFSET 0x234

// debug_j_read_data values
#define LAGD_CORE_DEBUG_J_READ_DATA_4_REG_OFFSET 0x238

// debug_j_read_data values
#define LAGD_CORE_DEBUG_J_READ_DATA_5_REG_OFFSET 0x23c

// debug_j_read_data values
#define LAGD_CORE_DEBUG_J_READ_DATA_6_REG_OFFSET 0x240

// debug_j_read_data values
#define LAGD_CORE_DEBUG_J_READ_DATA_7_REG_OFFSET 0x244

// debug_j_read_data values
#define LAGD_CORE_DEBUG_J_READ_DATA_8_REG_OFFSET 0x248

// debug_j_read_data values
#define LAGD_CORE_DEBUG_J_READ_DATA_9_REG_OFFSET 0x24c

// debug_j_read_data values
#define LAGD_CORE_DEBUG_J_READ_DATA_10_REG_OFFSET 0x250

// debug_j_read_data values
#define LAGD_CORE_DEBUG_J_READ_DATA_11_REG_OFFSET 0x254

// debug_j_read_data values
#define LAGD_CORE_DEBUG_J_READ_DATA_12_REG_OFFSET 0x258

// debug_j_read_data values
#define LAGD_CORE_DEBUG_J_READ_DATA_13_REG_OFFSET 0x25c

// debug_j_read_data values
#define LAGD_CORE_DEBUG_J_READ_DATA_14_REG_OFFSET 0x260

// debug_j_read_data values
#define LAGD_CORE_DEBUG_J_READ_DATA_15_REG_OFFSET 0x264

// debug_j_read_data values
#define LAGD_CORE_DEBUG_J_READ_DATA_16_REG_OFFSET 0x268

// debug_j_read_data values
#define LAGD_CORE_DEBUG_J_READ_DATA_17_REG_OFFSET 0x26c

// debug_j_read_data values
#define LAGD_CORE_DEBUG_J_READ_DATA_18_REG_OFFSET 0x270

// debug_j_read_data values
#define LAGD_CORE_DEBUG_J_READ_DATA_19_REG_OFFSET 0x274

// debug_j_read_data values
#define LAGD_CORE_DEBUG_J_READ_DATA_20_REG_OFFSET 0x278

// debug_j_read_data values
#define LAGD_CORE_DEBUG_J_READ_DATA_21_REG_OFFSET 0x27c

// debug_j_read_data values
#define LAGD_CORE_DEBUG_J_READ_DATA_22_REG_OFFSET 0x280

// debug_j_read_data values
#define LAGD_CORE_DEBUG_J_READ_DATA_23_REG_OFFSET 0x284

// debug_j_read_data values
#define LAGD_CORE_DEBUG_J_READ_DATA_24_REG_OFFSET 0x288

// debug_j_read_data values
#define LAGD_CORE_DEBUG_J_READ_DATA_25_REG_OFFSET 0x28c

// debug_j_read_data values
#define LAGD_CORE_DEBUG_J_READ_DATA_26_REG_OFFSET 0x290

// debug_j_read_data values
#define LAGD_CORE_DEBUG_J_READ_DATA_27_REG_OFFSET 0x294

// debug_j_read_data values
#define LAGD_CORE_DEBUG_J_READ_DATA_28_REG_OFFSET 0x298

// debug_j_read_data values
#define LAGD_CORE_DEBUG_J_READ_DATA_29_REG_OFFSET 0x29c

// debug_j_read_data values
#define LAGD_CORE_DEBUG_J_READ_DATA_30_REG_OFFSET 0x2a0

// debug_j_read_data values
#define LAGD_CORE_DEBUG_J_READ_DATA_31_REG_OFFSET 0x2a4

// debug_fm_spin_out values (common parameters)
#define LAGD_CORE_DEBUG_FM_SPIN_OUT_DEBUG_FM_SPIN_OUT_FIELD_WIDTH 32
#define LAGD_CORE_DEBUG_FM_SPIN_OUT_DEBUG_FM_SPIN_OUT_FIELDS_PER_REG 1
#define LAGD_CORE_DEBUG_FM_SPIN_OUT_MULTIREG_COUNT 8

// debug_fm_spin_out values
#define LAGD_CORE_DEBUG_FM_SPIN_OUT_0_REG_OFFSET 0x2a8

// debug_fm_spin_out values
#define LAGD_CORE_DEBUG_FM_SPIN_OUT_1_REG_OFFSET 0x2ac

// debug_fm_spin_out values
#define LAGD_CORE_DEBUG_FM_SPIN_OUT_2_REG_OFFSET 0x2b0

// debug_fm_spin_out values
#define LAGD_CORE_DEBUG_FM_SPIN_OUT_3_REG_OFFSET 0x2b4

// debug_fm_spin_out values
#define LAGD_CORE_DEBUG_FM_SPIN_OUT_4_REG_OFFSET 0x2b8

// debug_fm_spin_out values
#define LAGD_CORE_DEBUG_FM_SPIN_OUT_5_REG_OFFSET 0x2bc

// debug_fm_spin_out values
#define LAGD_CORE_DEBUG_FM_SPIN_OUT_6_REG_OFFSET 0x2c0

// debug_fm_spin_out values
#define LAGD_CORE_DEBUG_FM_SPIN_OUT_7_REG_OFFSET 0x2c4

// debug_aw_spin_out values (common parameters)
#define LAGD_CORE_DEBUG_AW_SPIN_OUT_DEBUG_AW_SPIN_OUT_FIELD_WIDTH 32
#define LAGD_CORE_DEBUG_AW_SPIN_OUT_DEBUG_AW_SPIN_OUT_FIELDS_PER_REG 1
#define LAGD_CORE_DEBUG_AW_SPIN_OUT_MULTIREG_COUNT 8

// debug_aw_spin_out values
#define LAGD_CORE_DEBUG_AW_SPIN_OUT_0_REG_OFFSET 0x2c8

// debug_aw_spin_out values
#define LAGD_CORE_DEBUG_AW_SPIN_OUT_1_REG_OFFSET 0x2cc

// debug_aw_spin_out values
#define LAGD_CORE_DEBUG_AW_SPIN_OUT_2_REG_OFFSET 0x2d0

// debug_aw_spin_out values
#define LAGD_CORE_DEBUG_AW_SPIN_OUT_3_REG_OFFSET 0x2d4

// debug_aw_spin_out values
#define LAGD_CORE_DEBUG_AW_SPIN_OUT_4_REG_OFFSET 0x2d8

// debug_aw_spin_out values
#define LAGD_CORE_DEBUG_AW_SPIN_OUT_5_REG_OFFSET 0x2dc

// debug_aw_spin_out values
#define LAGD_CORE_DEBUG_AW_SPIN_OUT_6_REG_OFFSET 0x2e0

// debug_aw_spin_out values
#define LAGD_CORE_DEBUG_AW_SPIN_OUT_7_REG_OFFSET 0x2e4

// debug_em_spin_in values (common parameters)
#define LAGD_CORE_DEBUG_EM_SPIN_IN_DEBUG_EM_SPIN_IN_FIELD_WIDTH 32
#define LAGD_CORE_DEBUG_EM_SPIN_IN_DEBUG_EM_SPIN_IN_FIELDS_PER_REG 1
#define LAGD_CORE_DEBUG_EM_SPIN_IN_MULTIREG_COUNT 8

// debug_em_spin_in values
#define LAGD_CORE_DEBUG_EM_SPIN_IN_0_REG_OFFSET 0x2e8

// debug_em_spin_in values
#define LAGD_CORE_DEBUG_EM_SPIN_IN_1_REG_OFFSET 0x2ec

// debug_em_spin_in values
#define LAGD_CORE_DEBUG_EM_SPIN_IN_2_REG_OFFSET 0x2f0

// debug_em_spin_in values
#define LAGD_CORE_DEBUG_EM_SPIN_IN_3_REG_OFFSET 0x2f4

// debug_em_spin_in values
#define LAGD_CORE_DEBUG_EM_SPIN_IN_4_REG_OFFSET 0x2f8

// debug_em_spin_in values
#define LAGD_CORE_DEBUG_EM_SPIN_IN_5_REG_OFFSET 0x2fc

// debug_em_spin_in values
#define LAGD_CORE_DEBUG_EM_SPIN_IN_6_REG_OFFSET 0x300

// debug_em_spin_in values
#define LAGD_CORE_DEBUG_EM_SPIN_IN_7_REG_OFFSET 0x304

#ifdef __cplusplus
}  // extern "C"
#endif
#endif  // _LAGD_CORE_REG_DEFS_
// End generated register defines for lagd_core