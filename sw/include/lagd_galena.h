#pragma once

#include "lagd_core.h"

// 1024-bit wbl/wblb/wbl_floating vectors -> 32 32-bit words.
#define LAGD_WBL_NUM_WORDS (NUM_SPIN * BIT_H / 32)
// 256-bit wwl[255:0] vector -> 8 32-bit words (the 257th bit, the "h row", is addressed separately
// through global_cfg_2.debug_h_wwl)
#define LAGD_WWL_NUM_WORDS (NUM_SPIN / 32)
// 256-bit spin vectors (one bit per spin) -> 8 32-bit words
#define LAGD_SPIN_NUM_WORDS (NUM_SPIN / 32)

// --- Stage WBL ---------------------------------------------------------------

// Load a full 1024-bit WBL pattern
static void galena_stage_wbl_pattern(unsigned core, const uint32_t pattern[LAGD_WBL_NUM_WORDS]) {
    lagd_core_write_vector(core, LAGD_CORE_DEBUG_WBL_CONFIG_0_REG_OFFSET, pattern,
                           LAGD_WBL_NUM_WORDS);
}

// Convenience: build and stage the WBL vector for a spin write from a 256-bit spin pattern.
static void galena_stage_wbl_spins(unsigned core, const uint32_t spins[LAGD_SPIN_NUM_WORDS]) {
    uint32_t wbl[LAGD_WBL_NUM_WORDS] = {0};
    for (unsigned i = 0; i < NUM_SPIN; i++) {
        if ((spins[i / 32] >> (i % 32)) & 1u) {
            unsigned bit = BIT_H * i + SPIN_WBL_OFFSET;
            wbl[bit / 32] |= (1u << (bit % 32));
        }
    }
    galena_stage_wbl_pattern(core, wbl);
}

// Load the wbl_floating mask, all-driven or all-floating across the whole array.
// Active-low (driven=1 drives every WBL/WBLB column, driven=0 floats them all)
static void galena_stage_wbl_floating(unsigned core, int driven) {
    uint32_t pattern[LAGD_WBL_NUM_WORDS];
    for (unsigned i = 0; i < LAGD_WBL_NUM_WORDS; i++)
        pattern[i] = driven ? 0xFFFFFFFFu : 0x00000000u;
    lagd_core_write_vector(core, LAGD_CORE_WBL_FLOATING_0_REG_OFFSET, pattern, LAGD_WBL_NUM_WORDS);
}

// --- Stage WWL ---------------------------------------------------------------

// Stage a WWL pattern
static void galena_stage_wwl_pattern(unsigned core, const uint32_t pattern[LAGD_WWL_NUM_WORDS],
                                     int h_row) {
    lagd_core_write_vector(core, LAGD_CORE_DEBUG_J_ONE_HOT_WWL_0_REG_OFFSET, pattern,
                           LAGD_WWL_NUM_WORDS);
    if (h_row)
        lagd_core_set_bit(core, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET,
                          LAGD_CORE_GLOBAL_CFG_2_DEBUG_H_WWL_BIT);
    else
        lagd_core_clear_bit(core, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET,
                            LAGD_CORE_GLOBAL_CFG_2_DEBUG_H_WWL_BIT);
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
    for (unsigned i = 0; i < LAGD_WWL_NUM_WORDS; i++)
        pattern[i] = active ? 0xFFFFFFFFu : 0x00000000u;
    lagd_core_write_vector(core, LAGD_CORE_WWL_VDD_CFG_0_REG_OFFSET, pattern, LAGD_WWL_NUM_WORDS);
    if (active)
        lagd_core_set_bit(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET,
                          LAGD_CORE_GLOBAL_CFG_1_WWL_VDD_CFG_256_BIT);
    else
        lagd_core_clear_bit(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET,
                            LAGD_CORE_GLOBAL_CFG_1_WWL_VDD_CFG_256_BIT);
}

// Stage wwl_vread: which WWL lines are driven with VREAD. Backup for stopping destructive
// VDD-reads. IMPORTANT: wwl_vdd and wwl_vread cannot be both 1 at the same time (will kill the
// chip).
//            Therefore one must ensure that the WWL_VDD pins are zero before triggering this.
//            You can use galena_switch_wwl_supply for a safe implementation!
static void galena_stage_wwl_vread(unsigned core, int active) {
    uint32_t pattern[LAGD_WWL_NUM_WORDS];
    for (unsigned i = 0; i < LAGD_WWL_NUM_WORDS; i++)
        pattern[i] = active ? 0xFFFFFFFFu : 0x00000000u;
    lagd_core_write_vector(core, LAGD_CORE_WWL_VREAD_CFG_0_REG_OFFSET, pattern, LAGD_WWL_NUM_WORDS);
    if (active)
        lagd_core_set_bit(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET,
                          LAGD_CORE_GLOBAL_CFG_1_WWL_VREAD_CFG_256_BIT);
    else
        lagd_core_clear_bit(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET,
                            LAGD_CORE_GLOBAL_CFG_1_WWL_VREAD_CFG_256_BIT);
}

// --- Stage spin lines --------------------------------------------------------

// Stage the spin word lines.
static void galena_stage_spin_wwl(unsigned core, int active) {
    uint32_t pattern[LAGD_SPIN_NUM_WORDS];
    for (unsigned i = 0; i < LAGD_SPIN_NUM_WORDS; i++)
        pattern[i] = active ? 0xFFFFFFFFu : 0x00000000u;
    lagd_core_write_vector(core, LAGD_CORE_SPIN_WWL_STROBE_0_REG_OFFSET, pattern,
                           LAGD_SPIN_NUM_WORDS);
}

// Stage the spin feedback lines. (high: feedback is ON, low: internal spin bit on BCT)
static void galena_stage_spin_feedback(unsigned core, int active) {
    uint32_t pattern[LAGD_SPIN_NUM_WORDS];
    for (unsigned i = 0; i < LAGD_SPIN_NUM_WORDS; i++)
        pattern[i] = active ? 0xFFFFFFFFu : 0x00000000u;
    lagd_core_write_vector(core, LAGD_CORE_SPIN_FEEDBACK_CFG_0_REG_OFFSET, pattern,
                           LAGD_SPIN_NUM_WORDS);
}

// --- Stage properties --------------------------------------------------------

// Load the wwl-high/wwl-low phase counter targets (in clock cycles) that time a dt write/read pulse
static void galena_stage_wwl_timing(unsigned core, unsigned cycle_per_wwl_high,
                                    unsigned cycle_per_wwl_low) {
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

// Load the bct_read_o synchronizer's pipe depth.
static void galena_stage_spin_sync_depth(unsigned core, unsigned pipe_num) {
    lagd_core_write_field(core, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET,
                          LAGD_CORE_GLOBAL_CFG_2_SYNCHRONIZER_PIPE_NUM_MASK,
                          LAGD_CORE_GLOBAL_CFG_2_SYNCHRONIZER_PIPE_NUM_OFFSET, pipe_num);
}

// Load the spin write pulse width.
static void galena_stage_spin_write_timing(unsigned core, unsigned cycle_per_spin_write) {
    lagd_core_write_field(
        core, LAGD_CORE_COUNTER_CFG_2_REG_OFFSET, LAGD_CORE_COUNTER_CFG_2_CYCLE_PER_SPIN_WRITE_MASK,
        LAGD_CORE_COUNTER_CFG_2_CYCLE_PER_SPIN_WRITE_OFFSET, cycle_per_spin_write);
}

// Load the feedback pulse width used by galena_trigger_feedback_pulse, in clock cycles.
static void galena_stage_feedback_pulse_timing(unsigned core, unsigned cycle_per_spin_compute) {
    lagd_core_write_field(core, LAGD_CORE_COUNTER_CFG_3_REG_OFFSET,
                          LAGD_CORE_COUNTER_CFG_3_CYCLE_PER_SPIN_COMPUTE_MASK,
                          LAGD_CORE_COUNTER_CFG_3_CYCLE_PER_SPIN_COMPUTE_OFFSET,
                          cycle_per_spin_compute);
}

// Load the sequenced spin readout's per-sample cycle count and sample count.
static void galena_stage_spin_read_timing(unsigned core, unsigned cycle_per_spin_read,
                                          unsigned read_num) {
    lagd_core_write_field(core, LAGD_CORE_COUNTER_CFG_3_REG_OFFSET,
                          LAGD_CORE_COUNTER_CFG_3_DEBUG_CYCLE_PER_SPIN_READ_MASK,
                          LAGD_CORE_COUNTER_CFG_3_DEBUG_CYCLE_PER_SPIN_READ_OFFSET,
                          cycle_per_spin_read);
    lagd_core_write_field(core, LAGD_CORE_COUNTER_CFG_4_REG_OFFSET,
                          LAGD_CORE_COUNTER_CFG_4_DEBUG_SPIN_READ_NUM_MASK,
                          LAGD_CORE_COUNTER_CFG_4_DEBUG_SPIN_READ_NUM_OFFSET, read_num);
}

// --- Commit ------------------------------------------------------------------

// Latch currently staged:
//     -WBL pattern
//     -wwl_vdd/vread's
//     -the WBL-synchronizer pipe depth
static void galena_commit_dt_configure(unsigned core) {
    lagd_core_set_bit(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET,
                      LAGD_CORE_GLOBAL_CFG_1_DEBUG_DT_CONFIGURE_ENABLE_BIT);
    lagd_core_clear_bit(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET,
                        LAGD_CORE_GLOBAL_CFG_1_DEBUG_DT_CONFIGURE_ENABLE_BIT);
}

// Latch currently staged:
//     -WBL pattern (spin data + enable lines)
//     -spin word lines
//     -spin feedback lines
//     -spin write / read pulse widths and the read sample count
static void galena_commit_spin_configure(unsigned core) {
    lagd_core_set_bit(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET,
                      LAGD_CORE_GLOBAL_CFG_1_DEBUG_SPIN_CONFIGURE_ENABLE_BIT);
    lagd_core_clear_bit(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET,
                        LAGD_CORE_GLOBAL_CFG_1_DEBUG_SPIN_CONFIGURE_ENABLE_BIT);
}

// Latch currently staged:
//     -the bct_read_o synchronizer pipe depth
static void galena_commit_aw_configure(unsigned core) {
    lagd_core_set_bit(core, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET,
                      LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_AW_BIT);
    lagd_core_clear_bit(core, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET,
                        LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_AW_BIT);
}

// --- Trigger -----------------------------------------------------------------

// Run a timed WBL/WWL write pulse using currently committed:
//     -WBL pattern
//     -WWL row selection
//     -cycle_per_wwl_high as the pulse width
static void galena_trigger_dt_write(unsigned core) {
    lagd_core_set_bit(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET,
                      LAGD_CORE_GLOBAL_CFG_1_DEBUG_J_WRITE_EN_BIT);
    lagd_core_clear_bit(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET,
                        LAGD_CORE_GLOBAL_CFG_1_DEBUG_J_WRITE_EN_BIT);
}

// Run a timed WBL/WWL read pulse using currently committed:
//     -WWL row selection
//     -cycle_per_wwl_low as the pulse width
//     -captures into debug_wbl_read_data/_wblb; poll the sticky idle bit, not the missable valid
//     pulse
static void galena_trigger_dt_read(unsigned core) {
    lagd_core_set_bit(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET,
                      LAGD_CORE_GLOBAL_CFG_1_DEBUG_J_READ_EN_BIT);
    lagd_core_clear_bit(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET,
                        LAGD_CORE_GLOBAL_CFG_1_DEBUG_J_READ_EN_BIT);
}

// Run a timed spin write using currently committed:
//     -WBL spin pattern
//     -spin word lines
//     -cycle_per_spin_write as the pulse width
static void galena_trigger_spin_write(unsigned core) {
    lagd_core_set_bit(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET,
                      LAGD_CORE_GLOBAL_CFG_1_DEBUG_SPIN_WRITE_EN_BIT);
    lagd_core_clear_bit(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET,
                        LAGD_CORE_GLOBAL_CFG_1_DEBUG_SPIN_WRITE_EN_BIT);
}

// Run a sequenced spin read using currently committed:
//     -read_num samples at cycle_per_read cadence
//     -feedback pattern, driven for the whole burst if staged on
//     -every sample is written into L1 flip memory unconditionally, regardless of read_num
static void galena_trigger_spin_read(unsigned core) {
    lagd_core_set_bit(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET,
                      LAGD_CORE_GLOBAL_CFG_1_DEBUG_SPIN_READ_EN_BIT);
    lagd_core_clear_bit(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET,
                        LAGD_CORE_GLOBAL_CFG_1_DEBUG_SPIN_READ_EN_BIT);
}

// Drive the staged feedback pattern for cycle_per_spin_compute cycles, then stop.
// IMPORTANT: this does not let you read the resulting spin values. Nothing captures or persists the
//            result, and bct_read_o reverts to the originally written spin the instant feedback
//            deasserts. To actually observe a convergence, use galena_trigger_spin_read with
//            feedback staged on instead.
static void galena_trigger_feedback_pulse(unsigned core) {
    lagd_core_set_bit(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET,
                      LAGD_CORE_GLOBAL_CFG_1_DEBUG_SPIN_COMPUTE_EN_BIT);
    lagd_core_clear_bit(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET,
                        LAGD_CORE_GLOBAL_CFG_1_DEBUG_SPIN_COMPUTE_EN_BIT);
}

// --- Poll ------------------------------------------------------------------------------------

static void galena_poll_dt_write_idle(unsigned core) {
    lagd_core_poll_bit(core, LAGD_CORE_OUTPUT_STATUS_REG_OFFSET,
                       LAGD_CORE_OUTPUT_STATUS_DEBUG_ANALOG_DT_W_IDLE_BIT, 1);
}

static void galena_poll_dt_read_idle(unsigned core) {
    lagd_core_poll_bit(core, LAGD_CORE_OUTPUT_STATUS_REG_OFFSET,
                       LAGD_CORE_OUTPUT_STATUS_DEBUG_ANALOG_DT_R_IDLE_BIT, 1);
}

static void galena_poll_dt_read_valid(unsigned core) {
    lagd_core_poll_bit(core, LAGD_CORE_OUTPUT_STATUS_REG_OFFSET,
                       LAGD_CORE_OUTPUT_STATUS_DEBUG_WBL_READ_DATA_VALID_BIT, 1);
}

static void galena_poll_spin_write_idle(unsigned core) {
    lagd_core_poll_bit(core, LAGD_CORE_OUTPUT_STATUS_REG_OFFSET,
                       LAGD_CORE_OUTPUT_STATUS_DEBUG_SPIN_W_IDLE_BIT, 1);
}

static void galena_poll_feedback_pulse_idle(unsigned core) {
    lagd_core_poll_bit(core, LAGD_CORE_OUTPUT_STATUS_REG_OFFSET,
                       LAGD_CORE_OUTPUT_STATUS_DEBUG_SPIN_CMPT_IDLE_BIT, 1);
}

static void galena_poll_spin_read_idle(unsigned core) {
    lagd_core_poll_bit(core, LAGD_CORE_OUTPUT_STATUS_REG_OFFSET,
                       LAGD_CORE_OUTPUT_STATUS_DEBUG_SPIN_R_IDLE_BIT, 1);
}

// --- Read back -------------------------------------------------------------------------------

static void galena_read_wbl(unsigned core, uint32_t out[LAGD_WBL_NUM_WORDS]) {
    lagd_core_read_vector(core, LAGD_CORE_DEBUG_WBL_READ_DATA_0_REG_OFFSET, out,
                          LAGD_WBL_NUM_WORDS);
}

static void galena_read_wblb(unsigned core, uint32_t out[LAGD_WBL_NUM_WORDS]) {
    lagd_core_read_vector(core, LAGD_CORE_DEBUG_WBLB_READ_DATA_0_REG_OFFSET, out,
                          LAGD_WBL_NUM_WORDS);
}

// Mirror internal spin_out onto the CSR registers.
static void galena_enable_spin_out(unsigned core, int enable) {
    if (enable)
        lagd_core_set_bit(core, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET,
                          LAGD_CORE_GLOBAL_CFG_2_CTNUS_DGT_DEBUG_BIT);
    else
        lagd_core_clear_bit(core, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET,
                            LAGD_CORE_GLOBAL_CFG_2_CTNUS_DGT_DEBUG_BIT);
}

static void galena_read_spin_out(unsigned core, uint32_t out[LAGD_SPIN_NUM_WORDS]) {
    lagd_core_read_vector(core, LAGD_CORE_DEBUG_AW_SPIN_OUT_0_REG_OFFSET, out, LAGD_SPIN_NUM_WORDS);
}

static void galena_read_spin_flip_mem(unsigned core, unsigned index,
                                      uint32_t out[LAGD_SPIN_NUM_WORDS]) {
    volatile uint32_t *base =
        (volatile uint32_t *)(IC_J_MEM_END_ADDR +
                              (uintptr_t)core * (L1_J_MEM_SIZE_B + L1_FLIP_MEM_SIZE_B));
    for (unsigned i = 0; i < LAGD_SPIN_NUM_WORDS; i++)
        out[i] = base[index * LAGD_SPIN_NUM_WORDS + i];
}
