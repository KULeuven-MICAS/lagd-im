// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

`include "lagd_platform.svh"

module memory_island_core_top import memory_island_pkg::*; #(
    parameter type mem_narrow_req_t = logic,
    parameter type mem_narrow_rsp_t = logic,
    parameter mem_cfg_t Cfg = default_mem_cfg()
)(
    input logic clk_i,
    input logic rst_ni,

    input mem_narrow_req_t mem_narrow_req_i,
    output mem_narrow_rsp_t mem_narrow_rsp_o
);

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

    // Narrow interconnect
    mem_narrow_req_t [Cfg.NumNarrowBanks-1:0] mem_narrow_req_to_banks;
    mem_narrow_rsp_t [Cfg.NumNarrowBanks-1:0] mem_narrow_rsp_from_banks;
    tcdm_interconnect_wrap #(
        .NumIn(1),
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
            .req_i(mem_narrow_req_to_banks[i].q_valid),
            .addr_i(mem_narrow_req_to_banks[i].q.addr[InBankAddrWidth-1:0]),
            .we_i(mem_narrow_req_to_banks[i].q.write),
            .wdata_i(mem_narrow_req_to_banks[i].q.data),
            .be_i(mem_narrow_req_to_banks[i].q.strb),
            .rdata_o(mem_narrow_rsp_from_banks[i].p.data)
        );
        // Update valid signal for response
        always_ff @(posedge clk_i or negedge rst_ni) begin
            if (!rst_ni) begin
                bank_req_q1_valid[i] <= 1'b0;
            end else begin
                bank_req_q1_valid[i] <= mem_narrow_req_to_banks[i].q_valid;
            end
        end
        assign mem_narrow_rsp_from_banks[i].p.valid = bank_req_q1_valid[i];
        assign mem_narrow_rsp_from_banks[i].q_ready = mem_narrow_req_to_banks[i].q_valid;
    end
endmodule : memory_island_core_top