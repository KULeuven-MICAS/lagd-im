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
    parameter int unsigned AddrWideWordBit = 0,
    parameter int unsigned InBankAddrWidth = 0,
    parameter int unsigned WideDataWidth = 0,
    parameter int unsigned NarrowDataWidth = 0,
    parameter int unsigned RspLatency = 1,

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
    output mem_wide_rsp_t [NumWideBanks-1:0] mem_wide_rsp_o,

    // Bank ports
    output mem_narrow_req_t [NumNarrowBanks-1:0] mem_bank_req_o,
    input mem_narrow_rsp_t [NumNarrowBanks-1:0] mem_bank_rsp_i
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

    // =======================================================================
    // Wide to narrow splitting
    // =======================================================================
    logic [NumNarrowBanks-1:0] wide_valid_split;
    for (genvar i = 0; i < NumNarrowBanks; i++) begin : wide_valid_splitting
        localparam int unsigned wide_idx = i / NarrowPerWide;
        assign wide_valid_split[i] = mem_wide_req_i[wide_idx].q_valid;
    end

    logic [NumNarrowBanks-1:0] wide_ready_split;
    for (genvar j = 0; j < NumWideBanks; j++) begin : narrow_ready_splitting
        assign mem_wide_rsp_o[j].q_ready = |wide_ready_split[j * NarrowPerWide +: NarrowPerWide];
    end
    localparam int unsigned WideToNarrowFactor = WideDataWidth / NarrowDataWidth;
    mem_narrow_req_t [NumWideBanks-1:0][WideToNarrowFactor-1:0] mem_wide_split_req;
    mem_narrow_rsp_t [NumWideBanks-1:0][WideToNarrowFactor-1:0] mem_wide_split_rsp;
    generate
        if (WideToNarrowFactor == 1) begin : gen_no_wide_split  // No splitting needed
            for(genvar i = 0; i < NumWideBanks; i++) begin: connect_no_split
                assign mem_wide_rsp_o[i].p = mem_wide_split_rsp[i][0].p;
                assign mem_wide_split_req[i] = mem_wide_req_i[i][0];
            end
        end else begin : gen_wide_split  // Splitting 
            for (genvar i = 0; i < NumWideBanks; i++) begin: split_wide_req
                wide_to_narrow_splitter #(
                    .MemAddrWidth(AddrWideWordBit + 1),
                    .BankAddrWidth(InBankAddrWidth),
                    .MemDataWidth(WideDataWidth),
                    .BankDataWidth(NarrowDataWidth),
                    .mem_req_t(mem_wide_req_t),
                    .mem_rsp_t(mem_wide_rsp_t),
                    .bank_req_t(mem_narrow_req_t),
                    .bank_rsp_t(mem_narrow_rsp_t)
                ) u_split_wide_req (
                    .clk_i(clk_i),
                    .rst_ni(rst_ni),
                    .mem_req_i(mem_wide_req_i[i]),
                    .mem_rsp_o(mem_wide_rsp_o[i]),
                    .bank_req_o(mem_wide_split_req[i]),
                    .bank_rsp_i(mem_wide_split_rsp[i])
                );
            end
        end
    endgenerate

    // =======================================================================
    // Narrow to wide valid merging (for constructing arbitration)
    // =======================================================================
    logic [NumWideBanks-1:0] narrow_valid_merged;
    logic [NumNarrowBanks-1:0] narrow_valid_unpacked, narrow_pseudowide_valid;
    for (genvar j = 0; j < NumWideBanks; j++) begin : narrow_valid_merging_gen
        for (genvar k = 0; k < NarrowPerWide; k++) begin
            localparam int unsigned narrow_idx = j * NarrowPerWide + k;
            assign narrow_valid_unpacked[narrow_idx] = mem_narrow_req_i[narrow_idx].q_valid;
        end
        assign narrow_valid_merged[j] = |narrow_valid_unpacked[j * NarrowPerWide +: NarrowPerWide];
        assign narrow_pseudowide_valid[j * NarrowPerWide +: NarrowPerWide] = {NarrowPerWide{narrow_valid_merged[j]}};
    end

    // =======================================================================
    // Arbitration Logic
    // =======================================================================
    logic [NumNarrowBanks-1:0] conflict_detected;
    for (genvar i = 0; i < NumNarrowBanks; i++) begin : conflict_detection
        assign conflict_detected[i] = narrow_pseudowide_valid[i] && wide_valid_split[i];
    end

    // Narrow/Wide arbitration
    for (genvar i = 0; i < NumNarrowBanks; i++) begin : bank_request_routing
        always_comb begin : bank_access_mux
            if (conflict_detected[i]) begin : conflict_case
                if (arb_narrow_next) begin : conflict_narrow_priority
                    mem_bank_req_o[i] = mem_narrow_req_i[i];
                    mem_narrow_rsp_o[i].q_ready = 1'b1;
                    wide_ready_split[i] = 1'b0;
                end else begin : conflict_wide_priority
                    mem_bank_req_o[i] = mem_wide_split_req[i];
                    mem_narrow_rsp_o[i].q_ready = 1'b0;
                    wide_ready_split[i] = 1'b1;
                end
            end else begin : no_conflict_case
                if (narrow_valid_unpacked[i]) begin : no_conflict_narrow
                    mem_bank_req_o[i] = mem_narrow_req_i[i];
                    wide_ready_split[i] = 1'b0;
                    mem_narrow_rsp_o[i].q_ready = 1'b1;
                end else begin : no_conflict_wide
                    mem_bank_req_o[i] = mem_wide_split_req[i];
                    wide_ready_split[i] = wide_valid_split[i];
                    mem_narrow_rsp_o[i].q_ready = 1'b0;
                end
            end
        end
    end

    // =======================================================================
    // Bank response routing
    // =======================================================================
    logic [NumNarrowBanks-1:0][RspLatency-1:0] mem_narrow_rsp_arb_valid;
    logic [NumNarrowBanks-1:0][RspLatency-1:0] mem_wide_rsp_arb_valid;
    for (genvar i = 0; i < RspLatency; i++) begin : rsp_valid_pipeline_gen
        for (genvar j = 0; j < NumNarrowBanks; j++) begin : bank_rsp_valid_gen
            always_ff @(posedge clk_i or negedge rst_ni) begin
                if (!rst_ni) begin
                    mem_narrow_rsp_arb_valid[j][i] <= 1'b0;
                    mem_wide_rsp_arb_valid[j][i] <= 1'b0;
                end else begin
                    if (i > 0) begin
                        mem_narrow_rsp_arb_valid[j][i] <= mem_narrow_rsp_arb_valid[j][i-1];
                        mem_wide_rsp_arb_valid[j][i] <= mem_wide_rsp_arb_valid[j][i-1];
                    end else begin
                        mem_narrow_rsp_arb_valid[j][i] <= mem_narrow_rsp_o[j].q_ready && mem_narrow_req_i[j].q_valid;
                        mem_wide_rsp_arb_valid[j][i] <= wide_ready_split[j] && wide_valid_split[j];
                    end
                end
            end
        end
    end

    generate
        for (genvar i = 0; i < NumNarrowBanks; i++) begin : bank_response_routing
            localparam int unsigned wide_idx = i / NarrowPerWide;
            localparam int unsigned narrow_idx_in_wide = i % NarrowPerWide;
            always_comb begin
                if (mem_narrow_rsp_arb_valid[i][RspLatency-1]) begin
                    mem_narrow_rsp_o[i].p = mem_bank_rsp_i[i].p;
                    mem_wide_split_rsp[wide_idx][narrow_idx_in_wide].p = '0;
                end else if (mem_wide_rsp_arb_valid[i][RspLatency-1]) begin
                    mem_narrow_rsp_o[i].p = '0;
                    mem_wide_split_rsp[wide_idx][narrow_idx_in_wide].p = mem_bank_rsp_i[i].p;
                end else begin
                    mem_narrow_rsp_o[i].p = '0; // Default value when no valid response
                    mem_wide_split_rsp[wide_idx][narrow_idx_in_wide].p = '0;
                end
            end
        end
    endgenerate

    // ----------------
    // Assertions
    // ----------------
    `STATIC_ASSERT(WideDataWidth % NarrowDataWidth == 0,
        "Wide data width must be a multiple of narrow data width");

    // -----------------
    // Logs
    // -----------------
    `ifdef TARGET_LOG_INSTS
    $info("Instantiated wide_narrow_arbiter with parameters:");
    `ifndef TARGET_SYNOPSYS
    $info("Module: %m");
    $info("  mem_narrow_req_t: %s", $typename(mem_narrow_req_i[0]));
    $info("  mem_narrow_rsp_t: %s", $typename(mem_narrow_rsp_o[0]));
    $info("  mem_wide_req_t: %s", $typename(mem_wide_req_i[0]));
    $info("  mem_wide_rsp_t: %s", $typename(mem_wide_rsp_o[0]));
    `endif
    $info("  NumNarrowBanks: %d", NumNarrowBanks);
    $info("  NumWideBanks: %d", NumWideBanks);
    $info("  WideDataWidth: %d", WideDataWidth);
    $info("  NarrowDataWidth: %d", NarrowDataWidth);
    `endif // TARGET_LOG_INSTS
endmodule