// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

// Module description:
// Wrapper for memory island module

// This module was inspired by 
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

    localparam int unsigned rw_narrow_reqs = Cfg.NumDirectNarrowReq + $countones(Cfg.NarrowRW);
    mem_narrow_req_t [rw_narrow_reqs-1:0] mem_narrow_req_from_axi;
    mem_narrow_rsp_t [rw_narrow_reqs-1:0] mem_narrow_rsp_to_axi;

    localparam int unsigned rw_wide_reqs = Cfg.NumDirectWideReq + $countones(Cfg.WideRW);
    mem_wide_req_t [rw_wide_reqs-1:0] mem_wide_req_from_axi;
    mem_wide_rsp_t [rw_wide_reqs-1:0] mem_wide_rsp_to_axi;

    localparam int unsigned total_narrow_reqs = rw_narrow_reqs + Cfg.NumDirectNarrowReq;
    mem_narrow_req_t [total_narrow_reqs-1:0] mem_narrow_req;
    mem_narrow_rsp_t [total_narrow_reqs-1:0] mem_narrow_rsp;
    assign mem_narrow_rsp = {mem_narrow_rsp_to_axi, mem_narrow_rsp_i};
    assign mem_narrow_req = {mem_narrow_req_from_axi, mem_narrow_req_i};

    localparam int unsigned total_wide_reqs = rw_wide_reqs + Cfg.NumDirectWideReq;
    mem_wide_req_t [total_wide_reqs-1:0] mem_wide_req;
    mem_wide_rsp_t [total_wide_reqs-1:0] mem_wide_rsp;
    assign mem_wide_rsp = {mem_wide_rsp_to_axi, mem_wide_rsp_i};
    assign mem_wide_req = {mem_wide_req_from_axi, mem_wide_req_i};

    // ------------
    // Axi to mem adapters
    // ------------

    for (genvar i = 0; i < Cfg.NumAxiNarrowReq; i++) begin: axi_narrow_adapter
        localparam int unsigned id = i + $countones(Cfg.NarrowRW[i:0]);
        axi_to_mem_adapter #(
            .Cfg(Cfg),
            .RW(Cfg.NarrowRW[i]),
            .axi_req_t(axi_narrow_req_t),
            .axi_rsp_t(axi_narrow_rsp_t),
            .mem_req_t(mem_narrow_req_t),
            .mem_rsp_t(mem_narrow_rsp_t)
        ) i_axi_to_mem_adapter_narrow (
            .clk_i(clk_i),
            .rst_ni(rst_ni),
            .axi_req_i(axi_narrow_req_i[i]),
            .axi_rsp_o(axi_narrow_rsp_o[i]),
            .mem_req_o(mem_narrow_req_i[id-:1+Cfg.NarrowRW[i]]),
            .mem_rsp_i(mem_narrow_rsp_o[id-:1+Cfg.NarrowRW[i]])
        );
    end
    for (genvar i = 0; i < Cfg.NumAxiWideReq; i++) begin: axi_wide_adapter
        localparam int unsigned id = i + $countones(Cfg.WideRW[i:0]);
        axi_to_mem_adapter #(
            .Cfg(Cfg),
            .RW(Cfg.WideRW[i]),
            .axi_req_t(axi_wide_req_t),
            .axi_rsp_t(axi_wide_rsp_t),
            .mem_req_t(mem_wide_req_t),
            .mem_rsp_t(mem_wide_rsp_t)
        ) i_axi_to_mem_adapter_wide (
            .clk_i(clk_i),
            .rst_ni(rst_ni),
            .axi_req_i(axi_wide_req_i[i]),
            .axi_rsp_o(axi_wide_rsp_o[i]),
            .mem_req_o(mem_wide_req_i[id-:1+Cfg.WideRW[i]]),
            .mem_rsp_i(mem_wide_rsp_o[id-:1+Cfg.WideRW[i]])
        );
    end

    memory_island_core #(
        .Cfg(Cfg),
        .mem_narrow_req_t(mem_narrow_req_t),
        .mem_narrow_rsp_t(mem_narrow_rsp_t),
        .mem_wide_req_t(mem_wide_req_t),
        .mem_wide_rsp_t(mem_wide_rsp_t)
    ) i_memory_island_core (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .mem_narrow_req_i(mem_narrow_req),
        .mem_narrow_rsp_o(mem_narrow_rsp),
        .mem_wide_req_i(mem_wide_req),
        .mem_wide_rsp_o(mem_wide_rsp)
    );

endmodule