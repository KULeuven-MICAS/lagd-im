// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

// Memory model: Simple SRAM + response delay emulation

`timescale 1ns/1ps

module virtual_memory #(
    parameter int unsigned NumWords  = 256,
    parameter int unsigned DataWidth = 64,
    parameter int unsigned ReadWrite = 1'b0,
    parameter type mem_req_t = logic,
    parameter type mem_rsp_t = logic
) (
    input  logic                          clk_i,
    input  logic                          rst_ni,

    // Memory request stream from DUT
    input  mem_req_t [ReadWrite:0] mem_req_i,
    // Memory response stream to DUT
    output mem_rsp_t [ReadWrite:0] mem_rsp_o
);

    `include "tb_config.svh"

    // ========================================================================
    // MEMORY STORAGE
    // ========================================================================

    tc_sram #(
        .NumWords(NumWords),
        .DataWidth(DataWidth),
        .NumPorts(1 + ReadWrite)
    ) u_tc_sram (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .req_i(mem_req_i[0].q_valid),
        .we_i(mem_req_i[0].q.write),
        .addr_i(mem_req_i[0].q.addr[$clog2(DataWidth/8)+: $clog2(NumWords)]),
        .wdata_i(mem_req_i[0].q.data),
        .be_i(mem_req_i[0].q.strb),
        .rdata_o(mem_rsp_o[0].p.data)
    );

    // ========================================================================
    // RESPONSE VALID GENERATION
    // ========================================================================

    logic rdata_valid;

    // Delay response by one cycle to emulate memory latency
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            rdata_valid <= '0;
        end else begin
            rdata_valid <= #TA mem_req_i[0].q_valid;
        end
    end

    // Drive response interface
    assign mem_rsp_o[0].p.valid  = rdata_valid;
    assign mem_rsp_o[0].q_ready  = 1'b1;

endmodule
