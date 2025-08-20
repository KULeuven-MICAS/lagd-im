// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>
//
// Module description:
// 2s complement adder that applies saturated value on overflow
//
// Parameters:
// - DATAW: number of bits of the input data

module adder #(
    parameter int DATAW = 32
)(
    input logic signed [DATAW-1:0] a,
    input logic signed [DATAW-1:0] b,
    output logic signed [DATAW-1:0] sum
);
    logic ovf_positive;
    logic ovf_negative;
    logic signed [DATAW:0] sum_temp;

    assign sum_temp = a + b;
    assign ovf_positive = (a[DATAW-1] == 0 && b[DATAW-1] == 0 && sum_temp[DATAW-1] == 1);
    assign ovf_negative = (a[DATAW-1] == 1 && b[DATAW-1] == 1 && sum_temp[DATAW-1] == 0);

    always_comb begin
        if (ovf_positive) begin
            sum = {1'b0, {DATAW-1{1'b1}}}; // Saturate to max positive value
        end else if (ovf_negative) begin
            sum = {1'b1, {DATAW-1{1'b0}}}; // Saturate to max negative value
        end else begin
            sum = sum_temp[DATAW-1:0]; // No overflow, normal addition
        end
    end
endmodule
