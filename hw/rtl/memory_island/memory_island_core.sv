// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

// TODO:
// Add address field definitions on top

module memory_island_core import memory_island_pkg::*; #(
    parameter type mem_narrow_req_t = logic,
    parameter type mem_narrow_rsp_t = logic,
    parameter type mem_wide_req_t = logic,
    parameter type mem_wide_rsp_t = logic,

    parameter mem_cfg_t Cfg = default_mem_cfg(),
    
    // Derived parameters - do not touch
    parameter int unsigned NumNarrowReq = Cfg.NumDirectNarrowReq + $countones(Cfg.AxiNarrowRW) +
        Cfg.NumAxiNarrowReq,
    parameter int unsigned NumWideReq = Cfg.NumDirectWideReq + $countones(Cfg.AxiWideRW) +
        Cfg.NumAxiWideReq
)(
    input logic clk_i,
    input logic rst_ni,

    input mem_narrow_req_t [NumNarrowReq-1:0] mem_narrow_req_i,
    output mem_narrow_rsp_t [NumNarrowReq-1:0] mem_narrow_rsp_o,

    input mem_wide_req_t [NumWideReq-1:0] mem_wide_req_i,
    output mem_wide_rsp_t [NumWideReq-1:0] mem_wide_rsp_o
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

    localparam int unsigned AddrBankWordBit = Cfg.NarrowDataWidth/8 - 1;
    localparam int unsigned AddrWideWordBit = Cfg.WideDataWidth/8 - 1;
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

    tcdm_interconnect_wrap #(
        .NumIn(NumWideReq),
        .NumOut(NumWideBanks),
        .AddrWidth(Cfg.AddrWidth),
        .DataWidth(Cfg.WideDataWidth),
        .AddrMemWidth(WideBankAddrWidth),
        .BeWidth(AddrWideWordBit + 1),
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

    // Narrow interconnect
    mem_narrow_req_t [Cfg.NumNarrowBanks-1:0] mem_narrow_req_to_banks;
    mem_narrow_rsp_t [Cfg.NumNarrowBanks-1:0] mem_narrow_rsp_from_banks;

    tcdm_interconnect_wrap #(
        .NumIn(NumNarrowReq),
        .NumOut(Cfg.NumNarrowBanks),
        .AddrWidth(Cfg.AddrWidth),
        .DataWidth(Cfg.NarrowDataWidth),
        .AddrMemWidth(NarrowBankAddrWidth),
        .BeWidth(AddrBankWordBit + 1),
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

    // ------------
    // Post route spilling
    // ------------
    mem_narrow_req_t [Cfg.NumNarrowBanks-1:0] mem_narrow_req_to_banks_q1;
    mem_narrow_rsp_t [Cfg.NumNarrowBanks-1:0] mem_narrow_rsp_from_banks_q1;
    mem_wide_req_t [NumWideBanks-1:0] mem_wide_req_to_banks_q1;
    mem_wide_rsp_t [NumWideBanks-1:0] mem_wide_rsp_from_banks_q1;

    for (genvar i = 0; i < Cfg.NumNarrowBanks; i++) begin: spill_narrow_routed
        mem_multicut #(
            .AddrWidth(Cfg.AddrWidth),
            .DataWidth(Cfg.NarrowDataWidth),
            .NumCutsReq(Cfg.SpillNarrowReqRouted),
            .NumCutsRsp(Cfg.SpillNarrowRspRouted),
            .mem_req_t(mem_narrow_req_t),
            .mem_rsp_t(mem_narrow_rsp_t)
        ) u_spill_narrow_routed (
            .clk_i(clk_i),
            .rst_ni(rst_ni),
            .req_i(mem_narrow_req_to_banks[i]),
            .req_o(mem_narrow_req_to_banks_q1[i]),
            .rsp_i(mem_narrow_rsp_from_banks_q1[i]),
            .rsp_o(mem_narrow_rsp_from_banks[i]),
            .read_ready_i(1'b1),
            .read_ready_o()
        );
    end

    for (genvar i = 0; i < NumWideBanks; i++) begin: spill_wide_routed
        mem_multicut #(
            .AddrWidth(Cfg.AddrWidth),
            .DataWidth(Cfg.WideDataWidth),
            .NumCutsReq(Cfg.SpillWideReqRouted),
            .NumCutsRsp(Cfg.SpillWideRspRouted),
            .mem_req_t(mem_wide_req_t),
            .mem_rsp_t(mem_wide_rsp_t)
        ) u_spill_wide_routed (
            .clk_i(clk_i),
            .rst_ni(rst_ni),
            .req_i(mem_wide_req_to_banks[i]),
            .req_o(mem_wide_req_to_banks_q1[i]),
            .rsp_i(mem_wide_rsp_from_banks_q1[i]),
            .rsp_o(mem_wide_rsp_from_banks[i]),
            .read_ready_i(1'b1),
            .read_ready_o()
        );
    end

    // ------------
    // Narrow wide arbitration
    // ------------
    wide_narrow_arbiter #(
        .NumNarrowBanks(Cfg.NumNarrowBanks),
        .NumWideBanks(NumWideBanks),
        .WideDataWidth(Cfg.WideDataWidth),
        .NarrowDataWidth(Cfg.NarrowDataWidth),
        .mem_narrow_req_t(mem_narrow_req_t),
        .mem_narrow_rsp_t(mem_narrow_rsp_t),
        .mem_wide_req_t(mem_wide_req_t),
        .mem_wide_rsp_t(mem_wide_rsp_t)
    ) u_narrow_wide_arbiter (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .mem_narrow_req_i(mem_narrow_req_to_banks_q1),
        .mem_narrow_rsp_o(mem_narrow_rsp_from_banks_q1),
        .mem_wide_req_i(mem_wide_req_to_banks_q1),
        .mem_wide_rsp_o(mem_wide_rsp_from_banks_q1)
    );

    // ------------
    // Wide request splitting
    // ------------
    localparam int unsigned WideToNarrowFactor = Cfg.WideDataWidth / Cfg.NarrowDataWidth;
    mem_narrow_req_t [NumWideBanks-1:0][WideToNarrowFactor-1:0] mem_wide_split_req;
    mem_narrow_rsp_t [NumWideBanks-1:0][WideToNarrowFactor-1:0] mem_wide_split_rsp;
    for (genvar i = 0; i < NumWideBanks; i++) begin: split_wide_req
        wide_to_narrow_splitter #(
            .MemAddrWidth(AddrWideWordBit + 1),
            .BankAddrWidth(InBankAddrWidth),
            .MemDataWidth(Cfg.WideDataWidth),
            .BankDataWidth(Cfg.NarrowDataWidth),
            .mem_req_t(mem_wide_req_t),
            .mem_rsp_t(mem_wide_rsp_t),
            .bank_req_t(mem_narrow_req_t),
            .bank_rsp_t(mem_narrow_rsp_t)
        ) u_split_wide_req (
            .clk_i(clk_i),
            .rst_ni(rst_ni),
            .mem_req_i(mem_wide_req_to_banks_q1[i]),
            .mem_rsp_o(mem_wide_rsp_from_banks_q1[i]),
            .bank_req_o(mem_wide_split_req[i]),
            .bank_rsp_i(mem_wide_split_rsp[i])
        );
    end

    // ------------
    // Bank access multiplexer
    // ------------
    mem_narrow_req_t [Cfg.NumNarrowBanks-1:0] bank_req;
    mem_narrow_rsp_t [Cfg.NumNarrowBanks-1:0] bank_rsp;

    always_comb begin : bank_access_mux
        for (int unsigned i = 0; i < Cfg.NumNarrowBanks; i++) begin
            automatic int unsigned wide_bank_idx = i / WideToNarrowFactor;
            automatic int unsigned narrow_part_idx = i % WideToNarrowFactor;

            bank_req[i] = '0;
            if (mem_narrow_rsp_from_banks_q1[i].q_ready) begin
                bank_req[i] = mem_narrow_req_to_banks_q1[i];
                mem_narrow_rsp_from_banks_q1[i].p = bank_rsp[i].p;
            end else begin : wide_bank_access
                bank_req[i] = mem_wide_split_req[wide_bank_idx][narrow_part_idx];
                mem_wide_split_rsp[wide_bank_idx][narrow_part_idx].p = bank_rsp[i].p;
            end
        end
    end
    
    // ------------
    // Banks multicut
    // ------------
    mem_narrow_req_t [Cfg.NumNarrowBanks-1:0] bank_req_q1;
    mem_narrow_rsp_t [Cfg.NumNarrowBanks-1:0] bank_rsp_q1;
    for (genvar i = 0; i < Cfg.NumNarrowBanks; i++) begin: banks_multicut
        mem_multicut #(
            .AddrWidth(Cfg.AddrWidth),
            .DataWidth(Cfg.NarrowDataWidth),
            .NumCutsReq(Cfg.SpillReqBank),
            .NumCutsRsp(Cfg.SpillRspBank),
            .mem_req_t(mem_narrow_req_t),
            .mem_rsp_t(mem_narrow_rsp_t)
        ) u_banks_multicut (
            .clk_i(clk_i),
            .rst_ni(rst_ni),
            .req_i(bank_req[i]),
            .req_o(bank_req_q1[i]),
            .rsp_i(bank_rsp_q1[i]),
            .rsp_o(bank_rsp[i]),
            .read_ready_i(1'b1),
            .read_ready_o()
        );
    end

    // ------------
    // Banks instances
    // ------------
    for (genvar i = 0; i < Cfg.NumNarrowBanks; i++) begin: banks
        tc_sram #(
            .NumWords(Cfg.WordsPerBank),
            .DataWidth(Cfg.NarrowDataWidth)
        ) u_bank (
            .clk_i(clk_i),
            .rst_ni(rst_ni),
            .req_i(bank_req_q1[i].q_valid),
            .addr_i(bank_req_q1[i].q.addr[AddrTopBit -: InBankAddrWidth]),
            .we_i(bank_req_q1[i].q.write),
            .wdata_i(bank_req_q1[i].q.data),
            .be_i(bank_req_q1[i].q.strb),
            .rdata_o(bank_rsp_q1[i].p.data)
        );
    end

    // ------------
    // Asserts
    // ------------
    // Banking factor must be a power of 2
    `STATIC_ASSERT($clog2(Cfg.NumNarrowBanks) == $clog2(Cfg.NumNarrowBanks & -Cfg.NumNarrowBanks),
        "Banking factor must be a power of 2");

    // Wide banking factor must be a multiple of narrow banking factor
    `STATIC_ASSERT((Cfg.NumNarrowBanks * Cfg.NarrowDataWidth) % Cfg.WideDataWidth == 0,
        "Wide banking factor must be a multiple of narrow banking factor");
    

endmodule : memory_island_core