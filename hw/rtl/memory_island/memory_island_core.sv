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
    parameter int unsigned NumNarrowReq = Cfg.NumDirectNarrowReq + $countones(Cfg.NarrowRW) +
        NumAxiNarrowReq,
    parameter int unsigned NumWideReq = Cfg.NumDirectWideReq + $countones(Cfg.WideRW) +
        NumAxiWideReq
)(
    input logic clk_i,
    input logic rst_ni,

    input mem_narrow_req_t [NumNarrowReq-1:0] mem_narrow_req_i,
    output mem_narrow_rsp_t [NumNarrowReq-1:0] mem_narrow_rsp_o,

    input mem_wide_req_t [NumWideReq-1:0] mem_wide_req_i,
    output mem_wide_rsp_t [NumWideReq-1:0] mem_wide_rsp_o
);

    // TODO: add buffer instances here to allow for variable latency
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
        .BankingFactor(NumWideBanks),
        .AccessLatency(Cfg.BankAccessLatency),
        .ReqType(mem_wide_req_t),
        .RspType(mem_wide_rsp_t)
    ) u_wide_interco (
        .clk_i(clk_i),
        .rst_ni(rst_ni),

        .mem_req_i(mem_wide_req_i),
        .mem_rsp_o(mem_wide_rsp_o),

        .mem_rsp_o(mem_wide_req_to_banks),
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
        .BankingFactor(Cfg.NumNarrowBanks),
        .AccessLatency(Cfg.BankAccessLatency),
        .ReqType(mem_narrow_req_t),
        .RspType(mem_narrow_rsp_t)
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
            .MemAddrWidth(Cfg.AddrWidth),
            .BankAddrWidth(Cfg.AddrWidth),
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

    for (genvar i = 0; i < Cfg.NumNarrowBanks; i++) begin: bank_access_mux
        if (mem_narrow_rsp_from_banks_q1[i].q_ready) begin : narrow_bank_access
            // Narrow access
            assign bank_req[i] = mem_narrow_req_to_banks_q1[i];
            assign mem_narrow_rsp_from_banks_q1[i].p = bank_rsp[i].p;
        end else begin : wide_bank_access
            localparam int unsigned wide_bank_idx = i / WideToNarrowFactor;
            localparam int unsigned narrow_part_idx = i % WideToNarrowFactor;
            assign bank_req[i] = mem_wide_split_req[wide_bank_idx][narrow_part_idx];
            assign mem_wide_split_rsp[wide_bank_idx][narrow_part_idx].p = bank_rsp[i].p;
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
    localparam int unsigned BankWordAddrWidth = Cfg.AddrWidth - $clog2(Cfg.NumNarrowBanks) -
        $clog2(Cfg.NarrowDataWidth/8);
    localparam int unsigned WordsPerBank = 1 << BankWordAddrWidth;
    localparam int unsigned AddressWideWordBit = $clog2(Cfg.NumNarrowBanks) + $clog2(Cfg.NarrowDataWidth/8);
    for (genvar i = 0; i < Cfg.NumNarrowBanks; i++) begin: banks
        tc_sram(
            .NumWords(WordsPerBank),
            .DataWidth(Cfg.NarrowDataWidth)
        ) u_bank (
            .clk_i(clk_i),
            .rst_ni(rst_ni),
            .req_i(bank_req_q1[i].q_valid),
            .addr_i(bank_req_q1[i].q.addr[AddressWideWordBit-1 -: BankWordAddrWidth]),
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