// Copyright 2026 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Toon Bettens <toon.bettens@kuleuven.be>

// Load a problem and a starting state over the debug path, then drive feedback/read pulses through
// the non-debug analog path, without running a computation.
//
// Trigger: TRIGGER_CMPT_EN (default) is a normal computation launch, and with FLIP_DISABLE set
// flip_engine ends the run after SPIN_DEPTH handshakes -- exactly two pulses, then CMPT_IDLE.
// TRIGGER_HOST_READOUT should also allow pops with no computation (spin_fifo_maintainer.sv:115),
// but is measured not to work on this die: fm_rx_cnt stays 0 and no handshake bit ever rises.
// Kept as an option, not a default.
//
// CTNUS_FIFO_READ is required for readback: it is what keeps the FIFO CSR mirrors live
// (ising_core_wrap.sv:402). Without it they only refresh at the end of a computation.
//
// There is no feedback-only pulse on the non-debug side. analog_rx.sv chains write -> feedback ->
// capture off a single pop, so every pulse rewrites the spins from the FIFO first. Harmless here:
// the FIFO holds the state the debug path wrote, so the first rewrite is a no-op and later ones
// rewrite whatever the array last settled to.
//
// HOST_READOUT is a level, not a pulse -- while high, each result is pushed back and popped again,
// so the array free-runs. DWELL_ITERS sets how long that window stays open.
//
// J and H are written into the analog array only. The digital energy monitor uses its own copies
// from l1_j_mem and the H_RDATA registers, neither of which is loaded, so the reported energies are
// meaningless; the spins are the result.

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

// --- debug-side write timing, as in scenarios/ising_block.spm.c --------------
#ifndef WWL_CYCLES
#define WWL_CYCLES 100
#endif
#ifndef SPIN_WRITE_CYCLES
#define SPIN_WRITE_CYCLES 100
#endif

// --- polarity, as in ising_block ---------------------------------------------
#ifndef INVERT_J
#define INVERT_J 1
#endif
#ifndef INVERT_H
#define INVERT_H 1
#endif

// --- the non-debug pulse ------------------------------------------------------
#ifndef CFG_CYCLE_PER_SPIN_WRITE
#define CFG_CYCLE_PER_SPIN_WRITE 100
#endif
#ifndef CFG_CYCLE_PER_SPIN_COMPUTE
#define CFG_CYCLE_PER_SPIN_COMPUTE 100
#endif
// CPU spin iterations with HOST_READOUT held high. Each analog pulse is roughly
// cycle_per_spin_write + cycle_per_spin_compute cycles, so this is a coarse dial on how many
// pulses happen. 0 opens and closes the window as fast as two register writes allow.
#ifndef DWELL_ITERS
#define DWELL_ITERS 1000
#endif
// Flipping off: flip_engine bypasses its XOR, so the state reaching the array is exactly what came
// out of the FIFO, and no icon memory is read.
#ifndef CFG_FLIP_DISABLE
#define CFG_FLIP_DISABLE 1
#endif
// Off, so every returned result is pushed rather than only improvements.
#ifndef CFG_EN_COMPARISON
#define CFG_EN_COMPARISON 0
#endif
#ifndef CFG_ENABLE_FLIP_DETECTION
#define CFG_ENABLE_FLIP_DETECTION 1
#endif
// 0 = launch a computation (proven), 1 = raise HOST_READOUT (does not pop, see above).
#ifndef USE_HOST_READOUT
#define USE_HOST_READOUT 0
#endif
// Subsystem enables default to the lagd_reg_params.h values, i.e. the set the launch probe ran
// under, since that is the configuration known to complete. Relax them one at a time afterwards.
#ifndef CFG_EN_EF
#define CFG_EN_EF 1
#endif
#ifndef POLL_TIMEOUT
#define POLL_TIMEOUT 20000000u
#endif

#if (CFG_CYCLE_PER_SPIN_WRITE > 0xFFFF) || (CFG_CYCLE_PER_SPIN_COMPUTE > 0xFFFF)
#error "a counter_cfg value exceeds its 16-bit field and would be silently truncated"
#endif

#include <stdint.h>
#include "printf.h"
#include "lagd_chip.h"
#include "lagd_bringup.h"
#include "lagd_galena_recipes.h"

// --- The problem -------------------------------------------------------------
// All entries -7..+7. Row i is logical spin i. The diagonal must stay 0.

// The same problem scenarios/ising_block.spm.c currently holds, so the two paths can be compared
// directly. All couplings -1: antiferromagnetic, and frustrated on this graph -- the aligned states
// are the WORST ones here, the opposite of the ferromagnetic case.
//
// Enumerated offline over all 32 states:
//     ground  E =  -4, four-fold degenerate: 01100, 01101, 10010, 10011
//     worst   E =  +6, at 00000 and 11111
//     start   E =  -2 at 00110, so it has to move, but only by 2
static const int J[BLOCK_SIZE][BLOCK_SIZE] = {
    { 0, -1, -1,  0,  0},
    {-1,  0,  0, -1,  0},
    {-1,  0,  0, -1, -1},
    { 0, -1, -1,  0, -1},
    { 0,  0, -1, -1,  0},
};

static const int H[BLOCK_SIZE] = {0, 0, 0, 0, 0};

static const int SPINS[BLOCK_SIZE] = {0, 0, 1, 1, 0};

static unsigned hw(unsigned logical) { return BLOCK_BASE + logical; }

#define BLOCK_END (BLOCK_BASE + BLOCK_SIZE)

static void print_block(const char *label, const uint32_t spins[LAGD_SPIN_NUM_WORDS]) {
    printf("%s: ", label);
    for (unsigned i = 0; i < BLOCK_SIZE; i++) {
        unsigned h = hw(i);
        printf("%u", (spins[h / 32] >> (h % 32)) & 1u);
    }
    printf("\r\n");
}

// Number of energies the flip manager has received back, i.e. completed pop -> write -> feedback
// -> capture -> return round trips. The direct measure of how many times feedback actually fired.
static unsigned fm_rx_count(unsigned core) {
    uint32_t d = *lagd_core_reg(core, LAGD_CORE_ENERGY_FIFO_DBG_0_REG_OFFSET);
    return (d >> LAGD_CORE_ENERGY_FIFO_DBG_0_FM_RX_CNT_OFFSET) &
           LAGD_CORE_ENERGY_FIFO_DBG_0_FM_RX_CNT_MASK;
}

static void read_spin_fifo(unsigned core, unsigned set, uint32_t out[LAGD_SPIN_NUM_WORDS]) {
    uint32_t off = set ? LAGD_CORE_SPIN_FIFO_DATA_1_0_REG_OFFSET
                       : LAGD_CORE_SPIN_FIFO_DATA_0_0_REG_OFFSET;
    lagd_core_read_vector(core, off, out, LAGD_SPIN_NUM_WORDS);
}

// Ising energy in the usual convention, from the table values (the intended physics, not the
// inverted values on the wires):
//     E = - sum_{i<j} J[i][j] * s_i * s_j  -  sum_i H[i] * s_i
// with a stored bit of 1 meaning spin +1 and 0 meaning spin -1.
static int host_energy(const uint32_t spins[LAGD_SPIN_NUM_WORDS]) {
    int energy = 0;
    for (unsigned i = 0; i < BLOCK_SIZE; i++) {
        unsigned hi = hw(i);
        int si = ((spins[hi / 32] >> (hi % 32)) & 1u) ? 1 : -1;
        for (unsigned j = i + 1; j < BLOCK_SIZE; j++) {
            unsigned hj = hw(j);
            int sj = ((spins[hj / 32] >> (hj % 32)) & 1u) ? 1 : -1;
            energy -= J[i][j] * si * sj;
        }
        energy -= H[i] * si;
    }
    return energy;
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

// Compute-side registers. Deliberately does not touch wwl_vdd/wwl_vread/wbl_floating: the debug
// writes already left those correct and re-latching them would undo the setup under test.
static void configure_pulse_path(unsigned core, const uint32_t spins[LAGD_SPIN_NUM_WORDS]) {
    uint32_t all_ones[LAGD_SPIN_NUM_WORDS];
    for (unsigned i = 0; i < LAGD_SPIN_NUM_WORDS; i++) all_ones[i] = 0xFFFFFFFFu;

    // The FIFO source. config_valid_fm's rising edge below is what pushes these in
    // (digital_macro.sv:556, config_start_i), and it is the only way to fill the spin FIFO.
    lagd_core_write_vector(core, LAGD_CORE_CONFIG_SPIN_INITIAL_0_0_REG_OFFSET, spins,
                           LAGD_SPIN_NUM_WORDS);
    lagd_core_write_vector(core, LAGD_CORE_CONFIG_SPIN_INITIAL_1_0_REG_OFFSET, spins,
                           LAGD_SPIN_NUM_WORDS);

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

    // HOST_READOUT stays LOW here -- it is raised separately to open the pulse window.
    *lagd_core_reg(core, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET) =
        (1u << LAGD_CORE_GLOBAL_CFG_1_EN_AW_BIT) |
        (1u << LAGD_CORE_GLOBAL_CFG_1_EN_EM_BIT) |
        (1u << LAGD_CORE_GLOBAL_CFG_1_EN_FM_BIT) |
        (1u << LAGD_CORE_GLOBAL_CFG_1_EN_FF_BIT) |
        (1u << LAGD_CORE_GLOBAL_CFG_1_EN_ANALOG_LOOP_BIT) |
        // Without this fm_rx_cnt's CSR mirror never updates -- ising_core_wrap.sv:347 has
        // hw2reg.energy_fifo_dbg_0.fm_rx_cnt.de = en_perf_counter -- and the counter reads 0
        // whether or not anything happened.
        (1u << LAGD_CORE_GLOBAL_CFG_1_EN_PERF_COUNTER_BIT) |
        ((uint32_t)CFG_EN_EF << LAGD_CORE_GLOBAL_CFG_1_EN_EF_BIT) |
        ((uint32_t)CFG_EN_COMPARISON << LAGD_CORE_GLOBAL_CFG_1_EN_COMPARISON_BIT) |
        ((uint32_t)CFG_FLIP_DISABLE << LAGD_CORE_GLOBAL_CFG_1_FLIP_DISABLE_BIT) |
        ((uint32_t)CFG_ENABLE_FLIP_DETECTION
         << LAGD_CORE_GLOBAL_CFG_1_ENABLE_FLIP_DETECTION_BIT) |
        (0xFFu << LAGD_CORE_GLOBAL_CFG_1_CONFIG_COUNTER_OFFSET) |
        (1u << LAGD_CORE_GLOBAL_CFG_1_WWL_VDD_CFG_256_BIT) |
        (3u << LAGD_CORE_GLOBAL_CFG_1_SYNCHRONIZER_WBL_PIPE_NUM_OFFSET);

    // CTNUS_FIFO_READ keeps the spin/energy FIFO CSR mirrors live; without it they would only
    // refresh on a cmpt_idle posedge, which never comes because no computation is run.
    // CONFIG_VALID_AW loads analog_rx's strobe/feedback/timing; CONFIG_VALID_FM pushes the spins.
    *lagd_core_reg(core, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET) =
        (1u << LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_AW_BIT) |
        (1u << LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_EM_BIT) |
        (1u << LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_FM_BIT) |
        (1u << LAGD_CORE_GLOBAL_CFG_2_CTNUS_FIFO_READ_BIT) |
        (3u << LAGD_CORE_GLOBAL_CFG_2_SYNCHRONIZER_PIPE_NUM_OFFSET) |
        (0x3Fu << LAGD_CORE_GLOBAL_CFG_2_DGT_ADDR_UPPER_BOUND_OFFSET) |
        (1u << LAGD_CORE_GLOBAL_CFG_2_DGT_HSCALING_OFFSET);

    lagd_core_clear_bit(core, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET,
                        LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_AW_BIT);
    lagd_core_clear_bit(core, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET,
                        LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_EM_BIT);
    lagd_core_clear_bit(core, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET,
                        LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_FM_BIT);
}

int main(void) {
    lagd_chip_init();

    printf("=== NON-DEBUG FEEDBACK PULSE ON DEBUG-WRITTEN DATA ===\r\n");
    printf("core=%u block hw [%u,%u) invert_j=%u invert_h=%u\r\n", (unsigned)CORE_TESTED,
           (unsigned)BLOCK_BASE, (unsigned)BLOCK_END, (unsigned)INVERT_J, (unsigned)INVERT_H);
    printf("pulse: spin_write=%u spin_compute=%u flip_disable=%u trigger=%s\r\n",
           (unsigned)CFG_CYCLE_PER_SPIN_WRITE, (unsigned)CFG_CYCLE_PER_SPIN_COMPUTE,
           (unsigned)CFG_FLIP_DISABLE, USE_HOST_READOUT ? "HOST_READOUT" : "CMPT_EN");

    if (check_problem()) {
        printf("problem rejected, nothing written\r\n");
        printf("FINISH\r\n");
        lagd_chip_finish();
        return 1;
    }

    // ---- stage 1: debug writes, the ising_block flow -------------------------
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

    uint32_t written[LAGD_SPIN_NUM_WORDS];
    galena_read_spins(CORE_TESTED, written);
    print_block("start    ", start_spins);
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

    // ---- stage 2: the non-debug pulse ---------------------------------------
    configure_pulse_path(CORE_TESTED, start_spins);

    uint32_t before_0[LAGD_SPIN_NUM_WORDS], before_1[LAGD_SPIN_NUM_WORDS];
    read_spin_fifo(CORE_TESTED, 0, before_0);
    read_spin_fifo(CORE_TESTED, 1, before_1);
    print_block("fifo_0 pre", before_0);
    print_block("fifo_1 pre", before_1);

    // Open the pulse window: pops now run without a computation. Each pop is one full
    // write -> feedback -> capture in analog_rx, so this is where feedback actually fires.
    // Sticky-OR while the pulses run. spin_fifo_update / energy_fifo_update are live under
    // CTNUS_FIFO_READ (ising_core_wrap.sv:313-314), so this is a second, perf-counter-independent
    // witness that data moved.
    unsigned rx_befor512e = fm_rx_count(CORE_TESTED);
    uint32_t sticky = 0;
    unsigned completed = 1;

    if (USE_HOST_READOUT) {
        lagd_core_set_bit(CORE_TESTED, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET,
                          LAGD_CORE_GLOBAL_CFG_1_HOST_READOUT_BIT);
        for (uint32_t n = 0; n < DWELL_ITERS; n++)
            sticky |= *lagd_core_reg(CORE_TESTED, LAGD_CORE_OUTPUT_STATUS_REG_OFFSET);
        lagd_core_clear_bit(CORE_TESTED, LAGD_CORE_GLOBAL_CFG_1_REG_OFFSET,
                            LAGD_CORE_GLOBAL_CFG_1_HOST_READOUT_BIT);
    } else {
        // One computation: two pops, each a full write -> feedback -> capture in analog_rx.
        lagd_core_set_bit(CORE_TESTED, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET,
                          LAGD_CORE_GLOBAL_CFG_2_CMPT_EN_BIT);
        completed = 0;
        for (uint32_t n = 0; n < POLL_TIMEOUT; n++) {
            uint32_t st = *lagd_core_reg(CORE_TESTED, LAGD_CORE_OUTPUT_STATUS_REG_OFFSET);
            sticky |= st;
            if ((st >> LAGD_CORE_OUTPUT_STATUS_CMPT_IDLE_BIT) & 1u) {
                completed = 1;
                break;
            }
        }
        lagd_core_clear_bit(CORE_TESTED, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET,
                            LAGD_CORE_GLOBAL_CFG_2_CMPT_EN_BIT);
    }
    unsigned rx_after = fm_rx_count(CORE_TESTED);

    // 0 means feedback never fired at all. 2 means only the two preloaded FIFO entries drained and
    // nothing came back to re-pop. More than 2 means the loop was free-running as intended.
    printf("trigger=%s completed=%s\r\n", USE_HOST_READOUT ? "HOST_READOUT" : "CMPT_EN",
           completed ? "yes" : "NO (timeout)");
    printf("pulse window closed: fm_rx_cnt %u -> %u (%u round trips)\r\n", rx_before, rx_after,
           (rx_after - rx_before) & LAGD_CORE_ENERGY_FIFO_DBG_0_FM_RX_CNT_MASK);
    printf("  sticky during window: 0x%08x | spin_fifo_update=%u energy_fifo_update=%u "
           "aw_dn=%u em_up=%u\r\n",
           sticky, (sticky >> LAGD_CORE_OUTPUT_STATUS_SPIN_FIFO_UPDATE_BIT) & 1u,
           (sticky >> LAGD_CORE_OUTPUT_STATUS_ENERGY_FIFO_UPDATE_BIT) & 1u,
           (sticky >> LAGD_CORE_OUTPUT_STATUS_DEBUG_AW_DOWNSTREAM_HANDSHAKE_BIT) & 1u,
           (sticky >> LAGD_CORE_OUTPUT_STATUS_DEBUG_EM_UPSTREAM_HANDSHAKE_BIT) & 1u);

    uint32_t after_0[LAGD_SPIN_NUM_WORDS], after_1[LAGD_SPIN_NUM_WORDS];
    read_spin_fifo(CORE_TESTED, 0, after_0);
    read_spin_fifo(CORE_TESTED, 1, after_1);
    print_block("fifo_0 post", after_0);
    print_block("fifo_1 post", after_1);

    // A debug read of the spin CACHE. The settled result is captured into the FIFO by the
    // synchronizer and never written back into the cells, so this shows the last value the compute
    // path wrote on its final pop -- not the answer. Printed as a cross-check, not as the result.
    uint32_t array_now[LAGD_SPIN_NUM_WORDS];
    galena_read_spins(CORE_TESTED, array_now);
    print_block("array    ", array_now);

    printf("--- energy ---\r\n");
    printf("start   E = %+d\r\n", host_energy(start_spins));
    printf("fifo_0  E = %+d\r\n", host_energy(after_0));
    printf("fifo_1  E = %+d\r\n", host_energy(after_1));
    printf("(ground E = -4, at 01100 / 01101 / 10010 / 10011)\r\n");

    printf("FINISH\r\n");

    lagd_chip_finish();
    return 0;
}
