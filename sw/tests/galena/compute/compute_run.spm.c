// Copyright 2026 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Toon Bettens <toon.bettens@kuleuven.be>

// One non-debug compute run. Writes every register itself rather than including
// include/ref/lagd_reg_params.h, so the configuration the chip gets is visible here; the defaults
// below match the debug scenarios that work on this die (scenarios/ising_block.spm.c).
//
//   make tests/galena/compute/compute_run.spm.elf DATA_FOLDER=<folder> COMPILE_ARGS="CORE_TESTED=1"
//
// Problem data comes from tests/ref/data/$(DATA_FOLDER) via include/gen/, as scompute's does.
//
// Where this path differs from the debug path:
//  - Pulse widths default to 100 cycles, not reg_params' 5 (analog_cfg.sv, analog_rx.sv).
//  - J/H must be two's complement: analog_cfg.sv converts in wbl_comb_in_analog_format. The debug
//    path wants sign-magnitude instead. Generated headers are already two's complement; do not
//    pre-encode them, and leave BYPASS_DATA_CONVERSION at 0.
//  - wbl_floating only latches on debug_dt_configure_enable_i (analog_macro_wrap.sv:189), so it is
//    written driven here and the debug configure bit pulsed purely to latch it.
//  - Spin write and feedback are one chained sequence off a single pop (analog_rx.sv), not three
//    software-separated phases. WBLB is driven differentially here where analog_spin_debug.sv:97
//    ties it to 0, and wbl_o holds the popped vector into the feedback phase (analog_rx.sv:66).
//    Feedback also rises on the same edge the write strobe falls, with no recovery gap.
//  - The capture fires on cmpt_counter_maxed, the last cycle feedback is asserted, so settling
//    margin comes entirely from CFG_CYCLE_PER_SPIN_COMPUTE (16-bit) or a lower SoC clock.
//  - EN_COMPARISON must stay 0: energy_fifo_maintainer.sv drops non-improving results without
//    writing them, leaving the spin FIFO on an older vector.
//
// Flipping stays enabled with an all-zero icon mask, so the run lasts
// ICON_LAST_RADDR_PLUS_ONE iterations (1 here) and applies no flips.

#ifndef CORE_TESTED
#define CORE_TESTED 0
#endif

// --- pulse timing: matched to the working debug scenarios --------
#ifndef CFG_CYCLE_PER_WWL_HIGH
#define CFG_CYCLE_PER_WWL_HIGH 100
#endif
#ifndef CFG_CYCLE_PER_WWL_LOW
#define CFG_CYCLE_PER_WWL_LOW 100
#endif
#ifndef CFG_CYCLE_PER_SPIN_WRITE
#define CFG_CYCLE_PER_SPIN_WRITE 100
#endif
// Feedback window before the capture. The equivalent debug window is cycle_per_spin_read *
// spin_read_num, i.e. 5 in the working scenarios -- but the debug capture sits inside
// its window while this one sits on its last cycle, so there is no margin here and the array must
// be fully settled by then. Defaulted well above the debug equivalent for that reason; sweep first.
#ifndef CFG_CYCLE_PER_SPIN_COMPUTE
#define CFG_CYCLE_PER_SPIN_COMPUTE 100
#endif
// Analog cfg transactions: the address counter runs 0..CFG_TRANS_NUM_, J occupies 0..HADDR-1 and
// the h row is the last one at HADDR == NUM_SPIN/PARALLELISM == 64. So this must be exactly 64.
#ifndef CFG_TRANS_NUM_
#define CFG_TRANS_NUM_ 64
#endif

// --- run shape --------------------------------------------------------------
#ifndef CFG_FLIP_DISABLE
#define CFG_FLIP_DISABLE 0
#endif
#ifndef CFG_ICON_LAST_RADDR_PLUS_ONE
#define CFG_ICON_LAST_RADDR_PLUS_ONE 1
#endif
#ifndef CFG_EN_COMPARISON
#define CFG_EN_COMPARISON 0
#endif

// --- subsystem enables ------------------------------------------------------
// EN_AW/EN_FM/EN_EM/EN_ANALOG_LOOP are load-bearing: the spin FIFO lives inside flip_manager, and
// results only re-enter it through energy_fifo_maintainer, which is also what ends the run
// (spin_fifo_maintainer.sv: cmpt_stop_comb = icon_finish_i & fifo_full). EN_FF feeds the flip
// engine's icon FIFO and is needed while flipping is enabled.
#ifndef CFG_EN_AW
#define CFG_EN_AW 1
#endif
#ifndef CFG_EN_EM
#define CFG_EN_EM 1
#endif
#ifndef CFG_EN_FM
#define CFG_EN_FM 1
#endif
#ifndef CFG_EN_FF
#define CFG_EN_FF 1
#endif
#ifndef CFG_EN_ANALOG_LOOP
#define CFG_EN_ANALOG_LOOP 1
#endif
#ifndef CFG_EN_EF
#define CFG_EN_EF 0
#endif
#ifndef CFG_EN_PERF_COUNTER
#define CFG_EN_PERF_COUNTER 0
#endif
// NOTE the capital-letter trap: ENABLE_FLIP_DETECTION in lagd_define.svh is a GENERATE parameter
// and it is 1, so digital_macro.sv elaborates the initialize_flip_filter branch and the flip filter
// sits UNCONDITIONALLY in the stream -- aw_downstream_ready = ff_slv_ready and
// em_upstream_mst_valid = ff_mst_valid are outside any runtime condition. This CSR bit only steers
// priority_handshake. Clearing it deviates from the only configuration known to run, inside a
// module data must flow through, so it is back at the reference value of 1.
#ifndef CFG_ENABLE_FLIP_DETECTION
#define CFG_ENABLE_FLIP_DETECTION 1
#endif
#ifndef CFG_FLUSH_EN
#define CFG_FLUSH_EN 0
#endif
// 0 keeps analog_cfg.sv's two's-complement -> sign-magnitude conversion; see the header.
#ifndef CFG_BYPASS_DATA_CONVERSION
#define CFG_BYPASS_DATA_CONVERSION 0
#endif
#ifndef CFG_HOST_READOUT
#define CFG_HOST_READOUT 0
#endif
#ifndef CFG_CONFIG_COUNTER
#define CFG_CONFIG_COUNTER 0xFF
#endif
#ifndef CFG_WWL_VDD_H
#define CFG_WWL_VDD_H 1
#endif
#ifndef CFG_WWL_VREAD_H
#define CFG_WWL_VREAD_H 0
#endif
#ifndef CFG_SYNCHRONIZER_WBL_PIPE_NUM
#define CFG_SYNCHRONIZER_WBL_PIPE_NUM 3
#endif
#ifndef CFG_SYNCHRONIZER_PIPE_NUM
#define CFG_SYNCHRONIZER_PIPE_NUM 3
#endif
#ifndef CFG_DEBUG_H_WWL
#define CFG_DEBUG_H_WWL 0
#endif
#ifndef CFG_DGT_ADDR_UPPER_BOUND
#define CFG_DGT_ADDR_UPPER_BOUND 0x3F
#endif
#ifndef CFG_CTNUS_FIFO_READ
#define CFG_CTNUS_FIFO_READ 0
#endif
#ifndef CFG_CTNUS_DGT_DEBUG
#define CFG_CTNUS_DGT_DEBUG 0
#endif
#ifndef CFG_INFINITE_ICON_LOOP_EN
#define CFG_INFINITE_ICON_LOOP_EN 0
#endif
#ifndef CFG_SPIN_INITIAL_SKIP_0
#define CFG_SPIN_INITIAL_SKIP_0 0
#endif
#ifndef CFG_SPIN_INITIAL_SKIP_1
#define CFG_SPIN_INITIAL_SKIP_1 0
#endif
#ifndef CFG_ENERGY_FIFO_SEL
#define CFG_ENERGY_FIFO_SEL 0
#endif

#if (CFG_CYCLE_PER_WWL_HIGH > 0xFFFF) || (CFG_CYCLE_PER_WWL_LOW > 0xFFFF) || \
    (CFG_CYCLE_PER_SPIN_WRITE > 0xFFFF) || (CFG_CYCLE_PER_SPIN_COMPUTE > 0xFFFF) || \
    (CFG_TRANS_NUM_ > 0xFFFF)
#error "a counter_cfg value exceeds its 16-bit field and would be silently truncated"
#endif
#if CFG_ICON_LAST_RADDR_PLUS_ONE > 0x7FF
#error "CFG_ICON_LAST_RADDR_PLUS_ONE exceeds its 11-bit field"
#endif

#include <stdint.h>
#include "printf.h"
#include "lagd_chip.h"
#include "lagd_core.h"

// Problem data, generated from tests/ref/data/$(DATA_FOLDER). J is never touched by software: it
// sits in the .l1j_data_c<core> section the analog onloader reads from, so the core decides which
// of the two headers to link in.
#if CORE_TESTED == 0
#include "model_j_data.h"
#include "spin_data.h"
#define PROBLEM_H_DATA model_h_data
#define PROBLEM_SPIN_INITIAL_0 spin_initial_0
#define PROBLEM_SPIN_INITIAL_1 spin_initial_1
#define PROBLEM_H_SCALING model_scaling_factor
#define FLIP_ICON_SECTION ".l1f_data_c0"
#else
#include "model_j_data_sec.h"
#include "spin_data_sec.h"
#define PROBLEM_H_DATA model_h_data_sec
#define PROBLEM_SPIN_INITIAL_0 spin_initial_0_sec
#define PROBLEM_SPIN_INITIAL_1 spin_initial_1_sec
#define PROBLEM_H_SCALING model_scaling_factor_sec
#define FLIP_ICON_SECTION ".l1f_data_c1"
#endif

#ifndef CFG_DGT_HSCALING
#define CFG_DGT_HSCALING PROBLEM_H_SCALING
#endif

// The flip mask: flipping is on, so flip_engine.sv XORs each state with one icon from
// l1_f_mem. An all-zero icon leaves the state untouched. Defined here rather than taken from
// model_f_data.h so the "no flips" guarantee does not depend on which data folder was built --
// whatever the generated cluster file happens to contain, this run cannot flip anything.
// 1024 entries of 256 bits, matching FLIP_ICON_DEPTH.
#define FLIP_ICON_WORDS (1024 * 4)
static const uint64_t flip_icons_zero[FLIP_ICON_WORDS]
    __attribute__((used, section(FLIP_ICON_SECTION))) = {0};

#define SPIN_WORDS (NUM_SPIN / 32)
#define WBL_WORDS (NUM_SPIN * BIT_H / 32)

// --- bounded polling ---------------------------------------------------------
// These polls used to be unbounded and both scenarios hung in one. A timeout turns that into a
// report: OUTPUT_STATUS carries handshake-level debug bits (AW downstream, FM upstream/downstream,
// EM upstream) that say exactly where in the analog->flip->energy stream the data stopped moving.
#ifndef POLL_TIMEOUT
#define POLL_TIMEOUT 20000000u
#endif

static void print_output_status(unsigned core) {
    uint32_t s = *lagd_core_reg(core, LAGD_CORE_OUTPUT_STATUS_REG_OFFSET);
    printf("  output_status = 0x%08x\r\n", s);
    printf("    dt_cfg_idle=%u cmpt_idle=%u energy_fifo_update=%u spin_fifo_update=%u\r\n",
           (s >> LAGD_CORE_OUTPUT_STATUS_DT_CFG_IDLE_BIT) & 1u,
           (s >> LAGD_CORE_OUTPUT_STATUS_CMPT_IDLE_BIT) & 1u,
           (s >> LAGD_CORE_OUTPUT_STATUS_ENERGY_FIFO_UPDATE_BIT) & 1u,
           (s >> LAGD_CORE_OUTPUT_STATUS_SPIN_FIFO_UPDATE_BIT) & 1u);
    printf("    aw_downstream=%u fm_upstream=%u fm_downstream=%u em_upstream=%u\r\n",
           (s >> LAGD_CORE_OUTPUT_STATUS_DEBUG_AW_DOWNSTREAM_HANDSHAKE_BIT) & 1u,
           (s >> LAGD_CORE_OUTPUT_STATUS_DEBUG_FM_UPSTREAM_HANDSHAKE_BIT) & 1u,
           (s >> LAGD_CORE_OUTPUT_STATUS_DEBUG_FM_DOWNSTREAM_HANDSHAKE_BIT) & 1u,
           (s >> LAGD_CORE_OUTPUT_STATUS_DEBUG_EM_UPSTREAM_HANDSHAKE_BIT) & 1u);
    printf("    spin_w_idle=%u spin_r_idle=%u spin_cmpt_idle=%u multi_cmpt_idle=%u\r\n",
           (s >> LAGD_CORE_OUTPUT_STATUS_DEBUG_SPIN_W_IDLE_BIT) & 1u,
           (s >> LAGD_CORE_OUTPUT_STATUS_DEBUG_SPIN_R_IDLE_BIT) & 1u,
           (s >> LAGD_CORE_OUTPUT_STATUS_DEBUG_SPIN_CMPT_IDLE_BIT) & 1u,
           (s >> LAGD_CORE_OUTPUT_STATUS_MULTI_CMPT_MODE_IDLE_BIT) & 1u);
}

// Returns 1 on success, 0 on timeout. On timeout it says which wait gave up and dumps the status.
static int poll_bit_timeout(unsigned core, uint32_t offset, unsigned bit, const char *what) {
    for (uint32_t n = 0; n < POLL_TIMEOUT; n++)
        if ((*lagd_core_reg(core, offset) >> bit) & 1u) return 1;
    printf("TIMEOUT waiting for %s\r\n", what);
    print_output_status(core);
    return 0;
}

// Print a 256-bit spin vector MSB-first: leftmost character is spin NUM_SPIN-1, rightmost is 0.
static void print_spin_vector(const char *label, const uint32_t words[SPIN_WORDS]) {
    printf("%s: ", label);
    for (int i = NUM_SPIN - 1; i >= 0; i--) printf("%u", (words[i / 32] >> (i % 32)) & 1u);
    printf("\r\n");
}

static void write_broadcast(unsigned core, uint32_t offset, unsigned words, uint32_t value) {
    for (unsigned i = 0; i < words; i++) *lagd_core_reg(core, offset + 4 * i) = value;
}

static void configure(unsigned core) {
    *lagd_core_reg(core, LAGD_CORE_CMPT_MAX_NUM_REG_OFFSET) = 1;

    write_broadcast(core, LAGD_CORE_WWL_VDD_CFG_0_REG_OFFSET, SPIN_WORDS, 0xFFFFFFFFu);
    write_broadcast(core, LAGD_CORE_WWL_VREAD_CFG_0_REG_OFFSET, SPIN_WORDS, 0x00000000u);
    write_broadcast(core, LAGD_CORE_SPIN_WWL_STROBE_0_REG_OFFSET, SPIN_WORDS, 0xFFFFFFFFu);
    // Feedback on for every spin: this is what makes the array compute, unlike a debug read which
    // needs it staged off.
    write_broadcast(core, LAGD_CORE_SPIN_FEEDBACK_CFG_0_REG_OFFSET, SPIN_WORDS, 0xFFFFFFFFu);
    // Active low: all ones = every WBL/WBLB column driven. This only latches on the
    // debug configure pulse, which is why it is written here and that bit is pulsed below.
    write_broadcast(core, LAGD_CORE_WBL_FLOATING_0_REG_OFFSET, WBL_WORDS, 0xFFFFFFFFu);

    lagd_core_write_vector(core, LAGD_CORE_CONFIG_SPIN_INITIAL_0_0_REG_OFFSET,
                           PROBLEM_SPIN_INITIAL_0, SPIN_WORDS);
    lagd_core_write_vector(core, LAGD_CORE_CONFIG_SPIN_INITIAL_1_0_REG_OFFSET,
                           PROBLEM_SPIN_INITIAL_1, SPIN_WORDS);
    lagd_core_write_vector(core, LAGD_CORE_H_RDATA_0_REG_OFFSET, PROBLEM_H_DATA, WBL_WORDS);

    *lagd_core_reg(core, LAGD_CORE_COUNTER_CFG_1_REG_OFFSET) =
        ((uint32_t)CFG_TRANS_NUM_ << LAGD_CORE_COUNTER_CFG_1_CFG_TRANS_NUM_OFFSET) |
        ((uint32_t)CFG_CYCLE_PER_WWL_HIGH << LAGD_CORE_COUNTER_CFG_1_CYCLE_PER_WWL_HIGH_OFFSET);
    *lagd_core_reg(core, LAGD_CORE_COUNTER_CFG_2_REG_OFFSET) =
        ((uint32_t)CFG_CYCLE_PER_WWL_LOW << LAGD_CORE_COUNTER_CFG_2_CYCLE_PER_WWL_LOW_OFFSET) |
        ((uint32_t)CFG_CYCLE_PER_SPIN_WRITE
         << LAGD_CORE_COUNTER_CFG_2_CYCLE_PER_SPIN_WRITE_OFFSET);
    *lagd_core_reg(core, LAGD_CORE_COUNTER_CFG_3_REG_OFFSET) =
        ((uint32_t)CFG_CYCLE_PER_SPIN_COMPUTE
         << LAGD_CORE_COUNTER_CFG_3_CYCLE_PER_SPIN_COMPUTE_OFFSET);
    *lagd_core_reg(core, LAGD_CORE_COUNTER_CFG_4_REG_OFFSET) =
        ((uint32_t)CFG_ICON_LAST_RADDR_PLUS_ONE
         << LAGD_CORE_COUNTER_CFG_4_ICON_LAST_RADDR_PLUS_ONE_OFFSET);

    // DEBUG_DT_CONFIGURE_ENABLE is pulsed only to latch wbl_floating;
    // DEBUG_SPIN_CONFIGURE_ENABLE alongside it, as the reference configuration does. Neither debug
    // *_EN bit is set, so no debug operation is triggered.
    *lagd_core_reg(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET) =
        ((uint32_t)CFG_FLUSH_EN << LAGD_CORE_GLOBAL_CFG_1_FLUSH_EN_BIT) |
        ((uint32_t)CFG_EN_AW << LAGD_CORE_GLOBAL_CFG_1_EN_AW_BIT) |
        ((uint32_t)CFG_EN_EM << LAGD_CORE_GLOBAL_CFG_1_EN_EM_BIT) |
        ((uint32_t)CFG_EN_FM << LAGD_CORE_GLOBAL_CFG_1_EN_FM_BIT) |
        ((uint32_t)CFG_EN_FF << LAGD_CORE_GLOBAL_CFG_1_EN_FF_BIT) |
        ((uint32_t)CFG_EN_EF << LAGD_CORE_GLOBAL_CFG_1_EN_EF_BIT) |
        ((uint32_t)CFG_EN_ANALOG_LOOP << LAGD_CORE_GLOBAL_CFG_1_EN_ANALOG_LOOP_BIT) |
        ((uint32_t)CFG_EN_COMPARISON << LAGD_CORE_GLOBAL_CFG_1_EN_COMPARISON_BIT) |
        (1u << LAGD_CORE_GLOBAL_CFG_1_DEBUG_DT_CONFIGURE_ENABLE_BIT) |
        (1u << LAGD_CORE_GLOBAL_CFG_1_DEBUG_SPIN_CONFIGURE_ENABLE_BIT) |
        ((uint32_t)CFG_EN_PERF_COUNTER << LAGD_CORE_GLOBAL_CFG_1_EN_PERF_COUNTER_BIT) |
        ((uint32_t)CFG_BYPASS_DATA_CONVERSION
         << LAGD_CORE_GLOBAL_CFG_1_BYPASS_DATA_CONVERSION_BIT) |
        ((uint32_t)CFG_HOST_READOUT << LAGD_CORE_GLOBAL_CFG_1_HOST_READOUT_BIT) |
        ((uint32_t)CFG_FLIP_DISABLE << LAGD_CORE_GLOBAL_CFG_1_FLIP_DISABLE_BIT) |
        ((uint32_t)CFG_ENABLE_FLIP_DETECTION
         << LAGD_CORE_GLOBAL_CFG_1_ENABLE_FLIP_DETECTION_BIT) |
        ((uint32_t)CFG_CONFIG_COUNTER << LAGD_CORE_GLOBAL_CFG_1_CONFIG_COUNTER_OFFSET) |
        ((uint32_t)CFG_WWL_VDD_H << LAGD_CORE_GLOBAL_CFG_1_WWL_VDD_CFG_256_BIT) |
        ((uint32_t)CFG_WWL_VREAD_H << LAGD_CORE_GLOBAL_CFG_1_WWL_VREAD_CFG_256_BIT) |
        ((uint32_t)CFG_SYNCHRONIZER_WBL_PIPE_NUM
         << LAGD_CORE_GLOBAL_CFG_1_SYNCHRONIZER_WBL_PIPE_NUM_OFFSET);

    // CONFIG_VALID_AW is what loads analog_cfg's and analog_rx's own timing/strobe registers, so it
    // has to be pulsed after the counters and the spin_wwl/spin_feedback vectors above.
    *lagd_core_reg(core, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET) =
        (1u << LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_AW_BIT) |
        (1u << LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_EM_BIT) |
        (1u << LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_FM_BIT) |
        ((uint32_t)CFG_SYNCHRONIZER_PIPE_NUM
         << LAGD_CORE_GLOBAL_CFG_2_SYNCHRONIZER_PIPE_NUM_OFFSET) |
        ((uint32_t)CFG_DEBUG_H_WWL << LAGD_CORE_GLOBAL_CFG_2_DEBUG_H_WWL_BIT) |
        ((uint32_t)CFG_DGT_ADDR_UPPER_BOUND
         << LAGD_CORE_GLOBAL_CFG_2_DGT_ADDR_UPPER_BOUND_OFFSET) |
        ((uint32_t)CFG_CTNUS_FIFO_READ << LAGD_CORE_GLOBAL_CFG_2_CTNUS_FIFO_READ_BIT) |
        ((uint32_t)CFG_CTNUS_DGT_DEBUG << LAGD_CORE_GLOBAL_CFG_2_CTNUS_DGT_DEBUG_BIT) |
        ((uint32_t)CFG_INFINITE_ICON_LOOP_EN
         << LAGD_CORE_GLOBAL_CFG_2_INFINITE_ICON_LOOP_EN_BIT) |
        ((uint32_t)CFG_SPIN_INITIAL_SKIP_0
         << LAGD_CORE_GLOBAL_CFG_2_CONFIG_SPIN_INITIAL_SKIP_0_BIT) |
        ((uint32_t)CFG_SPIN_INITIAL_SKIP_1
         << LAGD_CORE_GLOBAL_CFG_2_CONFIG_SPIN_INITIAL_SKIP_1_BIT) |
        ((uint32_t)CFG_DGT_HSCALING << LAGD_CORE_GLOBAL_CFG_2_DGT_HSCALING_OFFSET) |
        ((uint32_t)CFG_ENERGY_FIFO_SEL << LAGD_CORE_GLOBAL_CFG_2_ENERGY_FIFO_SEL_BIT);

    // Drop the one-shot pulses.
    lagd_core_clear_bit(core, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET,
                        LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_AW_BIT);
    lagd_core_clear_bit(core, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET,
                        LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_EM_BIT);
    lagd_core_clear_bit(core, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET,
                        LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_FM_BIT);
    lagd_core_clear_bit(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET,
                        LAGD_CORE_GLOBAL_CFG_1_DEBUG_DT_CONFIGURE_ENABLE_BIT);
    lagd_core_clear_bit(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET,
                        LAGD_CORE_GLOBAL_CFG_1_DEBUG_SPIN_CONFIGURE_ENABLE_BIT);
}

int main(void) {
    uint32_t final_0[SPIN_WORDS], final_1[SPIN_WORDS];

    lagd_chip_init();

    printf("=== COMPUTE RUN ===\r\n");
    printf("core=%u h_scaling=%u flip_disable=%u iterations=%u comparison=%u\r\n",
           (unsigned)CORE_TESTED, (unsigned)CFG_DGT_HSCALING, (unsigned)CFG_FLIP_DISABLE,
           (unsigned)CFG_ICON_LAST_RADDR_PLUS_ONE, (unsigned)CFG_EN_COMPARISON);
    printf("wwl_high=%u wwl_low=%u spin_write=%u spin_compute=%u trans_num=%u\r\n",
           (unsigned)CFG_CYCLE_PER_WWL_HIGH, (unsigned)CFG_CYCLE_PER_WWL_LOW,
           (unsigned)CFG_CYCLE_PER_SPIN_WRITE, (unsigned)CFG_CYCLE_PER_SPIN_COMPUTE,
           (unsigned)CFG_TRANS_NUM_);
    print_spin_vector("start_0", PROBLEM_SPIN_INITIAL_0);
    print_spin_vector("start_1", PROBLEM_SPIN_INITIAL_1);

    configure(CORE_TESTED);

    // Onload J and h into the analog macro. DT_CFG_ENABLE is a pulse; analog_cfg walks addresses
    // 0..CFG_TRANS_NUM_, the h row being the last, then raises DT_CFG_IDLE.
    lagd_core_set_bit(CORE_TESTED, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET,
                      LAGD_CORE_GLOBAL_CFG_2_DT_CFG_ENABLE_BIT);
    lagd_core_clear_bit(CORE_TESTED, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET,
                        LAGD_CORE_GLOBAL_CFG_2_DT_CFG_ENABLE_BIT);
    if (!poll_bit_timeout(CORE_TESTED, LAGD_CORE_OUTPUT_STATUS_REG_OFFSET,
                          LAGD_CORE_OUTPUT_STATUS_DT_CFG_IDLE_BIT, "DT_CFG_IDLE (J/h onload)")) {
        printf("=== DONE (onload never finished) ===\r\n");
        lagd_chip_finish();
        return 1;
    }
    printf("J/h onloaded\r\n");

    // One computation, held until CMPT_IDLE comes back up.
    lagd_core_set_bit(CORE_TESTED, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET,
                      LAGD_CORE_GLOBAL_CFG_2_CMPT_EN_BIT);
    int completed = poll_bit_timeout(CORE_TESTED, LAGD_CORE_OUTPUT_STATUS_REG_OFFSET,
                                     LAGD_CORE_OUTPUT_STATUS_CMPT_IDLE_BIT, "CMPT_IDLE");
    lagd_core_clear_bit(CORE_TESTED, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET,
                        LAGD_CORE_GLOBAL_CFG_2_CMPT_EN_BIT);
    printf(completed ? "computation done\r\n" : "computation DID NOT complete\r\n");

    lagd_core_read_vector(CORE_TESTED, LAGD_CORE_SPIN_FIFO_DATA_0_0_REG_OFFSET, final_0,
                          SPIN_WORDS);
    lagd_core_read_vector(CORE_TESTED, LAGD_CORE_SPIN_FIFO_DATA_1_0_REG_OFFSET, final_1,
                          SPIN_WORDS);
    print_spin_vector("final_0", final_0);
    print_spin_vector("final_1", final_1);

    // ENERGY_TOTAL_BIT is 32, so these are full-width two's complement.
    printf("energy_0: %d\r\n",
           (int32_t)*lagd_core_reg(CORE_TESTED, LAGD_CORE_ENERGY_FIFO_DATA_0_REG_OFFSET));
    printf("energy_1: %d\r\n",
           (int32_t)*lagd_core_reg(CORE_TESTED, LAGD_CORE_ENERGY_FIFO_DATA_1_REG_OFFSET));

    printf("=== DONE ===\r\n");
    lagd_chip_finish();
    return 0;
}
