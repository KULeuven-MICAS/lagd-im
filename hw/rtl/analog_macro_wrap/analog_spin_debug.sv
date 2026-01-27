// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Analog debugging module for spin writing and reading.

`include "common_cells/registers.svh"

module analog_spin_debug #(
    parameter integer NUM_SPIN = 256,
    parameter integer BITDATA = 4,
    parameter integer COUNTER_BITWIDTH = 16
)(
    input logic clk_i,
    input logic rst_ni,
    input logic en_i,
    // config interface
    input  logic configure_enable_i,
    input  logic [COUNTER_BITWIDTH-1:0] cycle_per_spin_write_i,
    input  logic [COUNTER_BITWIDTH-1:0] cycle_per_spin_compute_i,
    input  logic [COUNTER_BITWIDTH-1:0] cycle_per_spin_read_i,
    input  logic [COUNTER_BITWIDTH-1:0] spin_read_num_i,
    input  logic [NUM_SPIN-1:0] spin_wwl_strobe_i,
    input  logic [NUM_SPIN-1:0] spin_feedback_i,
    // debug interface <-> digital
    input  logic debug_wen_i,
    input  logic debug_feedback_en_i,
    input  logic debug_ren_i,
    input  logic [NUM_SPIN*BITDATA-1:0] wbl_spin_i,
    output logic [NUM_SPIN*BITDATA-1:0] wbl_spin_o,
    output logic [NUM_SPIN*BITDATA-1:0] wblb_spin_o,
    output logic debug_ren_sync_en_o,
    // debug interface <-> analog
    output logic [NUM_SPIN-1:0] spin_wwl_o,
    output logic [NUM_SPIN-1:0] spin_feedback_o,
    // status
    output logic debug_spin_idle_o,
    output logic debug_spin_w_idle_o,
    output logic debug_spin_feedback_idle_o,
    output logic debug_spin_r_idle_o
);
    // Internal signals
    logic wwl_high_counter_overflow;
    logic wwl_high_counter_en;
    logic wwl_high_counter_maxed;
    logic debug_spin_write_idle_cond;
    logic w_busy_status;
    logic r_busy_status;
    logic feedback_busy_status;
    logic debug_en_comb;
    logic busy_status_comb;
    logic debug_ren_comb;
    logic debug_wen_comb;
    logic debug_feedback_en_comb;
    logic config_cond;
    logic [NUM_SPIN-1:0] spin_wwl_strobe_reg;
    logic [NUM_SPIN-1:0] spin_feedback_reg;
    logic cmpt_counter_en;
    logic cmpt_counter_maxed;
    logic cmpt_counter_overflow;
    logic read_counter_maxed;
    logic read_counter_overflow;
    logic read_num_counter_maxed;
    logic read_num_counter_overflow;
    logic debug_spin_read_idle_cond;
    logic [NUM_SPIN*BITDATA-1:0] wbl_spin_reg;

    // config
    assign config_cond = en_i & configure_enable_i;

    // control logic
    assign debug_en_comb = debug_wen_comb | debug_ren_comb | debug_feedback_en_comb;
    assign busy_status_comb = w_busy_status | r_busy_status | feedback_busy_status;
    assign debug_wen_comb = busy_status_comb ? 1'b0 : debug_wen_i;
    assign debug_feedback_en_comb = (busy_status_comb | debug_wen_i) ? 1'b0 : debug_feedback_en_i;
    assign debug_ren_comb = (busy_status_comb | debug_wen_i | debug_feedback_en_i) ? 1'b0 : debug_ren_i;

    assign debug_spin_write_idle_cond = !en_i | wwl_high_counter_maxed;
    assign debug_spin_feedback_idle_cond = !en_i | cmpt_counter_maxed;
    assign debug_spin_read_idle_cond = !en_i | read_num_counter_overflow;

    // status signals
    assign debug_spin_idle_o = ~busy_status_comb;
    assign debug_spin_w_idle_o = ~w_busy_status;
    assign debug_spin_feedback_idle_o = ~feedback_busy_status;
    assign debug_spin_r_idle_o = ~r_busy_status;

    assign debug_ren_sync_en_o = read_counter_maxed & ~read_counter_overflow;

    // data path
    assign spin_wwl_o = w_busy_status ? spin_wwl_strobe_reg : 'd0;
    assign spin_feedback_o = (feedback_busy_status | r_busy_status) ? spin_feedback_reg : 'd0;
    assign wbl_spin_o = w_busy_status ? wbl_spin_reg : 'd0;
    assign wblb_spin_o = 'd0;

    `FFLARNC(w_busy_status, 1'b1, (en_i & debug_wen_comb), debug_spin_write_idle_cond, 1'b0, clk_i, rst_ni)
    `FFLARNC(feedback_busy_status, 1'b1, (en_i & debug_feedback_en_comb), debug_spin_feedback_idle_cond, 1'b0, clk_i, rst_ni)
    `FFLARNC(r_busy_status, 1'b1, (en_i & debug_ren_comb), debug_spin_read_idle_cond, 1'b0, clk_i, rst_ni)

    // configure registers
    `FFL(spin_wwl_strobe_reg, spin_wwl_strobe_i, config_cond, 'd0, clk_i, rst_ni)
    `FFL(spin_feedback_reg, spin_feedback_i, config_cond, 'd0, clk_i, rst_ni)
    `FFL(wbl_spin_reg, wbl_spin_i, config_cond, 'd0, clk_i, rst_ni)

    // counter for spin write
    step_counter #(
        .COUNTER_BITWIDTH (COUNTER_BITWIDTH),
        .PARALLELISM (1)
    ) i_wwl_high_counter (
        .clk_i (clk_i),
        .rst_ni (rst_ni),
        .en_i (en_i),
        .load_i (configure_enable_i),
        .d_i (cycle_per_spin_write_i),
        .recount_en_i (debug_wen_comb | wwl_high_counter_maxed),
        .step_en_i (w_busy_status),
        .q_o (),
        .maxed_o (wwl_high_counter_maxed),
        .overflow_o (wwl_high_counter_overflow)
    );

    // counter for spin feedback
    step_counter #(
        .COUNTER_BITWIDTH (COUNTER_BITWIDTH),
        .PARALLELISM (1)
    ) i_cmpt_counter (
        .clk_i (clk_i),
        .rst_ni (rst_ni),
        .en_i (en_i),
        .load_i (configure_enable_i),
        .d_i (cycle_per_spin_compute_i),
        .recount_en_i (debug_feedback_en_comb | cmpt_counter_maxed),
        .step_en_i (feedback_busy_status),
        .q_o (),
        .maxed_o (cmpt_counter_maxed),
        .overflow_o (cmpt_counter_overflow)
    );

    // counter for spin read cycles
    step_counter #(
        .COUNTER_BITWIDTH (COUNTER_BITWIDTH),
        .PARALLELISM (1)
    ) i_read_counter (
        .clk_i (clk_i),
        .rst_ni (rst_ni),
        .en_i (en_i),
        .load_i (configure_enable_i),
        .d_i (cycle_per_spin_read_i),
        .recount_en_i (debug_ren_comb | read_counter_maxed),
        .step_en_i (r_busy_status),
        .q_o (),
        .maxed_o (read_counter_maxed),
        .overflow_o (read_counter_overflow)
    );

    // counter for spin read numbers
    step_counter #(
        .COUNTER_BITWIDTH (COUNTER_BITWIDTH),
        .PARALLELISM (1)
    ) i_read_num_counter (
        .clk_i (clk_i),
        .rst_ni (rst_ni),
        .en_i (en_i),
        .load_i (configure_enable_i),
        .d_i (spin_read_num_i),
        .recount_en_i (debug_ren_comb | read_num_counter_overflow),
        .step_en_i (r_busy_status & read_counter_maxed),
        .q_o (),
        .maxed_o (read_num_counter_maxed),
        .overflow_o (read_num_counter_overflow)
    );

endmodule