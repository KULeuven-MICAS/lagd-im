// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Analog debugging module for j/h writing

`include "common_cells/registers.svh"

module debug_analog_dt_write #(
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
    input  logic debug_en_i,
    input  logic [NUM_SPIN-1:0] debug_j_one_hot_wwl_i,
    input  logic debug_h_wwl_i,
    input  logic [NUM_SPIN*BITDATA-1:0] debug_rdata_i,
    // debug interface <-> analog
    output logic [NUM_SPIN-1:0] j_one_hot_wwl_o,
    output logic h_wwl_o,
    output logic [NUM_SPIN*BITDATA-1:0] wbl_o,
    // status
    output logic debug_dt_write_idle_o
);
    // Internal signals
    logic [COUNTER_BITWIDTH-1:0] wwl_high_counter_q, wwl_low_counter_q;
    logic wwl_high_counter_overflow, wwl_low_counter_overflow;
    logic wwl_high_counter_en, wwl_low_counter_en;
    logic wwl_high_counter_maxed, wwl_low_counter_maxed;
    logic debug_dt_write_idle_cond;
    logic busy_status;

    assign wwl_high_counter_en_cond = en_i & debug_en_i;
    assign wwl_low_counter_en_cond = en_i & wwl_high_counter_maxed;
    assign debug_dt_write_idle_cond = !en_i | wwl_low_counter_maxed;
    assign debug_dt_write_idle_o = ~busy_status;

    `FFLARNC(busy_status, 1'b1, wwl_high_counter_en_cond, debug_dt_write_idle_cond, 1'b0, clk_i, rst_ni)
    `FFLARNC(wwl_high_counter_en, 1'b1, wwl_high_counter_en_cond, wwl_high_counter_maxed, 1'b0, clk_i, rst_ni)
    `FFLARNC(wwl_low_counter_en, 1'b1, wwl_low_counter_en_cond, wwl_low_counter_maxed, 1'b0, clk_i, rst_ni)
    `FFLARNC(j_one_hot_wwl_o, debug_j_one_hot_wwl_i, wwl_high_counter_en_cond, wwl_high_counter_maxed, 'd0, clk_i, rst_ni)
    `FFLARNC(h_wwl_o, debug_h_wwl_i, wwl_high_counter_en_cond, wwl_high_counter_maxed, 'd0, clk_i, rst_ni)
    `FFLARNC(wbl_o, debug_rdata_i, wwl_high_counter_en_cond, wwl_low_counter_maxed, 'd0, clk_i, rst_ni)

    step_counter #(
        .COUNTER_BITWIDTH (COUNTER_BITWIDTH),
        .PARALLELISM (1)
    ) i_wwl_high_counter (
        .clk_i (clk_i),
        .rst_ni (rst_ni),
        .en_i (en_i),
        .load_i (configure_enable_i),
        .d_i (cycle_per_wwl_high_i),
        .recount_en_i (debug_en_i | wwl_high_counter_overflow),
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
        .recount_en_i (debug_en_i | wwl_low_counter_overflow),
        .step_en_i (wwl_low_counter_en),
        .q_o (wwl_low_counter_q),
        .maxed_o (wwl_low_counter_maxed),
        .overflow_o (wwl_low_counter_overflow)
    );

endmodule