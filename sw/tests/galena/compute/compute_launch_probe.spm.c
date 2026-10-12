// Copyright 2026 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Toon Bettens <toon.bettens@kuleuven.be>

// Instrumented version of the step in tests/ref/lagd_scompute.spm.c that is hardest to observe:
// launching the computation and getting data back. Everything up to the launch is the reference
// flow verbatim (same headers, same register configuration, same order), so this is scompute --
// only the launch/readback stage is watched.
//
// The handshake bits in OUTPUT_STATUS are combinational, e.g.
// debug_aw_downstream_handshake_o = aw_downstream_ready & aw_mst_valid (digital_macro.sv:277), and
// high only for the single cycle a transfer happens -- a plain CPU register read essentially never
// catches one, so reading zeros proves nothing. This samples in a tight loop into RAM and
// sticky-ORs what it sees, printing only after the run so UART traffic does not slow the sampling.
//
// The real progress indicator is ENERGY_FIFO_DBG_0.fm_rx_cnt: the number of energies the flip
// manager has received back. If that stays 0 the array never returned a result; if it climbs, data
// is flowing and the problem is further down.

#ifndef CORE_TESTED
#define CORE_TESTED 0
#endif
// Samples taken while the computation runs. Each is two register reads.
#ifndef MAX_SAMPLES
#define MAX_SAMPLES 4096
#endif
// Distinct states printed from the trace (consecutive identical samples are collapsed).
#ifndef MAX_TRACE_PRINT
#define MAX_TRACE_PRINT 24
#endif

// Pulse-width overrides. Defaults are the lagd_reg_params.h values, so with no -D this stays a
// faithful scompute. The debug scenarios that are known to drive this array use 100 for the write
// pulses, i.e. 20x these -- pass -DPULSE_WWL_HIGH=100 -DPULSE_WWL_LOW=100 -DPULSE_SPIN_WRITE=100
// to test whether the array is simply not being driven long enough to latch anything.
#ifndef PULSE_WWL_HIGH
#define PULSE_WWL_HIGH CYCLE_PER_WWL_HIGH
#endif
#ifndef PULSE_WWL_LOW
#define PULSE_WWL_LOW CYCLE_PER_WWL_LOW
#endif
#ifndef PULSE_SPIN_WRITE
#define PULSE_SPIN_WRITE CYCLE_PER_SPIN_WRITE
#endif
#ifndef PULSE_SPIN_COMPUTE
#define PULSE_SPIN_COMPUTE CYCLE_PER_SPIN_COMPUTE
#endif

#include "regs/cheshire.h"
#include "dif/clint.h"
#include "dif/uart.h"
#include "params.h"
#include "util.h"
#include "printf.h"
// lagd_scompute.h must come before lagd_common.h
#include "lagd_scompute.h"
#include "lagd_common.h"
#include "lagd_galena.h"

static uint32_t status_log[MAX_SAMPLES];
static uint32_t dbg_log[MAX_SAMPLES];

static void print_status(const char *label, uint32_t s) {
    printf("%s 0x%08x | dt_cfg_idle=%u cmpt_idle=%u e_upd=%u s_upd=%u | "
           "aw_dn=%u fm_up=%u fm_dn=%u em_up=%u\r\n",
           label, s, (s >> LAGD_CORE_OUTPUT_STATUS_DT_CFG_IDLE_BIT) & 1u,
           (s >> LAGD_CORE_OUTPUT_STATUS_CMPT_IDLE_BIT) & 1u,
           (s >> LAGD_CORE_OUTPUT_STATUS_ENERGY_FIFO_UPDATE_BIT) & 1u,
           (s >> LAGD_CORE_OUTPUT_STATUS_SPIN_FIFO_UPDATE_BIT) & 1u,
           (s >> LAGD_CORE_OUTPUT_STATUS_DEBUG_AW_DOWNSTREAM_HANDSHAKE_BIT) & 1u,
           (s >> LAGD_CORE_OUTPUT_STATUS_DEBUG_FM_UPSTREAM_HANDSHAKE_BIT) & 1u,
           (s >> LAGD_CORE_OUTPUT_STATUS_DEBUG_FM_DOWNSTREAM_HANDSHAKE_BIT) & 1u,
           (s >> LAGD_CORE_OUTPUT_STATUS_DEBUG_EM_UPSTREAM_HANDSHAKE_BIT) & 1u);
}

static void print_dbg(const char *label, uint32_t d) {
    printf("%s 0x%08x | cmpt_idle=%u e_upd=%u flip_q_valid=%u fm_rx_cnt=%u\r\n", label, d,
           (d >> LAGD_CORE_ENERGY_FIFO_DBG_0_CMPT_IDLE_BIT) & 1u,
           (d >> LAGD_CORE_ENERGY_FIFO_DBG_0_ENERGY_FIFO_UPDATE_BIT) & 1u,
           (d >> LAGD_CORE_ENERGY_FIFO_DBG_0_FLIP_Q_VALID_BIT) & 1u,
           (d >> LAGD_CORE_ENERGY_FIFO_DBG_0_FM_RX_CNT_OFFSET) &
               LAGD_CORE_ENERGY_FIFO_DBG_0_FM_RX_CNT_MASK);
}

static void print_spin_fifo(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    for (int set = 0; set < 2; set++) {
        uint32_t off = set ? LAGD_CORE_SPIN_FIFO_DATA_1_0_REG_OFFSET
                           : LAGD_CORE_SPIN_FIFO_DATA_0_0_REG_OFFSET;
        printf("  spin_fifo_%d: ", set);
        for (int i = NUM_SPIN / 32 - 1; i >= 0; i--) printf("%08x", *reg32(base, off + 4 * i));
        printf("\r\n");
    }
}

int main(void) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)CORE_TESTED * IC_NUM_REGS);

    uint32_t rtc_freq = *reg32(&__base_regs, CHESHIRE_RTC_FREQ_REG_OFFSET);
    uint64_t reset_freq = clint_get_core_freq(rtc_freq, 2500);
    uart_init(&__base_uart, reset_freq, __BOOT_BAUDRATE);

    printf("=== SCOMPUTE LAUNCH PROBE ===\r\n");
    printf("core=%u h_scaling=%u max_samples=%u\r\n", (unsigned)CORE_TESTED,
           (unsigned)SC_SCALING_FACTOR, (unsigned)MAX_SAMPLES);
    printf("pulses: wwl_high=%u wwl_low=%u spin_write=%u spin_compute=%u\r\n",
           (unsigned)PULSE_WWL_HIGH, (unsigned)PULSE_WWL_LOW, (unsigned)PULSE_SPIN_WRITE,
           (unsigned)PULSE_SPIN_COMPUTE);

    // ---- reference scompute configuration, unchanged -------------------------
    lagd_configure_initial_spins(CORE_TESTED);
    lagd_configure_cmpt_max_num(CORE_TESTED);
    lagd_configure_counters(CORE_TESTED);
    // Re-write the three counter registers with the pulse widths above. This sits before
    // global_cfg_1/2, so the CONFIG_VALID_AW pulse they raise is what latches these into
    // analog_cfg's and analog_rx's own timing registers.
    *reg32(base, LAGD_CORE_COUNTER_CFG_1_REG_OFFSET) =
        ((uint32_t)CFG_TRANS_NUM << LAGD_CORE_COUNTER_CFG_1_CFG_TRANS_NUM_OFFSET) |
        ((uint32_t)PULSE_WWL_HIGH << LAGD_CORE_COUNTER_CFG_1_CYCLE_PER_WWL_HIGH_OFFSET);
    *reg32(base, LAGD_CORE_COUNTER_CFG_2_REG_OFFSET) =
        ((uint32_t)PULSE_WWL_LOW << LAGD_CORE_COUNTER_CFG_2_CYCLE_PER_WWL_LOW_OFFSET) |
        ((uint32_t)PULSE_SPIN_WRITE << LAGD_CORE_COUNTER_CFG_2_CYCLE_PER_SPIN_WRITE_OFFSET);
    *reg32(base, LAGD_CORE_COUNTER_CFG_3_REG_OFFSET) =
        ((uint32_t)PULSE_SPIN_COMPUTE << LAGD_CORE_COUNTER_CFG_3_CYCLE_PER_SPIN_COMPUTE_OFFSET) |
        ((uint32_t)DEBUG_CYCLE_PER_SPIN_READ
         << LAGD_CORE_COUNTER_CFG_3_DEBUG_CYCLE_PER_SPIN_READ_OFFSET);
    lagd_configure_wwl_vdd_cfg(CORE_TESTED);
    lagd_configure_wwl_vread_cfg(CORE_TESTED);
    lagd_configure_spin_wwl_strobe(CORE_TESTED);
    lagd_configure_spin_feedback(CORE_TESTED);
    lagd_configure_h_rdata(CORE_TESTED);
    lagd_configure_global_cfg_1(CORE_TESTED);
    lagd_configure_global_cfg_2(CORE_TESTED);
    lagd_clear_config_valid(CORE_TESTED);

    print_status("after config    :", *reg32(base, LAGD_CORE_OUTPUT_STATUS_REG_OFFSET));

    // ---- onload, still the reference flow ------------------------------------
    lagd_enable_analog_onloading(CORE_TESTED);
    {
        uint32_t n = 0;
        while (((*reg32(base, LAGD_CORE_OUTPUT_STATUS_REG_OFFSET) >>
                 LAGD_CORE_OUTPUT_STATUS_DT_CFG_IDLE_BIT) &
                1u) == 0 &&
               n < 50000000u)
            n++;
        printf("onload wait      : %s after %u polls\r\n",
               n < 50000000u ? "DT_CFG_IDLE" : "TIMEOUT", n);
    }
    print_status("after onload    :", *reg32(base, LAGD_CORE_OUTPUT_STATUS_REG_OFFSET));
    print_dbg("dbg before launch:", *reg32(base, LAGD_CORE_ENERGY_FIFO_DBG_0_REG_OFFSET));
    // NOTE: this is the CSR MIRROR, not the FIFO. ising_core_wrap.sv:402 updates it only on
    // cmpt_idle_posedge (or with the ctnus_* debug bits set), so before the first computation it
    // reads as whatever it was left at -- zeros. It does NOT mean the initial states are missing.
    printf("spin FIFO mirror before launch (stale until the first cmpt_idle posedge):\r\n");
    print_spin_fifo(CORE_TESTED);

    // ---- the step under investigation ---------------------------------------
    lagd_enable_energy_monitor_fifo(CORE_TESTED);
    lagd_enable_computation(CORE_TESTED);

    unsigned n_samples = 0;
    int completed = 0;
    for (; n_samples < MAX_SAMPLES; n_samples++) {
        uint32_t s = *reg32(base, LAGD_CORE_OUTPUT_STATUS_REG_OFFSET);
        uint32_t d = *reg32(base, LAGD_CORE_ENERGY_FIFO_DBG_0_REG_OFFSET);
        status_log[n_samples] = s;
        dbg_log[n_samples] = d;
        if ((s >> LAGD_CORE_OUTPUT_STATUS_CMPT_IDLE_BIT) & 1u) {
            completed = 1;
            n_samples++;
            break;
        }
    }

    printf("--- launch result ---\r\n");
    printf("completed=%s after %u samples%s\r\n", completed ? "YES" : "NO", n_samples,
           completed ? "" : " (sample buffer exhausted, still busy)");

    // Sticky OR: a handshake pulse seen in ANY sample shows up here, which a single read cannot do.
    uint32_t sticky_s = 0, sticky_d = 0;
    unsigned max_rx = 0;
    for (unsigned i = 0; i < n_samples; i++) {
        sticky_s |= status_log[i];
        sticky_d |= dbg_log[i];
        unsigned rx = (dbg_log[i] >> LAGD_CORE_ENERGY_FIFO_DBG_0_FM_RX_CNT_OFFSET) &
                      LAGD_CORE_ENERGY_FIFO_DBG_0_FM_RX_CNT_MASK;
        if (rx > max_rx) max_rx = rx;
    }
    print_status("sticky OR       :", sticky_s);
    print_dbg("sticky OR dbg   :", sticky_d);
    printf("max fm_rx_cnt seen: %u  (0 means the array never returned an energy)\r\n", max_rx);

    // Collapsed trace: only samples that differ from the previous one.
    printf("--- trace (distinct states, max %u) ---\r\n", (unsigned)MAX_TRACE_PRINT);
    unsigned shown = 0;
    for (unsigned i = 0; i < n_samples && shown < MAX_TRACE_PRINT; i++) {
        if (i && status_log[i] == status_log[i - 1] && dbg_log[i] == dbg_log[i - 1]) continue;
        printf("  [%5u] status=0x%08x dbg=0x%08x rx=%u\r\n", i, status_log[i], dbg_log[i],
               (dbg_log[i] >> LAGD_CORE_ENERGY_FIFO_DBG_0_FM_RX_CNT_OFFSET) &
                   LAGD_CORE_ENERGY_FIFO_DBG_0_FM_RX_CNT_MASK);
        shown++;
    }

    printf("--- readback ---\r\n");
    print_spin_fifo(CORE_TESTED);
    {
        // A result dominated by 1s with no dependence on the problem is what you get when the
        // accumulation lines are never meaningfully driven and the comparators' own bias decides --
        // the pull-up skew bias_review already measured. Counting is the cheapest way to spot it.
        unsigned ones_0 = 0, ones_1 = 0, diff_ref_0 = 0, diff_ref_1 = 0;
        for (int i = 0; i < NUM_SPIN / 32; i++) {
            uint32_t v0 = *reg32(base, LAGD_CORE_SPIN_FIFO_DATA_0_0_REG_OFFSET + 4 * i);
            uint32_t v1 = *reg32(base, LAGD_CORE_SPIN_FIFO_DATA_1_0_REG_OFFSET + 4 * i);
            uint32_t d0 = v0 ^ SC_SPIN_REF_0[i], d1 = v1 ^ SC_SPIN_REF_1[i];
            for (int b = 0; b < 32; b++) {
                ones_0 += (v0 >> b) & 1u;
                ones_1 += (v1 >> b) & 1u;
                diff_ref_0 += (d0 >> b) & 1u;
                diff_ref_1 += (d1 >> b) & 1u;
            }
        }
        printf("set 0: %u/%u ones, %u spins differ from the model reference\r\n", ones_0,
               (unsigned)NUM_SPIN, diff_ref_0);
        printf("set 1: %u/%u ones, %u spins differ from the model reference\r\n", ones_1,
               (unsigned)NUM_SPIN, diff_ref_1);
    }
    lagd_print_energy_fifo_data(CORE_TESTED);
    printf("cmpt_idx: %u\r\n", *reg32(base, LAGD_CORE_CMPT_IDX_REG_OFFSET));

    printf("=== DONE ===\r\n");
    uart_write_flush(&__base_uart);
    return 0;
}
