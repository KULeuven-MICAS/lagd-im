// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Module description:
//
// mem_to_handshake_fifo
// Maintains a FIFO to buffer data read from memory and exposes a handshake interface to downstream
// 
// Parameters:
// - DEPTH       : number of entries in the FIFO
// - ADDR_WIDTH  : width of usage / address output (derived from DEPTH)
// - DATA_WIDTH  : bit width of each data entry
//
// Ports:
// - clk_i, rst_ni : clock and asynchronous active-low reset
// - en_i          : module enable
// - flush_i       : flush FIFO and related state
// - addr_upper_bound_i: upper bound address for memory read (inclusive)
// - mem_ren_o     : memory read enable output
// - mem_raddr_o   : memory read address output
// - mem_rdata_i   : memory read data input
// - data_ready_i  : downstream ready for data
// - data_valid_o  : data valid output to downstream
// - data_o        : data output to downstream
//
// Case tested:
// - None

`include "common_cells/registers.svh"

module mem_to_handshake_fifo #(
    parameter int DEPTH = 2,
    parameter int ADDR_WIDTH = 8,
    parameter int DATA_WIDTH = 1024,
    // DO NOT OVERWRITE THIS PARAMETER
    parameter int unsigned FIFO_ADDR_DEPTH   = (DEPTH > 1) ? $clog2(DEPTH) : 1
)(
    input  logic clk_i,
    input  logic rst_ni,
    input  logic en_i,
    input  logic flush_i,
    input  logic [ADDR_WIDTH-1:0] addr_upper_bound_i, // upper bound included
    // mem interface
    output logic mem_ren_o,
    output logic [ADDR_WIDTH-1:0] mem_raddr_o,
    input  logic mem_rdata_valid_i,
    input  logic [DATA_WIDTH-1:0] mem_rdata_i,
    // handshake interface
    input  logic data_ready_i,
    output logic data_valid_o,
    output logic [DATA_WIDTH-1:0] data_o,
    // debug
    output logic [FIFO_ADDR_DEPTH-1:0] debug_fifo_usage_o
);
    logic fifo_full, fifo_empty;
    logic fifo_almost_full;
    logic [ADDR_WIDTH-1:0] mem_raddr_q, mem_raddr_n;
    logic fifo_push_en;

    // Memory read logic
    assign mem_ren_o = en_i & ~fifo_almost_full & ~flush_i;
    assign mem_raddr_o = mem_raddr_q;
    assign mem_raddr_n = (mem_raddr_q == addr_upper_bound_i) ? '0 : (mem_raddr_q + 1);
    assign fifo_push_en = mem_rdata_valid_i;

    // Handshake interface logic
    assign data_valid_o = en_i & ~fifo_empty;

    // Sequential logic
    `FFLARNC(mem_raddr_q, mem_raddr_n, mem_ren_o, flush_i, 1'b0, clk_i, rst_ni);

    // FIFO to cache data from memory
    lagd_fifo_v3 #(
        .FALL_THROUGH(1'b0),
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH),
        .RESET_VALUE(0)
    ) data_cache_fifo (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .flush_i(flush_i),
        .full_o(fifo_full),
        .empty_o(fifo_empty),
        .usage_o(debug_fifo_usage_o),
        .data_i(mem_rdata_i),
        .push_none_i(1'b0),
        .push_i(fifo_push_en),
        .data_o(data_o),
        .pop_i(data_ready_i & data_valid_o),
        .mem_o(),
        .almost_full_o(fifo_almost_full)
    );

endmodule