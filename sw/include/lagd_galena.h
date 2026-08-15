#pragma once

#include "lagd_core.h"

// 1024-bit wbl/wblb/wbl_floating vectors -> 32 32-bit words.
#define LAGD_WBL_NUM_WORDS (NUM_SPIN * BIT_H / 32)
// 256-bit wwl[255:0] vector -> 8 32-bit words (the 257th bit, the "h row", is addressed separately through global_cfg_2.debug_h_wwl)
#define LAGD_WWL_NUM_WORDS (NUM_SPIN / 32)

// --- Stage (level) -----------------------------------------------------------------------------

// Load a full 1024-bit WBL pattern
static void galena_stage_wbl_pattern(unsigned core, const uint32_t pattern[LAGD_WBL_NUM_WORDS]) {
    lagd_core_write_vector(core, LAGD_CORE_DEBUG_WBL_CONFIG_0_REG_OFFSET, pattern, LAGD_WBL_NUM_WORDS);
}

// Load the wbl_floating mask, all-driven or all-floating across the whole array.
// Active-low (driven=1 drives every WBL/WBLB column, driven=0 floats them all)
static void galena_stage_wbl_floating(unsigned core, int driven) {
    uint32_t pattern[LAGD_WBL_NUM_WORDS];
    for (unsigned i = 0; i < LAGD_WBL_NUM_WORDS; i++) pattern[i] = driven ? 0xFFFFFFFFu : 0x00000000u;
    lagd_core_write_vector(core, LAGD_CORE_WBL_FLOATING_0_REG_OFFSET, pattern, LAGD_WBL_NUM_WORDS);
}

// Stage a WWL pattern
static void galena_stage_wwl_pattern(unsigned core, const uint32_t pattern[LAGD_WWL_NUM_WORDS], int h_row) {
    lagd_core_write_vector(core, LAGD_CORE_DEBUG_J_ONE_HOT_WWL_0_REG_OFFSET, pattern, LAGD_WWL_NUM_WORDS);
    if (h_row) lagd_core_set_bit(core, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET, LAGD_CORE_GLOBAL_CFG_2_DEBUG_H_WWL_BIT);
    else       lagd_core_clear_bit(core, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET, LAGD_CORE_GLOBAL_CFG_2_DEBUG_H_WWL_BIT);
}

// Convenience: select exactly one WWL row (0..255 = j rows, 256 = the h row)
static void galena_select_wwl_row(unsigned core, unsigned row) {
    uint32_t pattern[LAGD_WWL_NUM_WORDS] = {0};
    if (row < NUM_SPIN) pattern[row / 32] |= (1u << (row % 32));
    galena_stage_wwl_pattern(core, pattern, row >= NUM_SPIN);
}

// Stage wwl_vdd: which WWL lines drive full VDD during a write.
// IMPORTANT: wwl_vdd and wwl_vread cannot be both 1 at the same time (will kill the chip).
//            Therefore one must ensure that the WWL_VREAD pins are zero before triggering this.
//            You can use galena_switch_wwl_supply for a safe implementation!
static void galena_stage_wwl_vdd(unsigned core, int active) {
    uint32_t pattern[LAGD_WWL_NUM_WORDS];
    for (unsigned i = 0; i < LAGD_WWL_NUM_WORDS; i++) pattern[i] = active ? 0xFFFFFFFFu : 0x00000000u;
    lagd_core_write_vector(core, LAGD_CORE_WWL_VDD_CFG_0_REG_OFFSET, pattern, LAGD_WWL_NUM_WORDS);
    if (active) lagd_core_set_bit(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET, LAGD_CORE_GLOBAL_CFG_1_WWL_VDD_CFG_256_BIT);
    else        lagd_core_clear_bit(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET, LAGD_CORE_GLOBAL_CFG_1_WWL_VDD_CFG_256_BIT);
}

// Stage wwl_vread: which WWL lines are driven with VREAD. Backup for stopping destructive VDD-reads.
// IMPORTANT: wwl_vdd and wwl_vread cannot be both 1 at the same time (will kill the chip).
//            Therefore one must ensure that the WWL_VDD pins are zero before triggering this.
//            You can use galena_switch_wwl_supply for a safe implementation!
static void galena_stage_wwl_vread(unsigned core, int active) {
    uint32_t pattern[LAGD_WWL_NUM_WORDS];
    for (unsigned i = 0; i < LAGD_WWL_NUM_WORDS; i++) pattern[i] = active ? 0xFFFFFFFFu : 0x00000000u;
    lagd_core_write_vector(core, LAGD_CORE_WWL_VREAD_CFG_0_REG_OFFSET, pattern, LAGD_WWL_NUM_WORDS);
    if (active) lagd_core_set_bit(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET, LAGD_CORE_GLOBAL_CFG_1_WWL_VREAD_CFG_256_BIT);
    else        lagd_core_clear_bit(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET, LAGD_CORE_GLOBAL_CFG_1_WWL_VREAD_CFG_256_BIT);
}

// Load the wwl-high/wwl-low phase counter targets (in clock cycles) that time a dt write/read pulse
static void galena_stage_wwl_timing(unsigned core, unsigned cycle_per_wwl_high, unsigned cycle_per_wwl_low) {
    lagd_core_write_field(core, LAGD_CORE_COUNTER_CFG_1_REG_OFFSET,
                           LAGD_CORE_COUNTER_CFG_1_CYCLE_PER_WWL_HIGH_MASK,
                           LAGD_CORE_COUNTER_CFG_1_CYCLE_PER_WWL_HIGH_OFFSET, cycle_per_wwl_high);
    lagd_core_write_field(core, LAGD_CORE_COUNTER_CFG_2_REG_OFFSET,
                           LAGD_CORE_COUNTER_CFG_2_CYCLE_PER_WWL_LOW_MASK,
                           LAGD_CORE_COUNTER_CFG_2_CYCLE_PER_WWL_LOW_OFFSET, cycle_per_wwl_low);
}

// Load the WBL-read synchronizer's pipe depth
static void galena_stage_wbl_sync_depth(unsigned core, unsigned pipe_num) {
    lagd_core_write_field(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET,
                           LAGD_CORE_GLOBAL_CFG_1_SYNCHRONIZER_WBL_PIPE_NUM_MASK,
                           LAGD_CORE_GLOBAL_CFG_1_SYNCHRONIZER_WBL_PIPE_NUM_OFFSET, pipe_num);
}

// --- Commit --------------------------------------------------------------------------------

// Commit (level): latch currently staged:
//     -WBL pattern
//     -wwl_vdd/vread's
//     -the WBL-synchronizer pipe depth
static void galena_commit_dt_configure(unsigned core) {
    lagd_core_set_bit(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET, LAGD_CORE_GLOBAL_CFG_1_DEBUG_DT_CONFIGURE_ENABLE_BIT);
    lagd_core_clear_bit(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET, LAGD_CORE_GLOBAL_CFG_1_DEBUG_DT_CONFIGURE_ENABLE_BIT);
}

// Commit (posedge): run a timed WBL/WWL write pulse from the staged pattern.
static void galena_commit_dt_write(unsigned core) {
    lagd_core_set_bit(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET, LAGD_CORE_GLOBAL_CFG_1_DEBUG_J_WRITE_EN_BIT);
    lagd_core_clear_bit(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET, LAGD_CORE_GLOBAL_CFG_1_DEBUG_J_WRITE_EN_BIT);
}

// Commit (posedge): run a timed WBL/WWL read pulse, capturing into debug_wbl_read_data/_wblb.
static void galena_commit_dt_read(unsigned core) {
    lagd_core_set_bit(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET, LAGD_CORE_GLOBAL_CFG_1_DEBUG_J_READ_EN_BIT);
    lagd_core_clear_bit(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET, LAGD_CORE_GLOBAL_CFG_1_DEBUG_J_READ_EN_BIT);
}

// --- Poll ------------------------------------------------------------------------------------

static void galena_poll_dt_write_idle(unsigned core) {
    lagd_core_poll_bit(core, LAGD_CORE_OUTPUT_STATUS_REG_OFFSET, LAGD_CORE_OUTPUT_STATUS_DEBUG_ANALOG_DT_W_IDLE_BIT, 1);
}

static void galena_poll_dt_read_idle(unsigned core) {
    lagd_core_poll_bit(core, LAGD_CORE_OUTPUT_STATUS_REG_OFFSET, LAGD_CORE_OUTPUT_STATUS_DEBUG_ANALOG_DT_R_IDLE_BIT, 1);
}

static void galena_poll_dt_read_valid(unsigned core) {
    lagd_core_poll_bit(core, LAGD_CORE_OUTPUT_STATUS_REG_OFFSET, LAGD_CORE_OUTPUT_STATUS_DEBUG_WBL_READ_DATA_VALID_BIT, 1);
}

// --- Read back -------------------------------------------------------------------------------

static void galena_read_wbl(unsigned core, uint32_t out[LAGD_WBL_NUM_WORDS]) {
    lagd_core_read_vector(core, LAGD_CORE_DEBUG_WBL_READ_DATA_0_REG_OFFSET, out, LAGD_WBL_NUM_WORDS);
}

static void galena_read_wblb(unsigned core, uint32_t out[LAGD_WBL_NUM_WORDS]) {
    lagd_core_read_vector(core, LAGD_CORE_DEBUG_WBLB_READ_DATA_0_REG_OFFSET, out, LAGD_WBL_NUM_WORDS);
}
