// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

// Description: Round-robin arbiter between wide and narrow memory ports

`include "lagd_platform.svh"

module wide_narrow_arbiter #(
    parameter int unsigned NumNarrowBanks = 0,
    parameter int unsigned NumWideBanks = 0,

    parameter type mem_narrow_req_t = logic,
    parameter type mem_narrow_rsp_t = logic,
    parameter type mem_wide_req_t = logic,
    parameter type mem_wide_rsp_t = logic,

) (
    input logic clk_i,
    input logic rst_ni,

    // Narrow ports
    input mem_narrow_req_t [NumNarrowBanks-1:0] mem_narrow_req_i,
    output mem_narrow_rsp_t [NumNarrowBanks-1:0] mem_narrow_rsp_o,

    // Wide ports
    input mem_wide_req_t [NumWideBanks-1:0] mem_wide_req_i,
    output mem_wide_rsp_t [NumWideBanks-1:0] mem_wide_rsp_o
);

    localparam int unsigned WideDataWidth = $bits(mem_wide_req_i[0].q.data);
    localparam int unsigned NarrowDataWidth = $bits(mem_narrow_req_i[0].q.data);
    localparam int unsigned NarrowPerWide = WideDataWidth / NarrowDataWidth;

    // Arbitration bit for narrow/wide
    logic arb_narrow_next;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            arb_narrow_next <= 1'b1;
        end else begin
            arb_narrow_next <= ~arb_narrow_next;
        end
    end

    logic [NumNarrowBanks-1:0] wide_valid_split;
    always_comb begin : wide_valid_splitting
        for (int unsigned i = 0; i < NumNarrowBanks; i++) begin
            int unsigned wide_idx = i / NarrowPerWide;
            wide_valid_split[i] = mem_wide_req_i[wide_idx].valid;
        end
    end

    logic [NumWideBanks-1:0] narrow_valid_merged;
    always_comb begin : narrow_valid_merging
        for (int unsigned j = 0; j < NumWideBanks; j++) begin
            narrow_valid_merged[j] = 1'b0;
            for (int unsigned k = 0; k < NarrowPerWide; k++) begin
                int unsigned narrow_idx = j * NarrowPerWide + k;
                narrow_valid_merged[j] |= mem_narrow_req_i[narrow_idx].valid;
            end
        end
    end

    // Narrow/Wide arbitration: blocks drives granting signals
    always_comb begin : narrow_wide_arbitration
        if (arb_narrow_next) begin : narrow_priority
            // Narrow has priority
            for (int unsigned i = 0; i < NumNarrowBanks; i++) begin
                mem_narrow_rsp_o[i].q_ready = 1'b1;
            end
            for (int unsigned j = 0; j < NumWideBanks; j++) begin
                mem_wide_rsp_o[j].q_ready = narrow_valid_merged[j] ? 1'b0 : 1'b1;
            end
        end else begin : wide_priority
            // Wide has priority
            for (int unsigned j = 0; j < NumWideBanks; j++) begin
                mem_wide_rsp_o[j].q_ready = 1'b1;
            end
            for (int unsigned i = 0; i < NumNarrowBanks; i++) begin
                mem_narrow_rsp_o[i].q_ready = wide_valid_split[i] ? 1'b0 : 1'b1;
            end
        end
    end

    // ----------------
    // Assertions
    // ----------------
    `STATIC_ASSERT(WideDataWidth % NarrowDataWidth == 0,
        "Wide data width must be a multiple of narrow data width");

endmodule