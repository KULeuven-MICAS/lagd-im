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

