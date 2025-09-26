// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Module description:
// Sequential accumulator for signed number
//
// Parameters:
// -N: number of inputs
// -DATAW: bit width of each input

module accumulator #(
    parameter int IN_WIDTH = 16, // bit width of input
    parameter int ACCUM_WIDTH = 32, // bit width of the accumulator
)(
    input logic clk_i, // input clock signal
    input logic rst_ni, // asynchornous reset, active low
    input logic en_i, // enable signal
    input logic clear_i, // clear signal
    input logic valid_i, // input valid signal
    input logic signed [IN_WIDTH-1:0] data_i, // input data
    output logic signed [OUT_WIDTH-1:0] accum_o, // output accumulated value
    output logic overflow_o, // overflow flag
    output logic valid_o // output valid signal
);

    // Internal signals
    logic signed [ACCUM_WIDTH-1:0] accum_reg; // register to hold the accumulated value
    logic signed [ACCUM_WIDTH-1:0] accum_next; // next value of the accumulator

    // Combinational logic to compute the next value of the accumulator
    always_comb begin
        if (clear_i) begin
            accum_next = '0; // clear the accumulator
        end else if (en_i && valid_i) begin
            accum_next = accum_reg + data_i; // accumulate the input data
        end else begin
            accum_next = accum_reg; // hold the current value
        end
    end

    // Sequential logic to update the accumulator register
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            accum_reg <= '0; // reset the accumulator
        end else begin
            accum_reg <= accum_next; // update the accumulator
        end
    end

    // Output assignments
    assign accum_o = accum_reg; // output the accumulated value
    assign overflow_o = (accum_next > $signed({1'b0, {ACCUM_WIDTH-1{1'b1}}})) || (accum_next < $signed({1'b1, {ACCUM_WIDTH-1{1'b0}}})); // check for overflow
    assign valid_o = valid_i; // propagate the valid signal

endmodule