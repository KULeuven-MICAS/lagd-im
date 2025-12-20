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
//
// Port definitions:
// - clk_i: input clock signal
// - rst_ni: asynchornous reset, active low
// - en_i: enable signal for the accumulator
// - clear_i: clear signal for the accumulator
// - valid_i: input valid signal
// - data_i: input data to be accumulated
// - accum_o: output accumulated value
// - overflow_o: overflow flag
// - valid_o: output valid signal
//
// Case tested:
// - None

`include "common_cells/registers.svh"
`include "../include/lagd_platform.svh"

module accumulator #(
    parameter int IN_WIDTH = 16,
    parameter int ACCUM_WIDTH = 32
)(
    input logic clk_i,
    input logic rst_ni,
    input logic en_i,
    input logic clear_i,
    input logic valid_i,
    input logic signed [IN_WIDTH-1:0] data_i,
    output logic signed [ACCUM_WIDTH-1:0] accum_o,
    output logic overflow_o,
    output logic valid_o
);

    // Internal signals
    logic signed [ACCUM_WIDTH-1:0] accum_reg; // register to hold the accumulated value
    logic signed [ACCUM_WIDTH-1:0] accum_n; // next value of the accumulator
    logic overflow; // overflow flag
    logic data_valid; // output data valid signal
    logic overflow_reg; // registered overflow flag
    logic data_valid_reg; // registered data valid signal

    // Combinational logic to compute the next value of the accumulator
    always_comb begin
        if (en_i && valid_i) begin
            accum_n = accum_reg + data_i; // accumulate the input data
        end else begin
            accum_n = accum_reg; // hold the current value
        end
    end

    // Overflow for signed addition: occurs when operands have the same sign
    // and the result's sign is different. Compare sign bits directly.
    assign overflow = (en_i && valid_i && !clear_i) && 
            ((accum_reg[ACCUM_WIDTH-1] == data_i[IN_WIDTH-1]) && 
                (accum_n[ACCUM_WIDTH-1] != accum_reg[ACCUM_WIDTH-1])); // check for overflow
    assign data_valid = en_i && valid_i && !clear_i;

    // Output assignments
    assign accum_o = accum_reg;
    assign overflow_o = overflow_reg;
    assign valid_o = data_valid_reg;

    // Sequential logic
    `FFLARNC(accum_reg, accum_n, en_i, clear_i, '0, clk_i, rst_ni)
    `FFLARNC(overflow_reg, overflow, en_i, clear_i, '0, clk_i, rst_ni)
    `FFLARNC(data_valid_reg, data_valid, en_i, clear_i, '0, clk_i, rst_ni)

// Assertions
`RUNTIME_ASSERT(overflow_reg === 1'b0, "Accumulator overflow occurred", clk_i, rst_ni)

endmodule