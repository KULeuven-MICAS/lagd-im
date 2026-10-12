// Copyright 2026 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// lagd_scompute_debug in MULTI-COMPUTATION mode, instrumented for throughput and power.
//
// Separate from lagd_scompute_debug.spm.c, which stays byte-identical to main and cannot do this:
// it waits on CMPT_IDLE, which rises after EVERY computation. This waits on MULTI_CMPT_MODE_IDLE.
//
// STRUCTURE OF A RUN. The knobs below override lagd_reg_params.h, which holds the defaults.
// The computation count is DERIVED from RUN_SECONDS, so a pulse-length sweep keeps a constant
// run length -- same meter window, same thermal state, one variable changing.
//
//   run
//   +- computation           x derived from RUN_SECONDS, each RE-SEEDED from CONFIG_SPIN_INITIAL_*
//      +- icon               x ICONS_PER_CMPT, one proposed move (state XOR mask)
//         +- spin write      WRITE_CYCLES, candidate into the array
//         +- feedback pulse  PULSE_CYCLES, the array evaluating it
//
// So a computation is one full sweep of the move set, and multi mode repeats it as independent
// restarts keeping the best -- any spread between them is analog noise, not search.
//
// WHAT THE NUMBERS AT THE END ARE FOR. cycles/icon is the measured cost of one iteration and is
// what caps throughput; the printed split shows how much of it is the pulse (useful analog work)
// against the write phase and the synchronizer (pure overhead). duty is the driven fraction, so
// on a Galena-only supply rail it is what converts an averaged meter reading into array-active
// power. The two pull in opposite directions: longer pulses raise duty and lower throughput.

#ifndef CORE_TESTED
#define CORE_TESTED 0
#endif
// --- sweep knobs, all in plain cycles/seconds -------------------------------
// Target run length; the computation count is derived from it (min 1, no practical max)
#ifndef RUN_SECONDS
#define RUN_SECONDS 10
#endif
// Feedback pulse, cycles as driven (1..65536)
#ifndef PULSE_CYCLES
#define PULSE_CYCLES 10
#endif
// Spin write phase, cycles as driven (1..65536)
#ifndef WRITE_CYCLES
#define WRITE_CYCLES 1
#endif
// Synchronizer depth, cycles in transit (0..3; 0 bypasses, costs metastability margin)
#ifndef SYNC_PIPE
#define SYNC_PIPE 0
#endif
// Icons walked per computation (1..1024 = FLIP_ICON_DEPTH; small values measure restart cost)
#ifndef ICONS_PER_CMPT
#define ICONS_PER_CMPT 1024
#endif
// Model constants for the duration estimate, measured on this chip. They only affect how close
// the run lands to RUN_SECONDS -- every reported number is measured, not derived from these.
#ifndef EST_HANDSHAKE_CYCLES
#define EST_HANDSHAKE_CYCLES 1
#endif
#ifndef EST_RESTART_CYCLES
#define EST_RESTART_CYCLES 76
#endif
// Per-iteration energy logging.
#ifndef MONITOR
#define MONITOR 0
#endif
#ifndef MAX_SAMPLES
#define MAX_SAMPLES 2048
#endif
// Drive the feedback lines low before exiting.
#ifndef FLUSH_FEEDBACK
#define FLUSH_FEEDBACK 0
#endif
#ifndef FLUSH_TIMEOUT
#define FLUSH_TIMEOUT 2000000u
#endif

#include "regs/cheshire.h"
#include "dif/clint.h"
#include "dif/uart.h"
#include "dif/dma.h"
#include "params.h"
#include "util.h"
#include "printf.h"
// lagd_scompute.h must come before lagd_common.h
#include "lagd_scompute.h"
#include "lagd_common.h"
#include "lagd_debug_load.h"

// A knob of 0 where the CSR takes value-minus-one would underflow to a 65536-cycle phase.
#if PULSE_CYCLES < 1 || PULSE_CYCLES > 65536
#error "PULSE_CYCLES must be 1..65536"
#endif
#if WRITE_CYCLES < 1 || WRITE_CYCLES > 65536
#error "WRITE_CYCLES must be 1..65536"
#endif
#if SYNC_PIPE > 3
#error "SYNC_PIPE must be 0..3"
#endif
#if ICONS_PER_CMPT < 1 || ICONS_PER_CMPT > FLIP_ICON_DEPTH
#error "ICONS_PER_CMPT must be 1..FLIP_ICON_DEPTH"
#endif
#if RUN_SECONDS < 1
#error "RUN_SECONDS must be at least 1"
#endif

// Zero the feedback mask, pulse config_valid_aw so analog_rx reloads it, then run one computation
// so a complete cycle drives the line low. Zeroing the CSR alone does not: it only changes the
// source register, not the output.
static int flush_feedback_low(unsigned core) {
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
    const uint32_t idle = 1u << LAGD_CORE_OUTPUT_STATUS_CMPT_IDLE_BIT;

    for (unsigned i = 0; i < NUM_SPIN / 32; i++)
        *reg32(base, LAGD_CORE_SPIN_FEEDBACK_CFG_0_REG_OFFSET + 4 * i) = 0u;

    uint32_t cfg2 = *reg32(base, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET);
    cfg2 &= ~((1u << LAGD_CORE_GLOBAL_CFG_2_MULTI_CMPT_MODE_EN_BIT) |
              (1u << LAGD_CORE_GLOBAL_CFG_2_CMPT_EN_BIT) |
              (1u << LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_AW_BIT) |
              (1u << LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_FM_BIT));
    *reg32(base, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET) = cfg2;
    *reg32(base, LAGD_CORE_CMPT_MAX_NUM_REG_OFFSET) = 0u;

    cfg2 |= (1u << LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_AW_BIT) |
            (1u << LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_FM_BIT);
    *reg32(base, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET) = cfg2;
    *reg32(base, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET) =
        cfg2 | (1u << LAGD_CORE_GLOBAL_CFG_2_CMPT_EN_BIT);

    // Wait for busy first, then for retirement. Bounded: cleanup must never hang the program.
    for (uint32_t t = 0; t < FLUSH_TIMEOUT; t++)
        if ((*reg32(base, LAGD_CORE_OUTPUT_STATUS_REG_OFFSET) & idle) == 0) break;
    int timeout = 1;
    for (uint32_t t = 0; t < FLUSH_TIMEOUT; t++)
        if (*reg32(base, LAGD_CORE_OUTPUT_STATUS_REG_OFFSET) & idle) {
            timeout = 0;
            break;
        }

    *reg32(base, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET) = cfg2;
    return timeout;
}

int main(void) {
#if MONITOR
    static uint32_t log_buf[MAX_SAMPLES];
#endif
    uint32_t rtc_freq = *reg32(&__base_regs, CHESHIRE_RTC_FREQ_REG_OFFSET);
    uint64_t core_freq = clint_get_core_freq(rtc_freq, 2500);
    uart_init(&__base_uart, core_freq, __BOOT_BAUDRATE);

    // How many computations fit in RUN_SECONDS at these settings.
    uint32_t est_icon = (uint32_t)WRITE_CYCLES + (uint32_t)PULSE_CYCLES + (uint32_t)SYNC_PIPE +
                        (uint32_t)EST_HANDSHAKE_CYCLES;
    uint32_t est_cmpt = (uint32_t)ICONS_PER_CMPT * est_icon + (uint32_t)EST_RESTART_CYCLES;
    uint64_t want = ((uint64_t)RUN_SECONDS * core_freq) / est_cmpt;
    if (want < 1u) want = 1u;
    if (want > 0x100000000ull) want = 0x100000000ull;
    uint32_t cmpt_max = (uint32_t)(want - 1u);

    void *cfg = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)CORE_TESTED * IC_NUM_REGS);

    printf("=== SCOMPUTE MULTI ===\r\n");
    printf("core=%u  core_freq=%u Hz  monitor=%u\r\n", (unsigned)CORE_TESTED, (unsigned)core_freq,
           (unsigned)MONITOR);
    printf("--- settings (overridden here; lagd_reg_params.h holds the defaults) ---\r\n");
    printf("  feedback pulse : %-13u (PULSE_CYCLES)\r\n", (unsigned)PULSE_CYCLES);
    printf("  spin write     : %-13u (WRITE_CYCLES)\r\n", (unsigned)WRITE_CYCLES);
    printf("  synchronizer   : %-13u (SYNC_PIPE, cycles in transit)\r\n", (unsigned)SYNC_PIPE);
    printf("  icons/cmpt     : %-13u (ICONS_PER_CMPT)\r\n", (unsigned)ICONS_PER_CMPT);
    printf("  computations   : %-13u (derived: %u s at ~%u cycles/cmpt)\r\n",
           (unsigned)cmpt_max + 1u, (unsigned)RUN_SECONDS, (unsigned)est_cmpt);

    lagd_configure_initial_spins(CORE_TESTED);
    lagd_configure_cmpt_max_num(CORE_TESTED);
    lagd_configure_counters(CORE_TESTED);

    // Overrides MUST land before lagd_configure_global_cfg_2() below: it raises config_valid,
    // and the counters latch their limits on that edge. Written after, the CSRs change and the
    // hardware does not.
    *reg32(cfg, LAGD_CORE_CMPT_MAX_NUM_REG_OFFSET) = cmpt_max;
    {
        volatile uint32_t *c3 = (volatile uint32_t *)((uintptr_t)cfg +
                                                      LAGD_CORE_COUNTER_CFG_3_REG_OFFSET);
        *c3 = (*c3 & ~(uint32_t)LAGD_CORE_COUNTER_CFG_3_CYCLE_PER_SPIN_COMPUTE_MASK) |
              ((uint32_t)(PULSE_CYCLES - 1u) &
               (uint32_t)LAGD_CORE_COUNTER_CFG_3_CYCLE_PER_SPIN_COMPUTE_MASK);
        volatile uint32_t *c2 = (volatile uint32_t *)((uintptr_t)cfg +
                                                      LAGD_CORE_COUNTER_CFG_2_REG_OFFSET);
        *c2 = (*c2 & ~((uint32_t)LAGD_CORE_COUNTER_CFG_2_CYCLE_PER_SPIN_WRITE_MASK
                       << LAGD_CORE_COUNTER_CFG_2_CYCLE_PER_SPIN_WRITE_OFFSET)) |
              (((uint32_t)(WRITE_CYCLES - 1u) &
                (uint32_t)LAGD_CORE_COUNTER_CFG_2_CYCLE_PER_SPIN_WRITE_MASK)
               << LAGD_CORE_COUNTER_CFG_2_CYCLE_PER_SPIN_WRITE_OFFSET);
        volatile uint32_t *c4 = (volatile uint32_t *)((uintptr_t)cfg +
                                                      LAGD_CORE_COUNTER_CFG_4_REG_OFFSET);
        *c4 = (*c4 & ~((uint32_t)LAGD_CORE_COUNTER_CFG_4_ICON_LAST_RADDR_PLUS_ONE_MASK
                       << LAGD_CORE_COUNTER_CFG_4_ICON_LAST_RADDR_PLUS_ONE_OFFSET)) |
              (((uint32_t)ICONS_PER_CMPT &
                (uint32_t)LAGD_CORE_COUNTER_CFG_4_ICON_LAST_RADDR_PLUS_ONE_MASK)
               << LAGD_CORE_COUNTER_CFG_4_ICON_LAST_RADDR_PLUS_ONE_OFFSET);
    }
    lagd_configure_wwl_vdd_cfg(CORE_TESTED);
    lagd_configure_wwl_vread_cfg(CORE_TESTED);
    lagd_configure_spin_wwl_strobe(CORE_TESTED);
    lagd_configure_spin_feedback(CORE_TESTED);
    lagd_configure_h_rdata(CORE_TESTED);
    lagd_configure_global_cfg_1(CORE_TESTED);
    lagd_configure_global_cfg_2(CORE_TESTED);

    // The synchronizer depth lives in global_cfg_2, which the call above rewrites wholesale, so it
    // is re-applied here with its own config_valid_aw pulse -- analog_tx latches it on that edge.
    {
        uint32_t c = *reg32(cfg, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET);
        *reg32(cfg, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET) =
            c & ~(1u << LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_AW_BIT);
        c = (c & ~((uint32_t)LAGD_CORE_GLOBAL_CFG_2_SYNCHRONIZER_PIPE_NUM_MASK
                   << LAGD_CORE_GLOBAL_CFG_2_SYNCHRONIZER_PIPE_NUM_OFFSET)) |
            (((uint32_t)SYNC_PIPE & (uint32_t)LAGD_CORE_GLOBAL_CFG_2_SYNCHRONIZER_PIPE_NUM_MASK)
             << LAGD_CORE_GLOBAL_CFG_2_SYNCHRONIZER_PIPE_NUM_OFFSET);
        *reg32(cfg, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET) =
            c & ~(1u << LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_AW_BIT);
        *reg32(cfg, LAGD_CORE_GLOBAL_CFG_2_REG_OFFSET) =
            c | (1u << LAGD_CORE_GLOBAL_CFG_2_CONFIG_VALID_AW_BIT);
    }

    lagd_clear_config_valid(CORE_TESTED);

    if (debug_load_jh(CORE_TESTED)) {
        printf("J/h loading FAIL; computation skipped\r\n");
        uart_write_flush(&__base_uart);
        return 1;
    }
    printf("J/h write sequence done (readback unsupported)\r\n");
    lagd_print_spin_fifo_data(CORE_TESTED);

    uint64_t t0 = clint_get_mtime();
    lagd_enable_energy_monitor_fifo(CORE_TESTED);
    lagd_enable_computation_multi_cmpt_mode(CORE_TESTED);
#if MONITOR
    unsigned log_cnt = lagd_monitor_energy_fifo_dbg_0(CORE_TESTED, MAX_SAMPLES, log_buf);
#endif
    lagd_wait_for_computation_multi_cmpt_mode_done(CORE_TESTED);
    uint64_t elapsed = clint_get_mtime() - t0;

    // cmpt_idx steps once per completed computation and stops at cmpt_max_num; cycle_all_cmpt is
    // the engine's busy time. Everything below is derived from those two plus the settings.
    void *base = (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)CORE_TESTED * IC_NUM_REGS);
    uint32_t idx = *reg32(base, LAGD_CORE_CMPT_IDX_REG_OFFSET);
    uint64_t cycles = ((uint64_t)*reg32(base, LAGD_CORE_CYCLE_ALL_CMPT_MSB_REG_OFFSET) << 32) |
                      *reg32(base, LAGD_CORE_CYCLE_ALL_CMPT_LSB_REG_OFFSET);

    uint64_t ran = (uint64_t)idx + 1u;
    uint64_t icons = ran * (uint64_t)ICONS_PER_CMPT;
    uint64_t pulse = (uint64_t)PULSE_CYCLES;
    uint64_t write = (uint64_t)WRITE_CYCLES;
    uint64_t active = icons * pulse;                     // cycles the array is driven
    uint64_t per_icon_x100 = icons ? (cycles * 100u) / icons : 0u;

    printf("--- result ---\r\n");
    printf("elapsed   : %u ms   (gate the meter to this)\r\n",
           (unsigned)((elapsed * 1000u) / rtc_freq));
    printf("cmpt_idx  : %u of %u  -> %s\r\n", (unsigned)idx, (unsigned)cmpt_max,
           (idx == cmpt_max) ? "all computations ran" : "STOPPED EARLY");
    printf("icons     : %u in %u cycles\r\n", (unsigned)icons, (unsigned)cycles);

    // Throughput. "other" is what the configured phases do not account for: the spin synchronizer
    // (SYNC_PIPE cycles) and the handshake, PLUS the per-computation restart
    // amortised over
    // icons/cmpt. That restart is ~76 cycles, so it vanishes at 1024 icons/cmpt and dominates at
    // 1 -- if "other" is large, check icons/cmpt before blaming the pipeline.
    uint64_t per_cmpt_x100 = ran ? (cycles * 100u) / ran : 0u;
    uint64_t other_x100 = per_icon_x100 - (pulse + write) * 100u;
    printf("--- throughput ---\r\n");
    printf("cycles/cmpt: %u.%02u  over %u icons\r\n", (unsigned)(per_cmpt_x100 / 100u),
           (unsigned)(per_cmpt_x100 % 100u), (unsigned)ICONS_PER_CMPT);
    printf("cycles/icon: %u.%02u  = %u pulse + %u write + %u.%02u other\r\n",
           (unsigned)(per_icon_x100 / 100u), (unsigned)(per_icon_x100 % 100u), (unsigned)pulse,
           (unsigned)write, (unsigned)(other_x100 / 100u), (unsigned)(other_x100 % 100u));
#if ICONS_PER_CMPT < 64
    printf("             NOTE: at %u icons/cmpt the per-computation restart (~76 cycles) is\r\n"
           "             charged to almost every icon. Raise ICONS_PER_CMPT to\r\n"
           "             measure iteration cost rather than restart cost.\r\n",
           (unsigned)ICONS_PER_CMPT);
#endif
    printf("rate      : %u k icons/s\r\n",
           (unsigned)(cycles ? (icons * core_freq / cycles) / 1000u : 0u));

    // Driven fraction. On a Galena-only rail this is the divisor turning an averaged meter
    // reading into array-active power. Above 100% means the one-pulse-per-icon model is wrong.
    printf("duty      : %u.%u%% of the engine's busy cycles are array drive\r\n",
           (unsigned)(cycles ? (active * 1000u / cycles) / 10u : 0u),
           (unsigned)(cycles ? (active * 1000u / cycles) % 10u : 0u));

    printf("--- solution ---\r\n");
    lagd_print_energy_fifo_data(CORE_TESTED);
    lagd_print_spin_fifo_data(CORE_TESTED);
#if MONITOR
    lagd_print_energy_fifo_dbg(CORE_TESTED, log_cnt, log_buf);
#endif

#if FLUSH_FEEDBACK
    // Last: the extra computation would disturb the FIFOs printed above.
    if (flush_feedback_low(CORE_TESTED))
        printf("feedback flush TIMED OUT -- the array may be left driven\r\n");
    else
        printf("feedback flushed low\r\n");
#endif

    printf("=== DONE ===\r\n");
    uart_write_flush(&__base_uart);
    return 0;
}
