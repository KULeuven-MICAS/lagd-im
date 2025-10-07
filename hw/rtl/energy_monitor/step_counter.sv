// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Module description:
// Incrimental step counter.
//
// Parameters:
// - COUNTER_BITWIDTH: bit width of the counter
// - PIPES: number of pipeline stages

`include "../lib/registers.svh"

module step_counter #(
    parameter int COUNTER_BITWIDTH = $clog2(256)
    )(
    input logic clk_i,
    input logic rst_ni,
    input logic en_i,
    input logic load_i,
    input logic unsigned [COUNTER_BITWIDTH-1:0] d_i,
    input logic recount_en_i,
    input logic step_en_i,
    output logic unsigned [COUNTER_BITWIDTH-1:0] q_o,
    output logic finish_o
);
    // Internal signals
    logic finish;
    logic unsigned [COUNTER_BITWIDTH-1:0] counter_reg;
    logic unsigned [COUNTER_BITWIDTH-1:0] counter_next;

    assign counter_next = q_o + 1;

    assign finish = q_o == counter_reg;
    `FFL(finish_o, finish, en_i, {1'b0}, clk_i, rst_ni)

    // Sequential logic to set the counter target value
    `FFL(counter_reg, d_i, en_i && load_i, {COUNTER_BITWIDTH{1'b1}}, clk_i, rst_ni)

    // Sequential logic to update the counter register
    `FFLARNC(q_o, counter_next, en_i && step_en_i && (q_o != counter_reg), en_i && recount_en_i, 'd0, clk_i, rst_ni)

endmodule