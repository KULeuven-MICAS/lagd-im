// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

`include "lagd_platform.svh"

module memory_island_core_ic import memory_island_pkg::*; #(
    parameter type mem_narrow_req_t = logic,
    parameter type mem_narrow_rsp_t = logic,
    parameter type mem_wide_req_t = logic,
    parameter type mem_wide_rsp_t = logic,

    parameter mem_cfg_t Cfg = default_mem_cfg(),
    
    // Derived parameters - do not touch
    parameter int unsigned NumNarrowReq = Cfg.NumDirectNarrowReq + $countones(Cfg.AxiNarrowRW) +
        Cfg.NumAxiNarrowReq,
    parameter int unsigned NumWideReq = Cfg.NumDirectWideReq + $countones(Cfg.AxiWideRW) +
        Cfg.NumAxiWideReq,
    parameter int unsigned NumNarrowReqSafe = `ZWIDTH_SAFE(NumNarrowReq),
    parameter int unsigned NumWideReqSafe = `ZWIDTH_SAFE(NumWideReq)
)(
    input logic clk_i,
    input logic rst_ni,

    input mem_narrow_req_t [NumNarrowReqSafe-1:0] mem_narrow_req_i,
    output mem_narrow_rsp_t [NumNarrowReqSafe-1:0] mem_narrow_rsp_o,

    input mem_wide_req_t [NumWideReqSafe-1:0] mem_wide_req_i,
    output mem_wide_rsp_t [NumWideReqSafe-1:0] mem_wide_rsp_o
);

    // Address Wide Requests: 
        // GlobalBits _ InBankAddr _ WideBankSel _ BankSel _ Offset/Strobe
        //          |            |             |         |---------------- AddrBankWordBit
        //          |            |             |-------------------------- AddrWideWordBit
        //          |            |---------------------------------------- AddrWideBankBit
        //          |----------------------------------------------------- AddrTopBit
        //
        //                        <----------->                            WideBankAddrWidth
        //                                      <------->                  WideBankSelWidth
        //
        // Wide interco: AddrWideBankBit -> AddrWideWordBit (WideBankAddrWidth len) for routing

    // Address Narrow Requests: 
        // GlobalBits _ InBankAddr _ BankSel _ Offset/Strobe
        //          |            |         |---------------- AddrBankWordBit
        //          |            |-------------------------- AddrWideBankBit
        //          |--------------------------------------- AddrTopBit
        //
        //                        <------->                  NarrowBankAddrWidth
        //
        // Narrow interco: AddrWideBankBit -> AddrBankWordBit for routing

    // Address Pseudo-Wide Requests:
        // (hierarchical version, not implemented yet, as of ETH original repo): 
        // GlobalBits _ InBankAddr _ PseudoWideBankSel _ BankSel _ Offset/Strobe
        //          |            |                   |         |------------- AddrBankWordBit
        //          |            |                   |----------------------- AddrPseudoWideWordBit
        //          |            |------------------------------------------- AddrPseudoWideBankBit
        //          |-------------------------------------------------------- AddrTopBit
        //
        //                        <----------------->                         PseudoWideBankAddrWidth
        //                                            <------->               PseudoWideBankSelWidth
        //
        // Interco: AddrPseudoWideBankBit -> AddrPseudoWideWordBit 
        //      (PseudoWideBankAddrWidth len) for routing

    localparam int unsigned InBankAddrWidth = $clog2(Cfg.WordsPerBank);

    localparam int unsigned AddrBankWordBit = $clog2(Cfg.NarrowDataWidth/8) - 1;
    localparam int unsigned AddrWideWordBit = $clog2(Cfg.WideDataWidth/8) - 1;
    localparam int unsigned NumNarrowBanksInWide = Cfg.WideDataWidth / Cfg.NarrowDataWidth;

    localparam int unsigned NarrowBankAddrWidth = $clog2(Cfg.NumNarrowBanks);
    localparam int unsigned WideBankAddrWidth = $clog2(Cfg.NumNarrowBanks / NumNarrowBanksInWide);

    localparam int unsigned AddrWideBankBit = AddrBankWordBit + NarrowBankAddrWidth;
    localparam int unsigned AddrTopBit = AddrWideBankBit + InBankAddrWidth;

    // Response latency for narrow banks
    localparam int unsigned NarrowBankRespLat = Cfg.BankAccessLatency + Cfg.SpillNarrowReqRouted +
        Cfg.SpillNarrowRspRouted + Cfg.SpillReqBank + Cfg.SpillRspBank;
    localparam int unsigned WideBankRespLat = Cfg.BankAccessLatency + Cfg.SpillWideReqRouted +
        Cfg.SpillWideRspRouted + Cfg.SpillReqBank + Cfg.SpillRspBank;

    // TODO: add buffer instances here to allow for decoupling/variable latency
    // possibly in-order and out-of-order variants

    // -------------
    // Interconnects
    // -------------
    // Wide interconnect
    localparam int unsigned NumWideBanks = Cfg.NumNarrowBanks * Cfg.NarrowDataWidth / Cfg.WideDataWidth;
    mem_wide_req_t [NumWideBanks-1:0] mem_wide_req_to_banks;
    mem_wide_rsp_t [NumWideBanks-1:0] mem_wide_rsp_from_banks;
    generate
        if (NumWideReq > 0) begin : gen_wide_req_nonzero
            tcdm_interconnect_wrap #(
                .NumIn(NumWideReq),
                .NumOut(NumWideBanks),
                .FullAddrWidth(Cfg.AddrWidth),
                .AddrWidth(AddrTopBit+1),
                .DataWidth(Cfg.WideDataWidth),
                .AddrMemWidth(InBankAddrWidth),
                .BeWidth(Cfg.WideDataWidth/8),
                .RespLat(WideBankRespLat),
                .mem_req_t(mem_wide_req_t),
                .mem_rsp_t(mem_wide_rsp_t)
            ) u_wide_interco (
                .clk_i(clk_i),
                .rst_ni(rst_ni),

                .mem_req_i(mem_wide_req_i),
                .mem_rsp_o(mem_wide_rsp_o),

                .mem_req_o(mem_wide_req_to_banks),
                .mem_rsp_i(mem_wide_rsp_from_banks)
            );
        end else begin : gen_wide_req_zero
            // Tie-off signals if no wide requests
            assign mem_wide_rsp_o = '0;
            assign mem_wide_req_to_banks = '0;
        end
    endgenerate

    // Narrow interconnect
    mem_narrow_req_t [Cfg.NumNarrowBanks-1:0] mem_narrow_req_to_banks;
    mem_narrow_rsp_t [Cfg.NumNarrowBanks-1:0] mem_narrow_rsp_from_banks;
    generate
        if (NumNarrowReq == 0) begin : gen_narrow_req_zero
            // Tie-off signals if no narrow requests
            assign mem_narrow_rsp_o = '0;
            assign mem_narrow_req_to_banks = '0;
        end else begin : gen_narrow_multi_bank
            // Interconnect instance
            tcdm_interconnect_wrap #(
                .NumIn(NumNarrowReq),
                .NumOut(Cfg.NumNarrowBanks),
                .FullAddrWidth(Cfg.AddrWidth),
                .AddrWidth(AddrTopBit+1),
                .DataWidth(Cfg.NarrowDataWidth),
                .AddrMemWidth(InBankAddrWidth),
                .BeWidth(Cfg.NarrowDataWidth/8),
                .RespLat(NarrowBankRespLat),
                .mem_req_t(mem_narrow_req_t),
                .mem_rsp_t(mem_narrow_rsp_t)
            ) i_narrow_interco (
                .clk_i(clk_i),
                .rst_ni(rst_ni),

                .mem_req_i(mem_narrow_req_i),
                .mem_rsp_o(mem_narrow_rsp_o),

                .mem_req_o(mem_narrow_req_to_banks),
                .mem_rsp_i(mem_narrow_rsp_from_banks)
            );
        end
    endgenerate

    // ------------
    // Narrow wide arbitration
    // ------------
    mem_narrow_req_t [Cfg.NumNarrowBanks-1:0] bank_req;
    mem_narrow_rsp_t [Cfg.NumNarrowBanks-1:0] bank_rsp;
    wide_narrow_arbiter #(
        .NumNarrowBanks(Cfg.NumNarrowBanks),
        .NumWideBanks(NumWideBanks),
        .AddrWideWordBit(AddrWideWordBit),
        .InBankAddrWidth(InBankAddrWidth),
        .WideDataWidth(Cfg.WideDataWidth),
        .NarrowDataWidth(Cfg.NarrowDataWidth),
        .RspLatency(1 + Cfg.SpillReqBank + Cfg.SpillRspBank),
        .mem_narrow_req_t(mem_narrow_req_t),
        .mem_narrow_rsp_t(mem_narrow_rsp_t),
        .mem_wide_req_t(mem_wide_req_t),
        .mem_wide_rsp_t(mem_wide_rsp_t)
    ) u_narrow_wide_arbiter (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .mem_narrow_req_i(mem_narrow_req_to_banks),
        .mem_narrow_rsp_o(mem_narrow_rsp_from_banks),
        .mem_wide_req_i(mem_wide_req_to_banks),
        .mem_wide_rsp_o(mem_wide_rsp_from_banks),
        .mem_bank_req_o(bank_req),
        .mem_bank_rsp_i(bank_rsp)
    );
    

    for (genvar i = 0; i < Cfg.NumNarrowBanks; i++) begin: banks_multicut
        assign bank_rsp[i].q_ready = bank_req[i].q_valid;
    end

    // ------------
    // Banks instances
    // ------------
    logic [Cfg.NumNarrowBanks-1:0] bank_req_q1_valid;
    for (genvar i = 0; i < Cfg.NumNarrowBanks; i++) begin: banks
        tc_sram #(
            .NumWords(Cfg.WordsPerBank),
            .DataWidth(Cfg.NarrowDataWidth),
            .NumPorts(1)
        ) u_bank (
            .clk_i(clk_i),
            .rst_ni(rst_ni),
            .req_i(bank_req[i].q_valid),
            .addr_i(bank_req[i].q.addr[InBankAddrWidth-1:0]),
            .we_i(bank_req[i].q.write),
            .wdata_i(bank_req[i].q.data),
            .be_i(bank_req[i].q.strb),
            .rdata_o(bank_rsp[i].p.data)
        );
        // Update valid signal for response
        always_ff @(posedge clk_i or negedge rst_ni) begin
            if (!rst_ni) begin
                bank_req_q1_valid[i] <= 1'b0;
            end else begin
                bank_req_q1_valid[i] <= bank_req[i].q_valid;
            end
        end
        assign bank_rsp[i].p.valid = bank_req_q1_valid[i];
    end
    // TODO: add valid answer signal back to tc_sram and connect to rsp.p.valid
    // ------------
    // Asserts
    // ------------
    // Banking factor must be a power of 2
    `STATIC_ASSERT($clog2(Cfg.NumNarrowBanks) == $clog2(Cfg.NumNarrowBanks & -Cfg.NumNarrowBanks),
        "Banking factor must be a power of 2");

    // Wide banking factor must be a multiple of narrow banking factor
    `STATIC_ASSERT((Cfg.NumNarrowBanks * Cfg.NarrowDataWidth) % Cfg.WideDataWidth == 0,
        "Wide banking factor must be a multiple of narrow banking factor");
    

endmodule : memory_island_core_ic