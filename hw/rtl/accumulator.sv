// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Module description:
// Sequential accumulator for signed number
//
// Parameters:
// -IN_WIDTH: bit width of input
// -ACCUM_WIDTH: bit width of the accumulator

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
    logic overflow; // overflow flag
    logic data_valid; // output data valid signal
    logic overflow_reg; // registered overflow flag
    logic data_valid_reg; // registered data valid signal

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

    assign overflow = (en_i && valid_i && !clear_i) && 
            ((accum_reg[ACCUM_WIDTH-1] == $signed(data_i[ACCUM_WIDTH-1])) && 
                (accum_next[ACCUM_WIDTH-1] != accum_reg[ACCUM_WIDTH-1])); // check for overflow
    assign data_valid = en_i && valid_i && !clear_i;

    // Output assignments
    assign accum_o = accum_reg; // output the accumulated value
    assign overflow_o = overflow_reg; // output the overflow flag
    assign valid_o = data_valid_reg; // output the valid signal

    // Sequential logic
    `FFL(.__q(accum_reg), .__d(accum_next), .__load(en_i || clear_i), .__reset_value('0), .__clk(clk_i), .__arst_n(rst_ni))
    `FFL(.__q(overflow_reg), .__d(overflow), .__load(en_i || clear_i), .__reset_value('0), .__clk(clk_i), .__arst_n(rst_ni))
    `FFL(.__q(data_valid_reg), .__d(data_valid), .__load(en_i || clear_i), .__reset_value('0), .__clk(clk_i), .__arst_n(rst_ni))

endmodule