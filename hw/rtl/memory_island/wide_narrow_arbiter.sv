// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

// Module: wide_narrow_arbiter

// Description:
//      Round-robin arbiter between wide and narrow memory request ports for shared banked 
//      memory access. The arbiter  generates ready/grant signals 
//      (q_ready) to control which requestor type can access the banks in each cycle. 
// Arbitration Policy:
//      - Round-robin priority flip: arb_narrow_next toggles every cycle.
//      - When arb_narrow_next=1 (narrow priority): narrow requests are granted; wide requests 
//        are blocked if any narrow request is valid for the corresponding wide bank group.
//      - When arb_narrow_next=0 (wide priority): wide requests are granted; narrow requests 
//        are blocked if the corresponding wide request is valid.
//      - This ensures neither type starves and provides approximately equal bandwidth allocation.

// Parameters:
//      NumNarrowBanks: Total number of narrow memory banks.
//      NumWideBanks: Total number of wide request ports (NumNarrowBanks / NarrowPerWide).
//      WideDataWidth: Data width of wide ports (bits).
//      NarrowDataWidth: Data width of narrow ports (bits).
//                       WideDataWidth must be an integer multiple of NarrowDataWidth.
//      mem_narrow_req_t / mem_narrow_rsp_t: Narrow memory request/response struct types 
//          (must have q_valid and q_ready fields).
//      mem_wide_req_t / mem_wide_rsp_t: Wide memory request/response struct types 
//          (must have q_valid and q_ready fields).

// Ports:
//      clk_i: Clock.
//      rst_ni: Active-low reset.
//      Narrow Ports (one per narrow bank):
//          mem_narrow_req_i[NumNarrowBanks-1:0]: Narrow request inputs (only .q_valid used here).
//          mem_narrow_rsp_o[NumNarrowBanks-1:0]: Narrow response outputs (only .q_ready driven here).
//      Wide Ports (one per wide bank group):
//          mem_wide_req_i[NumWideBanks-1:0]: Wide request inputs (only .q_valid used here).
//          mem_wide_rsp_o[NumWideBanks-1:0]: Wide response outputs (only .q_ready driven here).


`include "lagd_platform.svh"

module wide_narrow_arbiter #(
    parameter int unsigned NumNarrowBanks = 0,
    parameter int unsigned NumWideBanks = 0,
    parameter int unsigned WideDataWidth = 0,
    parameter int unsigned NarrowDataWidth = 0,

    parameter type mem_narrow_req_t = logic,
    parameter type mem_narrow_rsp_t = logic,
    parameter type mem_wide_req_t = logic,
    parameter type mem_wide_rsp_t = logic

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
    for (genvar i = 0; i < NumNarrowBanks; i++) begin : wide_valid_splitting
        localparam int unsigned wide_idx = i / NarrowPerWide;
        assign wide_valid_split[i] = mem_wide_req_i[wide_idx].q_valid;
    end

    logic [NumWideBanks-1:0] narrow_valid_merged;
    logic [NumNarrowBanks-1:0] narrow_valid_unpacked;
    for (genvar j = 0; j < NumWideBanks; j++) begin : narrow_valid_merging_gen
        for (genvar k = 0; k < NarrowPerWide; k++) begin
            localparam int unsigned narrow_idx = j * NarrowPerWide + k;
            assign narrow_valid_unpacked[narrow_idx] = mem_narrow_req_i[narrow_idx].q_valid;
        end
        assign narrow_valid_merged[j] = |narrow_valid_unpacked[j * NarrowPerWide +: NarrowPerWide];
    end

    // Narrow/Wide arbitration: drives granting signals
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