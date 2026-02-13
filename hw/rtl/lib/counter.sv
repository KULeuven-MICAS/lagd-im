// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Module description:
// Generic counter module with load and step functionality.

// Parameters:
// - WIDTH: bit width of the counter

// Port definitions:
// - clk_i: input clock signal
// - rst_ni: asynchronous reset, active low
// - clear_i: synchronous clear signal, active high
// - en_i: enable signal for counting
// - step_i: step value for incrementing the counter
// - init_i: initial value to load into the counter
// - max_i: maximum count value before resetting to initial value
// - load_i: load enable signal for loading the counter with init_i
// - d_i: data input for loading the counter when load_i is high
// - count_o: current count value output
// - tc: terminal count output, goes high when count_o reaches max_i

`include "common_cells/registers.svh"

module counter #(
    parameter int WIDTH = 8
)(
    input logic clk_i,
    input logic rst_ni,
    input logic clear_i,
    input logic en_i,
    input logic unsigned [WIDTH-1:0] step_i,
    input logic unsigned [WIDTH-1:0] init_i,
    input logic unsigned [WIDTH-1:0] max_i,
    input logic load_i,
    input logic unsigned [WIDTH-1:0] d_i,
    output logic unsigned [WIDTH-1:0] count_o,
    output logic tc
);

    logic unsigned [WIDTH-1:0] count_q;
    logic unsigned [WIDTH-1:0] count_d;

    // Counter logic
    always_comb begin
        if (load_i) begin
            count_d = d_i; // Load the counter with the input value
        end else if (en_i) begin
            if (tc) begin
                count_d = init_i; // Reset to initial value if terminal count is reached
            end else begin
                count_d = count_q + step_i; // Increment the counter by the step value
            end
        end else begin
            count_d = count_q; // Hold the current value
        end
    end
    `FFLARNC(count_q, count_d, en_i, clear_i, init_i, clk_i, rst_ni)

    // Terminal count logic
    assign tc = (count_q == max_i) ? 1'b1 : 1'b0;
    assign count_o = count_q;
endmodule
