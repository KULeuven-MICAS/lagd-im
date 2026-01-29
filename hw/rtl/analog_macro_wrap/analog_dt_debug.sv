// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Analog debugging module for j/h writing and reading.

`include "common_cells/registers.svh"

module analog_dt_debug #(
    parameter integer NUM_SPIN = 256,
    parameter integer BITDATA = 4,
    parameter integer COUNTER_BITWIDTH = 16
)(
    input logic clk_i,
    input logic rst_ni,
    input logic en_i,
    // config interface
    input  logic configure_enable_i,
    input  logic [COUNTER_BITWIDTH-1:0] cycle_per_wwl_high_i,
    input  logic [COUNTER_BITWIDTH-1:0] cycle_per_wwl_low_i,
    // debug interface <-> digital
    input  logic debug_wen_i,
    input  logic debug_ren_i,
    input  logic [NUM_SPIN-1:0] debug_j_one_hot_wwl_i,
    input  logic debug_h_wwl_i,
    input  logic [NUM_SPIN*BITDATA-1:0] wbl_dt_i,
    output logic debug_dt_sync_en_o,
    // debug interface <-> analog
    output logic [NUM_SPIN-1:0] j_one_hot_wwl_o,
    output logic h_wwl_o,
    output logic [NUM_SPIN*BITDATA-1:0] wbl_o,
    // status
    output logic debug_dt_idle_o,
    output logic debug_dt_w_idle_o,
    output logic debug_dt_r_idle_o
);
    // Internal signals
    logic [COUNTER_BITWIDTH-1:0] wwl_high_counter_q, wwl_low_counter_q;
    logic wwl_high_counter_overflow, wwl_low_counter_overflow;
    logic wwl_high_counter_en, wwl_low_counter_en;
    logic wwl_high_counter_maxed, wwl_low_counter_maxed;
    logic debug_dt_write_idle_cond;
    logic w_busy_status;
    logic r_busy_status;
    logic debug_en_comb;
    logic busy_status_comb;
    logic debug_ren_comb;
    logic debug_wen_comb;
    logic [NUM_SPIN*BITDATA-1:0] wbl_dt_reg;
    logic wwl_high_counter_en_cond;
    logic wwl_low_counter_en_cond;

    assign debug_en_comb = debug_wen_comb | debug_ren_comb;
    assign busy_status_comb = w_busy_status | r_busy_status;
    assign debug_wen_comb = busy_status_comb ? 1'b0 : debug_wen_i;
    assign debug_ren_comb = (busy_status_comb | debug_wen_i) ? 1'b0 : debug_ren_i;

    assign wwl_high_counter_en_cond = en_i & debug_en_comb;
    assign wwl_low_counter_en_cond = en_i & wwl_high_counter_maxed;
    assign debug_dt_write_idle_cond = !en_i | wwl_low_counter_maxed;
    assign debug_dt_idle_o = ~busy_status_comb;
    assign debug_dt_w_idle_o = ~w_busy_status;
    assign debug_dt_r_idle_o = ~r_busy_status;
    assign debug_dt_sync_en_o = r_busy_status & wwl_high_counter_maxed;

    `FFLARNC(w_busy_status, 1'b1, (en_i & debug_wen_comb), debug_dt_write_idle_cond, 1'b0, clk_i, rst_ni)
    `FFLARNC(r_busy_status, 1'b1, (en_i & debug_ren_comb), debug_dt_write_idle_cond, 1'b0, clk_i, rst_ni)
    `FFLARNC(wwl_high_counter_en, 1'b1, wwl_high_counter_en_cond, wwl_high_counter_maxed, 1'b0, clk_i, rst_ni)
    `FFLARNC(wwl_low_counter_en, 1'b1, wwl_low_counter_en_cond, wwl_low_counter_maxed, 1'b0, clk_i, rst_ni)
    `FFLARNC(j_one_hot_wwl_o, debug_j_one_hot_wwl_i, wwl_high_counter_en_cond, wwl_high_counter_maxed, 'd0, clk_i, rst_ni)
    `FFLARNC(h_wwl_o, debug_h_wwl_i, wwl_high_counter_en_cond, wwl_high_counter_maxed, 'd0, clk_i, rst_ni)
    `FFLARNC(wbl_o, wbl_dt_reg, (en_i & debug_wen_comb), wwl_low_counter_maxed, 'd0, clk_i, rst_ni)

    // config
    `FFLARNC(wbl_dt_reg, wbl_dt_i, configure_enable_i, wwl_low_counter_maxed, 'd0, clk_i, rst_ni)

    step_counter #(
        .COUNTER_BITWIDTH (COUNTER_BITWIDTH),
        .PARALLELISM (1)
    ) i_wwl_high_counter (
        .clk_i (clk_i),
        .rst_ni (rst_ni),
        .en_i (en_i),
        .load_i (configure_enable_i),
        .d_i (cycle_per_wwl_high_i),
        .recount_en_i (debug_en_comb | wwl_high_counter_overflow),
        .step_en_i (wwl_high_counter_en),
        .q_o (wwl_high_counter_q),
        .maxed_o (wwl_high_counter_maxed),
        .overflow_o (wwl_high_counter_overflow)
    );

    step_counter #(
        .COUNTER_BITWIDTH (COUNTER_BITWIDTH),
        .PARALLELISM (1)
    ) i_wwl_low_counter (
        .clk_i (clk_i),
        .rst_ni (rst_ni),
        .en_i (en_i),
        .load_i (configure_enable_i),
        .d_i (cycle_per_wwl_low_i),
        .recount_en_i (debug_en_comb | wwl_low_counter_overflow),
        .step_en_i (wwl_low_counter_en),
        .q_o (wwl_low_counter_q),
        .maxed_o (wwl_low_counter_maxed),
        .overflow_o (wwl_low_counter_overflow)
    );

endmodule