// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

`include "lagd_platform.svh"

module memory_island_wrap_ic import memory_island_pkg::*; #(
    parameter mem_cfg_t Cfg = default_mem_cfg(),

    parameter type axi_narrow_req_t = logic,
    parameter type axi_narrow_rsp_t = logic,
    parameter type mem_narrow_req_t = logic,
    parameter type mem_narrow_rsp_t = logic,
    parameter type mem_wide_req_t = logic,
    parameter type mem_wide_rsp_t = logic
)(
    input logic clk_i,
    input logic rst_ni,

    input axi_narrow_req_t axi_narrow_req_i,
    output axi_narrow_rsp_t  axi_narrow_rsp_o,

    input mem_wide_req_t mem_wide_req_i,
    output mem_wide_rsp_t mem_wide_rsp_o
);

    mem_narrow_req_t mem_narrow_req_from_axi;
    mem_narrow_rsp_t mem_narrow_rsp_to_axi;

    // Spill latencies
    localparam int unsigned NarrowMemRspLatency = Cfg.SpillAxiNarrowReqEntry +
        Cfg.SpillNarrowReqRouted + Cfg.SpillReqBank + Cfg.SpillRspBank +
        Cfg.SpillNarrowRspRouted + Cfg.SpillAxiNarrowRspEntry + Cfg.BankAccessLatency;

    localparam int unsigned WideMemRspLatency = Cfg.SpillAxiWideReqEntry +
        Cfg.SpillWideReqRouted + Cfg.SpillReqBank + Cfg.SpillRspBank +
        Cfg.SpillWideRspRouted + Cfg.SpillAxiWideRspEntry + Cfg.BankAccessLatency;
    
    // =============================================================================================
    // Axi to mem adapters
    // =============================================================================================
    axi_to_mem_adapter #(
        .axi_req_t(axi_narrow_req_t),
        .axi_rsp_t(axi_narrow_rsp_t),
        .mem_req_t(mem_narrow_req_t),
        .mem_rsp_t(mem_narrow_rsp_t),
        .AddrWidth(Cfg.AddrWidth),
        .DataWidth(Cfg.NarrowDataWidth),
        .IdWidth(Cfg.AxiNarrowIdWidth),
        .BufDepth(1 + NarrowMemRspLatency),
        .ReadWrite(1'b0)
    ) u_axi_to_mem_adapter_narrow (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .axi_req_i(axi_narrow_req_i),
        .axi_rsp_o(axi_narrow_rsp_o),
        .mem_req_o(mem_narrow_req_from_axi),
        .mem_rsp_i(mem_narrow_rsp_to_axi)
    );

    // =============================================================================================
    // Memory island core
    // =============================================================================================
    memory_island_core_ic #(
        .mem_narrow_req_t(mem_narrow_req_t),
        .mem_narrow_rsp_t(mem_narrow_rsp_t),
        .mem_wide_req_t(mem_wide_req_t),
        .mem_wide_rsp_t(mem_wide_rsp_t),
        .Cfg(Cfg)
    ) i_memory_island_core (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .mem_narrow_req_i(mem_narrow_req_from_axi),
        .mem_narrow_rsp_o(mem_narrow_rsp_to_axi),
        .mem_wide_req_i(mem_wide_req_i),
        .mem_wide_rsp_o(mem_wide_rsp_o)
    );
endmodule : memory_island_wrap_ic
