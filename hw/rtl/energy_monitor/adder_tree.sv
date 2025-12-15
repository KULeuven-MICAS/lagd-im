// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Module description:
// Adder tree to sum up N inputs
//
// Parameters:
// -N: number of inputs
// -DATAW: bit width of each input
// -PIPES: number of pipeline stages
// -OUT_WIDTH: bit width of the output
// -IN_WIDTH: total input width

`include "common_cells/registers.svh"

module adder_tree #(
    parameter int N = 256,
    parameter int DATAW = 8,
    parameter int PIPES = 0,
    parameter int OUT_WIDTH = $clog2(N) + DATAW,
    parameter int IN_WIDTH = N * DATAW
)(
    input logic clk_i,
    input logic rst_ni,
    input logic en_i,
    input logic data_valid_i,
    input logic [IN_WIDTH-1:0] data_i,
    output logic signed [OUT_WIDTH-1:0] sum_o
);
    localparam int STAGES = $clog2(N); // number of stages
    logic signed [STAGES:0][N-1:0][DATAW+$clog2(N)-1:0] stage_data; // data at each stage

    // Generate variables
    genvar i, j;

    // Assign input data to stage 0
    generate
        for (i = 0; i < N; i++) begin : gen_input_unpack
            assign stage_data[0][i] = $signed(data_i[i*DATAW +: DATAW]);
        end
    endgenerate

    // Generate adder tree
    generate
        for (i = 0; i < STAGES; i++) begin : gen_stages
            for (j = 0; j < (N >> (i + 1)); j++) begin : gen_adders
                assign stage_data[i+1][j] = stage_data[i][2*j] + stage_data[i][2*j + 1];
            end
        end
    endgenerate

    // Sum pipeline registers
    bp_pipe #(
        .DATAW(OUT_WIDTH),
        .PIPES(PIPES)
    ) u_pipe_sum (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .data_i(stage_data[STAGES][0]),
        .data_o(sum_o),
        .valid_i(data_valid_i),
        .valid_o(),
        .ready_i(1'b1),
        .ready_o()
    );

endmodule