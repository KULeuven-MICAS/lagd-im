#pragma once

#include "lagd_core.h"

typedef struct {
    // global_cfg_1: subsystem enables
    int en_aw, en_em, en_fm, en_ff, en_analog_loop, en_comparison;
    // global_cfg_1: permanent debug/perf enables (not pulsed/cleared)
    int en_perf_counter, enable_flip_detection;
    // global_cfg_1: multi-bit fields
    unsigned config_counter;            // 8 bit; hjson: "number of spins" (meaning unverified)
    unsigned synchronizer_wbl_pipe_num; // 2 bit: synchronizer depth for wbl read
    int wwl_vdd_h, wwl_vread_h;         // the h-row's +1 bit for each vector below

    // global_cfg_2
    int cmpt_en, dt_cfg_enable;
    unsigned synchronizer_pipe_num; // 2 bit
    unsigned dgt_addr_upper_bound;  // 6 bit: J address upper bound (inclusive)
    unsigned dgt_hscaling;          // 6 bit: scaling factor for dgt
    int energy_fifo_sel;

    // counter_cfg_1..4 (cycle counts unless noted)
    unsigned cfg_trans_num; // analog cfg transaction count, including h, as the last one
    unsigned cycle_per_wwl_high, cycle_per_wwl_low, cycle_per_spin_write;
    unsigned cycle_per_spin_compute, debug_cycle_per_spin_read;
    unsigned debug_spin_read_num;
    unsigned icon_last_raddr_plus_one; // flip manager's last valid address, plus one

    uint32_t cmpt_max_num; // max computation count under multi_cmpt_mode (1 means 2 computations)
    uint32_t wwl_vdd_cfg[8];   // wwl_vdd[255:0]: 1 = that row's WWL-high drives full VDD
    uint32_t wwl_vread_cfg[8]; // wwl_vread[255:0]: alternate read-voltage config, unused by dt path
} lagd_core_config_t;

// Base configuration matching the known-working bring-up (values copied from include/ref's
// lagd_reg_params.h, not re-derived). Every field is listed explicitly, including the ones that
// happen to be 0 -- see the file comment above for why.
static const lagd_core_config_t LAGD_BASE_CONFIG = {
    .en_aw = 1, .en_em = 1, .en_fm = 1, .en_ff = 1, .en_analog_loop = 1, .en_comparison = 1,
    .en_perf_counter = 1, .enable_flip_detection = 1,
    .config_counter = 0xFF, .synchronizer_wbl_pipe_num = 3, .wwl_vdd_h = 1, .wwl_vread_h = 0,

    .cmpt_en = 0, .dt_cfg_enable = 0,
    .synchronizer_pipe_num = 3, .dgt_addr_upper_bound = 0x3F,
    .dgt_hscaling = 4,
    .energy_fifo_sel = 0,

    .cfg_trans_num = 0x0040, .cycle_per_wwl_high = 0x0005, .cycle_per_wwl_low = 0x0005,
    .cycle_per_spin_write = 0x0005,
    .cycle_per_spin_compute = 0x0005, .debug_cycle_per_spin_read = 0x0005,
    .debug_spin_read_num = 0x0005, .icon_last_raddr_plus_one = 0x0400,

    .cmpt_max_num = 0x00000001,
    .wwl_vdd_cfg = {0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU,
                    0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU},
    .wwl_vread_cfg = {0x00000000U, 0x00000000U, 0x00000000U, 0x00000000U,
                      0x00000000U, 0x00000000U, 0x00000000U, 0x00000000U},
};

// The one place that knows the register/bit-position mapping for lagd_core_config_t.
static void lagd_core_apply_config(unsigned core, const lagd_core_config_t *cfg) {
    *lagd_core_reg(core, LAGD_CORE_CMPT_MAX_NUM_REG_OFFSET) = cfg->cmpt_max_num;
    lagd_core_write_vector(core, LAGD_CORE_WWL_VDD_CFG_0_REG_OFFSET, cfg->wwl_vdd_cfg, 8);
    lagd_core_write_vector(core, LAGD_CORE_WWL_VREAD_CFG_0_REG_OFFSET, cfg->wwl_vread_cfg, 8);

    *lagd_core_reg(core, LAGD_CORE_COUNTER_CFG_1_REG_OFFSET) =
        ((uint32_t)cfg->cfg_trans_num << LAGD_CORE_COUNTER_CFG_1_CFG_TRANS_NUM_OFFSET) |
        ((uint32_t)cfg->cycle_per_wwl_high << LAGD_CORE_COUNTER_CFG_1_CYCLE_PER_WWL_HIGH_OFFSET);
    *lagd_core_reg(core, LAGD_CORE_COUNTER_CFG_2_REG_OFFSET) =
        ((uint32_t)cfg->cycle_per_wwl_low << LAGD_CORE_COUNTER_CFG_2_CYCLE_PER_WWL_LOW_OFFSET) |
        ((uint32_t)cfg->cycle_per_spin_write << LAGD_CORE_COUNTER_CFG_2_CYCLE_PER_SPIN_WRITE_OFFSET);
    *lagd_core_reg(core, LAGD_CORE_COUNTER_CFG_3_REG_OFFSET) =
        ((uint32_t)cfg->cycle_per_spin_compute
         << LAGD_CORE_COUNTER_CFG_3_CYCLE_PER_SPIN_COMPUTE_OFFSET) |
        ((uint32_t)cfg->debug_cycle_per_spin_read
         << LAGD_CORE_COUNTER_CFG_3_DEBUG_CYCLE_PER_SPIN_READ_OFFSET);
    *lagd_core_reg(core, LAGD_CORE_COUNTER_CFG_4_REG_OFFSET) =
        ((uint32_t)cfg->debug_spin_read_num << LAGD_CORE_COUNTER_CFG_4_DEBUG_SPIN_READ_NUM_OFFSET) |
        ((uint32_t)cfg->icon_last_raddr_plus_one
         << LAGD_CORE_COUNTER_CFG_4_ICON_LAST_RADDR_PLUS_ONE_OFFSET);

    *lagd_core_reg(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET) =
        ((uint32_t)cfg->en_aw << LAGD_CORE_GLOBAL_CFG_1_EN_AW_BIT) |
        ((uint32_t)cfg->en_em << LAGD_CORE_GLOBAL_CFG_1_EN_EM_BIT) |
        ((uint32_t)cfg->en_fm << LAGD_CORE_GLOBAL_CFG_1_EN_FM_BIT) |
        ((uint32_t)cfg->en_ff << LAGD_CORE_GLOBAL_CFG_1_EN_FF_BIT) |
        ((uint32_t)cfg->en_analog_loop << LAGD_CORE_GLOBAL_CFG_1_EN_ANALOG_LOOP_BIT) |
        ((uint32_t)cfg->en_comparison << LAGD_CORE_GLOBAL_CFG_1_EN_COMPARISON_BIT) |
        (1u << LAGD_CORE_GLOBAL_CFG_1_DEBUG_DT_CONFIGURE_ENABLE_BIT) |   // one-shot pulse,
        (1u << LAGD_CORE_GLOBAL_CFG_1_DEBUG_SPIN_CONFIGURE_ENABLE_BIT) | // cleared below
        ((uint32_t)cfg->en_perf_counter << LAGD_CORE_GLOBAL_CFG_1_EN_PERF_COUNTER_BIT) |
        ((uint32_t)cfg->enable_flip_detection << LAGD_CORE_GLOBAL_CFG_1_ENABLE_FLIP_DETECTION_BIT) |
        ((uint32_t)cfg->config_counter << LAGD_CORE_GLOBAL_CFG_1_CONFIG_COUNTER_OFFSET) |
        ((uint32_t)cfg->wwl_vdd_h << LAGD_CORE_GLOBAL_CFG_1_WWL_VDD_CFG_256_BIT) |
        ((uint32_t)cfg->wwl_vread_h << LAGD_CORE_GLOBAL_CFG_1_WWL_VREAD_CFG_256_BIT) |
        ((uint32_t)cfg->synchronizer_wbl_pipe_num
         << LAGD_CORE_GLOBAL_CFG_1_SYNCHRONIZER_WBL_PIPE_NUM_OFFSET);

    *lagd_core_reg(core, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET) =
        ((uint32_t)cfg->cmpt_en << LAGD_CORE_GLOBAL_CFG_2_CMPT_EN_BIT) |
        (1u << LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_AW_BIT) | // one-shot pulse,
        (1u << LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_EM_BIT) | // cleared below
        (1u << LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_FM_BIT) |
        ((uint32_t)cfg->dt_cfg_enable << LAGD_CORE_GLOBAL_CFG_2_DT_CFG_ENABLE_BIT) |
        ((uint32_t)cfg->synchronizer_pipe_num << LAGD_CORE_GLOBAL_CFG_2_SYNCHRONIZER_PIPE_NUM_OFFSET) |
        ((uint32_t)cfg->dgt_addr_upper_bound << LAGD_CORE_GLOBAL_CFG_2_DGT_ADDR_UPPER_BOUND_OFFSET) |
        ((uint32_t)cfg->dgt_hscaling << LAGD_CORE_GLOBAL_CFG_2_DGT_HSCALING_OFFSET) |
        ((uint32_t)cfg->energy_fifo_sel << LAGD_CORE_GLOBAL_CFG_2_ENERGY_FIFO_SEL_BIT);

    lagd_core_clear_bit(core, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET, LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_AW_BIT);
    lagd_core_clear_bit(core, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET, LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_EM_BIT);
    lagd_core_clear_bit(core, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET, LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_FM_BIT);
    lagd_core_clear_bit(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET, LAGD_CORE_GLOBAL_CFG_1_DEBUG_DT_CONFIGURE_ENABLE_BIT);
    lagd_core_clear_bit(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET, LAGD_CORE_GLOBAL_CFG_1_DEBUG_SPIN_CONFIGURE_ENABLE_BIT);
}
