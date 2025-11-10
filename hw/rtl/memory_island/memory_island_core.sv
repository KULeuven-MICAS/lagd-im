// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

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
    ) i_wide_interco (
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
    // Asserts
    // ------------
    // Banking factor must be a power of 2
    `STATIC_ASSERT($clog2(Cfg.NumNarrowBanks) == $clog2(Cfg.NumNarrowBanks & -Cfg.NumNarrowBanks),
        "Banking factor must be a power of 2");

    // Wide banking factor must be a multiple of narrow banking factor
    `STATIC_ASSERT((Cfg.NumNarrowBanks * Cfg.NarrowDataWidth) % Cfg.WideDataWidth == 0,
        "Wide banking factor must be a multiple of narrow banking factor");
    

endmodule : memory_island_core