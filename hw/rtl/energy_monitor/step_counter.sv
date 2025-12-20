// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Module description:
// Incremental step counter. q_o increases and stays at the target value until recount_en_i is asserted.
//
// Parameters:
// - COUNTER_BITWIDTH: bit width of the counter
//
// Port definitions:
// - clk_i: input clock signal
// - rst_ni: asynchronous reset, active low
// - en_i: module enable signal
// - load_i: load enable signal
// - d_i: data input for loading the counter
// - recount_en_i: recount enable signal
// - step_en_i: step enable signal
// - q_o: counter output
// - last_o: last signal, goes high when the counter reaches the target value
// - finish_o: finish signal, remains high when the counter reaches the target value + 1
//
// Case tested:
// - None

`include "common_cells/registers.svh"

module step_counter #(
    parameter int COUNTER_BITWIDTH = $clog2(256),
    parameter int PARALLELISM = 4
    )(
    input logic clk_i,
    input logic rst_ni,
    input logic en_i,
    input logic load_i,
    input logic unsigned [COUNTER_BITWIDTH-1:0] d_i,
    input logic recount_en_i,
    input logic step_en_i,
    output logic unsigned [COUNTER_BITWIDTH-1:0] q_o,
    output logic overflow_o
);
    // Internal signals
    logic overflow;
    logic finish;
    logic unsigned [COUNTER_BITWIDTH-1:0] counter_reg;
    logic unsigned [COUNTER_BITWIDTH-1:0] counter_n;
    logic load_cond;
    logic step_cond;
    logic overflow_cond;
    logic recount_cond;

    assign counter_n = q_o + PARALLELISM;
    assign load_cond = en_i && load_i;
    assign step_cond = en_i && step_en_i && (q_o != counter_reg);
    assign overflow_cond = en_i && step_en_i && (q_o == (counter_reg - PARALLELISM + 1));
    assign recount_cond = en_i && recount_en_i;

    assign overflow_o = overflow;

    // Sequential logic to set the counter target value
    `FFL(counter_reg, d_i, load_cond, {COUNTER_BITWIDTH{1'b1}}, clk_i, rst_ni)

    // Sequential logic to update the counter register
    `FFLARNC(q_o, counter_n, step_cond, recount_cond, 'd0, clk_i, rst_ni)
    `FFLARNC(overflow, 1'b1, overflow_cond, recount_cond, 'd0, clk_i, rst_ni)

endmodule