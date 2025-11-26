// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

// Module description:
// Wrapper for memory island module

// The entire memory island was inspired by:
// https://github.com/pulp-platform/memory_island

module memory_island_wrap import memory_island_pkg::*; #(
    parameter mem_cfg_t Cfg = default_mem_cfg(),

    parameter type axi_narrow_req_t = logic,
    parameter type axi_narrow_rsp_t = logic,
    
    parameter type axi_wide_req_t = logic,
    parameter type axi_wide_rsp_t = logic,

    parameter type mem_narrow_req_t = logic,
    parameter type mem_narrow_rsp_t = logic,

    parameter type mem_wide_req_t = logic,
    parameter type mem_wide_rsp_t = logic
)(
    input logic clk_i,
    input logic rst_ni,

    input axi_narrow_req_t [Cfg.NumAxiNarrowReq-1:0] axi_narrow_req_i,
    output axi_narrow_rsp_t [Cfg.NumAxiNarrowReq-1:0] axi_narrow_rsp_o,

    input axi_wide_req_t [Cfg.NumAxiWideReq-1:0] axi_wide_req_i,
    output axi_wide_rsp_t [Cfg.NumAxiWideReq-1:0] axi_wide_rsp_o,

    input mem_narrow_req_t [Cfg.NumDirectNarrowReq-1:0] mem_narrow_req_i,
    output mem_narrow_rsp_t [Cfg.NumDirectNarrowReq-1:0] mem_narrow_rsp_o,

    input mem_wide_req_t [Cfg.NumDirectWideReq-1:0] mem_wide_req_i,
    output mem_wide_rsp_t [Cfg.NumDirectWideReq-1:0] mem_wide_rsp_o
);

    // Narrow AXI requests and responses for adapter and spilling
    localparam int unsigned axi_rw_narrow_reqs = Cfg.NumAxiNarrowReq + $countones(Cfg.AxiNarrowRW);
    mem_narrow_req_t [axi_rw_narrow_reqs-1:0] mem_narrow_req_from_axi, mem_narrow_req_from_axi_q1;
    mem_narrow_rsp_t [axi_rw_narrow_reqs-1:0] mem_narrow_rsp_to_axi, mem_narrow_rsp_to_axi_q1;

    // Wide AXI requests and responses for adapter and spilling
    localparam int unsigned axi_rw_wide_reqs = Cfg.NumAxiWideReq + $countones(Cfg.AxiWideRW);
    mem_wide_req_t [axi_rw_wide_reqs-1:0] mem_wide_req_from_axi, mem_wide_req_from_axi_q1;
    mem_wide_rsp_t [axi_rw_wide_reqs-1:0] mem_wide_rsp_to_axi, mem_wide_rsp_to_axi_q1;

    // Full memory island requests and responses narrow
    localparam int unsigned total_narrow_reqs = axi_rw_narrow_reqs + Cfg.NumDirectNarrowReq;
    mem_narrow_req_t [total_narrow_reqs-1:0] mem_narrow_req;
    mem_narrow_rsp_t [total_narrow_reqs-1:0] mem_narrow_rsp;
    assign mem_narrow_rsp = {mem_narrow_rsp_to_axi_q1, mem_narrow_rsp_o};
    assign mem_narrow_req = {mem_narrow_req_from_axi_q1, mem_narrow_req_i};

    // Full memory island requests and responses wide
    localparam int unsigned total_wide_reqs = axi_rw_wide_reqs + Cfg.NumDirectWideReq;
    mem_wide_req_t [total_wide_reqs-1:0] mem_wide_req;
    mem_wide_rsp_t [total_wide_reqs-1:0] mem_wide_rsp;
    assign mem_wide_rsp = {mem_wide_rsp_to_axi_q1, mem_wide_rsp_o};
    assign mem_wide_req = {mem_wide_req_from_axi_q1, mem_wide_req_i};

    // Spill latencies
    localparam int unsigned NarrowMemRspLatency = Cfg.SpillAxiNarrowReqEntry +
        Cfg.SpillNarrowReqRouted + Cfg.SpillReqBank + Cfg.SpillRspBank +
        Cfg.SpillNarrowRspRouted + Cfg.SpillAxiNarrowRspEntry + Cfg.BankAccessLatency;

    localparam int unsigned WideMemRspLatency = Cfg.SpillAxiWideReqEntry +
        Cfg.SpillWideReqRouted + Cfg.SpillReqBank + Cfg.SpillRspBank +
        Cfg.SpillWideRspRouted + Cfg.SpillAxiWideRspEntry + Cfg.BankAccessLatency;
    // ------------
    // Axi to mem adapters
    // ------------
    for (genvar i = 0; i < Cfg.NumAxiNarrowReq; i++) begin: axi_narrow_adapter
        localparam int unsigned id = i + $countones(Cfg.AxiNarrowRW[i:0]);
        axi_to_mem_adapter #(
            .axi_req_t(axi_narrow_req_t),
            .axi_rsp_t(axi_narrow_rsp_t),
            .mem_req_t(mem_narrow_req_t),
            .mem_rsp_t(mem_narrow_rsp_t),
            .AddrWidth(),
            .DataWidth(Cfg.NarrowDataWidth),
            .IdWidth(Cfg.AxiNarrowIdWidth),
            .MemDataWidth(Cfg.NarrowDataWidth),
            .BufDepth(1 + NarrowMemRspLatency),
            .ReadWrite(Cfg.AxiNarrowRW[i])
        ) u_axi_to_mem_adapter_narrow (
            .clk_i(clk_i),
            .rst_ni(rst_ni),
            .axi_req_i(axi_narrow_req_i[i]),
            .axi_rsp_o(axi_narrow_rsp_o[i]),
            .mem_req_o(mem_narrow_req_from_axi[id-:1+Cfg.AxiNarrowRW[i]]),
            .mem_rsp_i(mem_narrow_rsp_to_axi[id-:1+Cfg.AxiNarrowRW[i]])
        );
    end
    for (genvar i = 0; i < Cfg.NumAxiWideReq; i++) begin: axi_wide_adapter
        localparam int unsigned id = i + $countones(Cfg.AxiWideRW[i:0]);
        axi_to_mem_adapter #(
            .axi_req_t(axi_wide_req_t),
            .axi_rsp_t(axi_wide_rsp_t),
            .mem_req_t(mem_wide_req_t),
            .mem_rsp_t(mem_wide_rsp_t),
            .AddrWidth(Cfg.AddrWidth),
            .DataWidth(Cfg.WideDataWidth),
            .IdWidth(Cfg.AxiWideIdWidth),
            .MemDataWidth(Cfg.WideDataWidth),
            .BufDepth(1 + WideMemRspLatency),
            .ReadWrite(Cfg.AxiWideRW[i])
        ) u_axi_to_mem_adapter_wide (
            .clk_i(clk_i),
            .rst_ni(rst_ni),
            .axi_req_i(axi_wide_req_i[i]),
            .axi_rsp_o(axi_wide_rsp_o[i]),
            .mem_req_o(mem_wide_req_from_axi[id-:1+Cfg.AxiWideRW[i]]),
            .mem_rsp_i(mem_wide_rsp_to_axi[id-:1+Cfg.AxiWideRW[i]])
        );
    end

    // ------------
    // Entry spilling
    // ------------
    for (genvar i = 0; i < axi_rw_narrow_reqs; i++) begin: spill_narrow_entry
        mem_multicut #(
            .AddrWidth(Cfg.AddrWidth),
            .DataWidth(Cfg.NarrowDataWidth),
            .NumCutsReq(Cfg.SpillAxiNarrowReqEntry),
            .NumCutsRsp(Cfg.SpillAxiNarrowRspEntry),
            .mem_req_t(mem_narrow_req_t),
            .mem_rsp_t(mem_narrow_rsp_t)
        ) u_spill_narrow_entry (
            .clk_i(clk_i),
            .rst_ni(rst_ni),
            .req_i(mem_narrow_req_from_axi[i]),
            .req_o(mem_narrow_req_from_axi_q1[i]),
            .rsp_i(mem_narrow_rsp_to_axi[i]),
            .rsp_o(mem_narrow_rsp_to_axi_q1[i]),
            .read_ready_i(1'b1),
            .read_ready_o()
        );
    end

    for (genvar i = 0; i < axi_rw_wide_reqs; i++) begin: spill_wide_entry
        mem_multicut #(
            .AddrWidth(Cfg.AddrWidth),
            .DataWidth(Cfg.WideDataWidth),
            .NumCutsReq(Cfg.SpillAxiWideReqEntry),
            .NumCutsRsp(Cfg.SpillAxiWideRspEntry),
            .mem_req_t(mem_wide_req_t),
            .mem_rsp_t(mem_wide_rsp_t)
        ) u_spill_wide_entry (
            .clk_i(clk_i),
            .rst_ni(rst_ni),
            .req_i(mem_wide_req_from_axi[i]),
            .req_o(mem_wide_req_from_axi_q1[i]),
            .rsp_i(mem_wide_rsp_to_axi[i]),
            .rsp_o(mem_wide_rsp_to_axi_q1[i]),
            .read_ready_i(1'b1),
            .read_ready_o()
        );
    end

    // ------------
    // Memory island core
    // ------------
    memory_island_core #(
        .mem_narrow_req_t(mem_narrow_req_t),
        .mem_narrow_rsp_t(mem_narrow_rsp_t),
        .mem_wide_req_t(mem_wide_req_t),
        .mem_wide_rsp_t(mem_wide_rsp_t),
        .Cfg(Cfg)
    ) i_memory_island_core (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .mem_narrow_req_i(mem_narrow_req),
        .mem_narrow_rsp_o(mem_narrow_rsp),
        .mem_wide_req_i(mem_wide_req),
        .mem_wide_rsp_o(mem_wide_rsp)
    );
endmodule : memory_island_wrap
