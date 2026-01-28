// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Priority arbiter
// Dependencies: relies on the module "onehot_to_bin" in pulp/common_cells

`include "common_cells/registers.svh"

module customized_arbiter #(
    parameter int unsigned NUM_REQ = 256,
    parameter int LSB_PRIORITY = 1,
    parameter int unsigned PIPES = 0 // only pipeline the upstream requests
) (
    input  logic clk_i,
    input  logic rst_ni,
    input  logic en_i,
    input  logic flush_i,
    input  logic req_valid_i,
    input  logic [NUM_REQ-1:0] req_i,
    output logic               idx_valid_o,
    output logic [NUM_REQ-1:0] grant_o,
    output logic [$clog2(NUM_REQ)-1:0] idx_o,
    output logic               empty_o
);
    logic [PIPES:0] [NUM_REQ-1:0] req_pipe;
    logic [PIPES:0] req_valid_pipe;
    logic [NUM_REQ-1:0] req_temp;
    logic [NUM_REQ-1:0] grant_temp;
    genvar i;

    assign req_valid_pipe[0] = req_valid_i;
    assign req_pipe[0] = req_temp;
    assign idx_valid_o = ~empty_o & req_valid_pipe[PIPES];
    assign empty_o = !(|req_pipe[PIPES]);
    assign grant_temp = req_pipe[PIPES] & ((~req_pipe[PIPES]) + 1); // LSB priority encoder

    if (LSB_PRIORITY) begin
        assign req_temp = req_i;
        assign grant_o = grant_temp;
    end else begin: flip_input
        for (i = 0; i < NUM_REQ; i++) begin
            assign req_temp[i] = req_i[NUM_REQ - 1 - i];
            assign grant_o[i] = grant_temp[NUM_REQ - 1 - i];
        end
    end

    // Pipeline input requests
    generate
        if (PIPES > 0) begin : gen_pipes
            for (i = 1; i < PIPES; i++) begin
                `FFLARNC(req_pipe[i], req_pipe[i-1], en_i, flush_i, 1'b0, clk_i, rst_ni);
                `FFLARNC(req_valid_pipe[i], req_valid_pipe[i-1], en_i, flush_i, 1'b0, clk_i, rst_ni);
            end
        end
    endgenerate

    // one-hot to index
    onehot_to_bin #(
        .ONEHOT_WIDTH ( NUM_REQ )
    ) i_onehot_to_bin (
        .onehot (grant_o),
        .bin    (idx_o)
    );

endmodule