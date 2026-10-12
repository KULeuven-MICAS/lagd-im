// Copyright 2026 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Toon Bettens <toon.bettens@kuleuven.be>

// Hybrid run: load the problem with the DEBUG write path that is known to work on this die, then
// hand the array to the NON-DEBUG compute path to actually settle and read out.
//
// The point is to take data writing out of the equation. scenarios/ising_block.spm.c proves the
// debug J/H/spin writes land correctly, so this file reuses that flow verbatim (same recipes, same
// polarity handling, same verification readback) and only the compute/settle/capture stage is the
// non-debug one. If this works and tests/galena/compute/compute_run.spm.c does not, the problem is
// in the analog_cfg onload or its data format; if neither works, it is in analog_rx's
// write/feedback/capture sequence.
//
// CRITICAL: DT_CFG_ENABLE IS NEVER PULSED HERE. analog_cfg.sv rewrites every J row and the h row
// from L1 / the H_RDATA registers when it runs, which would immediately destroy what the debug path
// just wrote. The compute stage does not need it -- dt_cfg_idle_o stays high, which is exactly what
// routes wbl_write_output to the spin path. So there is no onload step below, and no model_j_data
// header: this scenario carries its own problem in the tables at the top, like ising_block does.
//
// The initial state is written twice, deliberately. The debug write goes in first and is read back
// and verified, which is the diagnostic worth having. The compute path then rewrites the same
// values from CONFIG_SPIN_INITIAL when it pops -- that is not optional, analog_rx drives spin_wwl
// and WBL on every pop and there is no way to suppress it. Feeding it identical data makes the
// rewrite a no-op semantically, and per NOTE 4a in compute_run.spm.c the compute-path spin write is
// the structurally correct one anyway (it drives WBLB, the debug path hardwires it to 0).

#ifndef CORE_TESTED
#define CORE_TESTED 0
#endif
#ifndef BLOCK_BASE
#define BLOCK_BASE 0
#endif
// Changing this means rewriting J, H and SPINS below to match.
#ifndef BLOCK_SIZE
#define BLOCK_SIZE 5
#endif

// --- debug-side write timing: the values ising_block.spm.c uses -------------
#ifndef WWL_CYCLES
#define WWL_CYCLES 100
#endif
#ifndef SPIN_WRITE_CYCLES
#define SPIN_WRITE_CYCLES 100
#endif

// --- polarity, as in ising_block --------------------------------------------
// A value written into a CU reaches the array with its sign inverted, so J is negated on the way
// in. H is negated the same way -- the H row uses galena_encode_cu() exactly like a J row.
#ifndef INVERT_J
#define INVERT_J 1
#endif
#ifndef INVERT_H
#define INVERT_H 1
#endif

// --- compute-side stage ------------------------------------------------------
// See compute_run.spm.c for why each of these is what it is; the HEADROOM section there lists what
// to sweep. Only the knobs that matter once J/H are already in the array are exposed here.
#ifndef CFG_CYCLE_PER_SPIN_WRITE
#define CFG_CYCLE_PER_SPIN_WRITE 100
#endif
#ifndef CFG_CYCLE_PER_SPIN_COMPUTE
#define CFG_CYCLE_PER_SPIN_COMPUTE 100
#endif
#ifndef CFG_FLIP_DISABLE
#define CFG_FLIP_DISABLE 0
#endif
#ifndef CFG_ICON_LAST_RADDR_PLUS_ONE
#define CFG_ICON_LAST_RADDR_PLUS_ONE 1
#endif
#ifndef CFG_EN_COMPARISON
#define CFG_EN_COMPARISON 0
#endif
// ENABLE_FLIP_DETECTION in lagd_define.svh is a GENERATE parameter and is 1, so digital_macro.sv
// puts the flip filter unconditionally in the stream (aw_downstream_ready = ff_slv_ready,
// em_upstream_mst_valid = ff_mst_valid). This CSR bit only steers priority_handshake, so clearing
// it deviates from the only known-running configuration inside a module data must pass through.
#ifndef CFG_ENABLE_FLIP_DETECTION
#define CFG_ENABLE_FLIP_DETECTION 1
#endif
#ifndef CFG_DGT_HSCALING
#define CFG_DGT_HSCALING 1
#endif
#ifndef CFG_SYNCHRONIZER_PIPE_NUM
#define CFG_SYNCHRONIZER_PIPE_NUM 3
#endif
#ifndef CFG_DGT_ADDR_UPPER_BOUND
#define CFG_DGT_ADDR_UPPER_BOUND 0x3F
#endif

#if (CFG_CYCLE_PER_SPIN_WRITE > 0xFFFF) || (CFG_CYCLE_PER_SPIN_COMPUTE > 0xFFFF)
#error "a counter_cfg value exceeds its 16-bit field and would be silently truncated"
#endif
#if CFG_ICON_LAST_RADDR_PLUS_ONE > 0x7FF
#error "CFG_ICON_LAST_RADDR_PLUS_ONE exceeds its 11-bit field"
#endif

#include <stdint.h>
#include "printf.h"
#include "lagd_chip.h"
#include "lagd_bringup.h"
#include "lagd_galena_recipes.h"

// --- The problem -------------------------------------------------------------
// All entries -7..+7. Row i is logical spin i. The diagonal must stay 0.

static const int J[BLOCK_SIZE][BLOCK_SIZE] = {
    {0, 1, 1, 0, 0},
    {1, 0, 0, 1, 0},
    {1, 0, 0, 1, 1},
    {0, 1, 1, 0, 1},
    {0, 0, 1, 1, 0},
};

static const int H[BLOCK_SIZE] = {0, 0, 0, 0, 0};

static const int SPINS[BLOCK_SIZE] = {0, 0, 1, 1, 0};

// Flipping is enabled but must apply no flips, so the icon memory is filled with zeros from here
// rather than from a generated cluster file. 1024 entries of 256 bits, matching FLIP_ICON_DEPTH.
#if CORE_TESTED == 0
#define FLIP_ICON_SECTION ".l1f_data_c0"
#else
#define FLIP_ICON_SECTION ".l1f_data_c1"
#endif
static const uint64_t flip_icons_zero[1024 * 4]
    __attribute__((used, section(FLIP_ICON_SECTION))) = {0};

// --- Index mapping -----------------------------------------------------------

static unsigned hw(unsigned logical) { return BLOCK_BASE + logical; }

#define BLOCK_END (BLOCK_BASE + BLOCK_SIZE)

// --- Helpers -----------------------------------------------------------------

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

// Print BLOCK_SIZE bits in logical order: leftmost character is logical spin 0.
static void print_block(const char *label, const uint32_t spins[LAGD_SPIN_NUM_WORDS]) {
    printf("%s: ", label);
    for (unsigned i = 0; i < BLOCK_SIZE; i++) {
        unsigned h = hw(i);
        printf("%u", (spins[h / 32] >> (h % 32)) & 1u);
    }
    printf("\r\n");
}

static unsigned check_problem(void) {
    unsigned bad = 0;
    for (unsigned i = 0; i < BLOCK_SIZE; i++) {
        for (unsigned j = 0; j < BLOCK_SIZE; j++) {
            if (J[i][j] < -7 || J[i][j] > 7) {
                printf("BAD: J[%u][%u] = %d outside -7..+7\r\n", i, j, J[i][j]);
                bad++;
            }
            if (i == j && J[i][j] != 0) {
                printf("BAD: J[%u][%u] = %d, the diagonal is the AU and must be 0\r\n", i, j,
                       J[i][j]);
                bad++;
            }
        }
        if (H[i] < -7 || H[i] > 7) {
            printf("BAD: H[%u] = %d outside -7..+7\r\n", i, H[i]);
            bad++;
        }
        if (SPINS[i] != 0 && SPINS[i] != 1) {
            printf("BAD: SPINS[%u] = %d, expected 0 or 1\r\n", i, SPINS[i]);
            bad++;
        }
    }
    return bad;
}

// Everything the compute stage needs, written after the debug writes are done. This deliberately
// does NOT touch wwl_vdd/wwl_vread/wbl_floating: the debug path already left those correct, and
// re-latching them is exactly the kind of thing that would undo the setup being tested.
static void configure_compute_stage(unsigned core, const uint32_t spins[LAGD_SPIN_NUM_WORDS]) {
    uint32_t all_ones[LAGD_SPIN_NUM_WORDS];
    for (unsigned i = 0; i < LAGD_SPIN_NUM_WORDS; i++) all_ones[i] = 0xFFFFFFFFu;

    *lagd_core_reg(core, LAGD_CORE_CMPT_MAX_NUM_REG_OFFSET) = 1;

    // The state analog_rx will rewrite on each pop -- same values the debug path just wrote.
    lagd_core_write_vector(core, LAGD_CORE_CONFIG_SPIN_INITIAL_0_0_REG_OFFSET, spins,
                           LAGD_SPIN_NUM_WORDS);
    lagd_core_write_vector(core, LAGD_CORE_CONFIG_SPIN_INITIAL_1_0_REG_OFFSET, spins,
                           LAGD_SPIN_NUM_WORDS);

    // Strobe every spin on the write phase, feedback every spin on the settle phase.
    lagd_core_write_vector(core, LAGD_CORE_SPIN_WWL_STROBE_0_REG_OFFSET, all_ones,
                           LAGD_SPIN_NUM_WORDS);
    lagd_core_write_vector(core, LAGD_CORE_SPIN_FEEDBACK_CFG_0_REG_OFFSET, all_ones,
                           LAGD_SPIN_NUM_WORDS);

    lagd_core_write_field(core, LAGD_CORE_COUNTER_CFG_2_REG_OFFSET,
                          LAGD_CORE_COUNTER_CFG_2_CYCLE_PER_SPIN_WRITE_MASK,
                          LAGD_CORE_COUNTER_CFG_2_CYCLE_PER_SPIN_WRITE_OFFSET,
                          CFG_CYCLE_PER_SPIN_WRITE);
    lagd_core_write_field(core, LAGD_CORE_COUNTER_CFG_3_REG_OFFSET,
                          LAGD_CORE_COUNTER_CFG_3_CYCLE_PER_SPIN_COMPUTE_MASK,
                          LAGD_CORE_COUNTER_CFG_3_CYCLE_PER_SPIN_COMPUTE_OFFSET,
                          CFG_CYCLE_PER_SPIN_COMPUTE);
    lagd_core_write_field(core, LAGD_CORE_COUNTER_CFG_4_REG_OFFSET,
                          LAGD_CORE_COUNTER_CFG_4_ICON_LAST_RADDR_PLUS_ONE_MASK,
                          LAGD_CORE_COUNTER_CFG_4_ICON_LAST_RADDR_PLUS_ONE_OFFSET,
                          CFG_ICON_LAST_RADDR_PLUS_ONE);

    // global_cfg_1: subsystem enables for a compute run. EN_AW/EN_FM/EN_EM/EN_ANALOG_LOOP are
    // load-bearing (the spin FIFO lives in flip_manager, results re-enter it through
    // energy_fifo_maintainer, and that is also what ends the run); EN_FF feeds the flip engine's
    // icon FIFO while flipping is on. Comparison off so the second result is not discarded.
    // No debug configure pulse: that would re-latch wbl_floating and the debug WBL/strobe vectors.
    *lagd_core_reg(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET) =
        (1u << LAGD_CORE_GLOBAL_CFG_1_EN_AW_BIT) |
        (1u << LAGD_CORE_GLOBAL_CFG_1_EN_EM_BIT) |
        (1u << LAGD_CORE_GLOBAL_CFG_1_EN_FM_BIT) |
        (1u << LAGD_CORE_GLOBAL_CFG_1_EN_FF_BIT) |
        (1u << LAGD_CORE_GLOBAL_CFG_1_EN_ANALOG_LOOP_BIT) |
        ((uint32_t)CFG_EN_COMPARISON << LAGD_CORE_GLOBAL_CFG_1_EN_COMPARISON_BIT) |
        ((uint32_t)CFG_FLIP_DISABLE << LAGD_CORE_GLOBAL_CFG_1_FLIP_DISABLE_BIT) |
        ((uint32_t)CFG_ENABLE_FLIP_DETECTION
         << LAGD_CORE_GLOBAL_CFG_1_ENABLE_FLIP_DETECTION_BIT) |
        (0xFFu << LAGD_CORE_GLOBAL_CFG_1_CONFIG_COUNTER_OFFSET) |
        (1u << LAGD_CORE_GLOBAL_CFG_1_WWL_VDD_CFG_256_BIT) |
        (3u << LAGD_CORE_GLOBAL_CFG_1_SYNCHRONIZER_WBL_PIPE_NUM_OFFSET);

    // CONFIG_VALID_AW is what loads analog_rx's own strobe/feedback/timing registers, so it has to
    // be pulsed after the vectors and counters above.
    *lagd_core_reg(core, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET) =
        (1u << LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_AW_BIT) |
        (1u << LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_EM_BIT) |
        (1u << LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_FM_BIT) |
        ((uint32_t)CFG_SYNCHRONIZER_PIPE_NUM
         << LAGD_CORE_GLOBAL_CFG_2_SYNCHRONIZER_PIPE_NUM_OFFSET) |
        ((uint32_t)CFG_DGT_ADDR_UPPER_BOUND
         << LAGD_CORE_GLOBAL_CFG_2_DGT_ADDR_UPPER_BOUND_OFFSET) |
        ((uint32_t)CFG_DGT_HSCALING << LAGD_CORE_GLOBAL_CFG_2_DGT_HSCALING_OFFSET);

    lagd_core_clear_bit(core, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET,
                        LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_AW_BIT);
    lagd_core_clear_bit(core, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET,
                        LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_EM_BIT);
    lagd_core_clear_bit(core, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET,
                        LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_FM_BIT);
}

int main(void) {
    lagd_chip_init();

    printf("=== COMPUTE FROM DEBUG-WRITTEN DATA ===\r\n");
    printf("core=%u block hw [%u,%u) invert_j=%u invert_h=%u\r\n", (unsigned)CORE_TESTED,
           (unsigned)BLOCK_BASE, (unsigned)BLOCK_END, (unsigned)INVERT_J, (unsigned)INVERT_H);
    printf("debug wwl=%u spin_write=%u | compute spin_write=%u spin_compute=%u iters=%u\r\n",
           (unsigned)WWL_CYCLES, (unsigned)SPIN_WRITE_CYCLES, (unsigned)CFG_CYCLE_PER_SPIN_WRITE,
           (unsigned)CFG_CYCLE_PER_SPIN_COMPUTE, (unsigned)CFG_ICON_LAST_RADDR_PLUS_ONE);

    if (check_problem()) {
        printf("problem rejected, nothing written\r\n");
        printf("FINISH\r\n");
        lagd_chip_finish();
        return 1;
    }

    // ---- stage 1: debug writes, exactly the ising_block flow ----------------
    lagd_core_apply_config(CORE_TESTED, &LAGD_BASE_CONFIG);
    galena_stage_wwl_timing(CORE_TESTED, WWL_CYCLES, WWL_CYCLES);
    galena_commit_dt_configure(CORE_TESTED);
    galena_stage_spin_write_timing(CORE_TESTED, SPIN_WRITE_CYCLES);
    galena_commit_spin_configure(CORE_TESTED);

    galena_zero_array(CORE_TESTED);
    uint32_t zero_spins[LAGD_SPIN_NUM_WORDS] = {0};
    galena_write_spins(CORE_TESTED, zero_spins);

    for (unsigned i = 0; i < BLOCK_SIZE; i++) {
        int row_values[BLOCK_SIZE];
        for (unsigned j = 0; j < BLOCK_SIZE; j++) row_values[j] = INVERT_J ? -J[i][j] : J[i][j];
        galena_write_row_values(CORE_TESTED, hw(i), row_values, BLOCK_BASE, BLOCK_SIZE);
    }
    {
        int h_values[BLOCK_SIZE];
        for (unsigned i = 0; i < BLOCK_SIZE; i++) h_values[i] = INVERT_H ? -H[i] : H[i];
        galena_write_row_values(CORE_TESTED, NUM_SPIN, h_values, BLOCK_BASE, BLOCK_SIZE);
    }
    printf("J (%ux%u) and H written via the debug path\r\n", (unsigned)BLOCK_SIZE,
           (unsigned)BLOCK_SIZE);

    uint32_t start_spins[LAGD_SPIN_NUM_WORDS] = {0};
    for (unsigned i = 0; i < BLOCK_SIZE; i++)
        if (SPINS[i]) start_spins[hw(i) / 32] |= (1u << (hw(i) % 32));
    galena_write_spins(CORE_TESTED, start_spins);
    print_block("start    ", start_spins);

    uint32_t written[LAGD_SPIN_NUM_WORDS];
    galena_read_spins(CORE_TESTED, written);
    print_block("written  ", written);

    unsigned mismatches = 0;
    for (unsigned i = 0; i < NUM_SPIN; i++) {
        unsigned want = (start_spins[i / 32] >> (i % 32)) & 1u;
        unsigned got = (written[i / 32] >> (i % 32)) & 1u;
        if (want != got) mismatches++;
    }
    if (mismatches)
        printf("WRITE CHECK FAIL (%u mismatches)\r\n", mismatches);
    else
        printf("WRITE CHECK PASS\r\n");

    // ---- stage 2: hand over to the compute path -----------------------------
    // No DT_CFG_ENABLE pulse: J and H are already in the array and analog_cfg would overwrite them.
    configure_compute_stage(CORE_TESTED, start_spins);

    lagd_core_set_bit(CORE_TESTED, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET,
                      LAGD_CORE_GLOBAL_CFG_2_CMPT_EN_BIT);
    int completed = poll_bit_timeout(CORE_TESTED, LAGD_CORE_OUTPUT_STATUS_REG_OFFSET,
                                     LAGD_CORE_OUTPUT_STATUS_CMPT_IDLE_BIT, "CMPT_IDLE");
    lagd_core_clear_bit(CORE_TESTED, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET,
                        LAGD_CORE_GLOBAL_CFG_2_CMPT_EN_BIT);
    printf(completed ? "computation done\r\n" : "computation DID NOT complete\r\n");

    uint32_t final_0[LAGD_SPIN_NUM_WORDS], final_1[LAGD_SPIN_NUM_WORDS];
    lagd_core_read_vector(CORE_TESTED, LAGD_CORE_SPIN_FIFO_DATA_0_0_REG_OFFSET, final_0,
                          LAGD_SPIN_NUM_WORDS);
    lagd_core_read_vector(CORE_TESTED, LAGD_CORE_SPIN_FIFO_DATA_1_0_REG_OFFSET, final_1,
                          LAGD_SPIN_NUM_WORDS);
    print_block("final_0  ", final_0);
    print_block("final_1  ", final_1);

    printf("energy_0: %d\r\n",
           (int32_t)*lagd_core_reg(CORE_TESTED, LAGD_CORE_ENERGY_FIFO_DATA_0_REG_OFFSET));
    printf("energy_1: %d\r\n",
           (int32_t)*lagd_core_reg(CORE_TESTED, LAGD_CORE_ENERGY_FIFO_DATA_1_REG_OFFSET));

    printf("FINISH\r\n");

    lagd_chip_finish();
    return 0;
}
