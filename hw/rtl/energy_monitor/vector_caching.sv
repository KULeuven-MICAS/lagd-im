// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Module description:
// Vector data caching module.
//
// Parameters:
// - DATAWIDTH: data width

`include "common_cells/registers.svh"

module vector_caching #(
    parameter int DATAWIDTH = 256
) (
    input logic clk_i,
    input logic rst_ni,
    input logic en_i,
    input logic data_valid_i,
    input logic [DATAWIDTH-1:0] data_i,
    output logic [DATAWIDTH-1:0] data_o
);
    logic [DATAWIDTH-1:0] data_cached;
    logic data_handshake;
    assign data_handshake = en_i & data_valid_i;
    assign data_o = (data_handshake) ? data_i : data_cached;

    `FFLARNC(data_cached, data_i, data_handshake, !en_i, 'd0, clk_i, rst_ni)

endmodule