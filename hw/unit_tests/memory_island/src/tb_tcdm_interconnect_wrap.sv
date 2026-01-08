// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

// NumIn:           [ 1,  1,    1,  1,   1,  1]
// NumOut:          [ 1,  4,    1, 64,   1,  4] 
// AddrWidth:       [14, 16,   15, 15,  15, 15]
// DataWidth:       [64, 64, 4096, 64, 256, 64] 
// FullAddrWidth:   [48, 48,   48, 48,  48, 48]
// AddrMemWidth:    [11, 11,    6,  6,  10, 10]
// BeWidth:         [ 8,  8,    9,  8,   5,  8]
// RespLat:         [ 1,  1,    1,  1,   1,  1]

// Project-wide includes
`include "lagd_define.svh"
`include "lagd_typedef.svh"

// ETH AXI and memory interface includes
`include "common_cells/assertions.svh"

// Testbench includes
`include "lagd_test/tb_common.svh"
`include "tb_config.svh"

module tb_tcdm_interconnect_wrap #(
    parameter int unsigned NumIn = 1,
    parameter int unsigned NumOut = 1,
    parameter int unsigned AddrWidth = 14,
    parameter int unsigned DataWidth = 64,
    parameter int unsigned FullAddrWidth = 48,
    parameter int unsigned AddrMemWidth = 11,
    parameter int unsigned BeWidth = 8,
    parameter int unsigned RespLat = 1,

    parameter type mem_req_t = logic,
    parameter type mem_rsp_t = logic
) ();

    // Debug setup
    `SETUP_DEBUG(dbg, vcd_file, tb_mem_multicut)
    `LAGD_TYPEDEF_ALL(lagd_, `IC_L1_J_MEM_DATA_WIDTH, CheshireCfg)

    // ========================================================================
    // SIGNALS AND INTERFACES
    // ========================================================================

    logic clk_i, rst_ni;
    mem_req_t [NumIn-1:0] mem_req_i;
    mem_rsp_t [NumIn-1:0] mem_rsp_o;
    mem_req_t [NumOut-1:0] mem_req_o;
    mem_rsp_t [NumOut-1:0] mem_rsp_i;

    logic test_complete;

    // ========================================================================
    // DUT INSTANTIATION
    // ========================================================================

    tcdm_interconnect_wrap #(
        .NumIn(NumIn),
        .NumOut(NumOut),
        .AddrWidth(AddrWidth),
        .DataWidth(DataWidth),
        .FullAddrWidth(FullAddrWidth),
        .AddrMemWidth(AddrMemWidth),
        .BeWidth(BeWidth),
        .RespLat(RespLat),
        .mem_req_t(mem_req_t),
        .mem_rsp_t(mem_rsp_t)
    ) dut (
        .clk_i(clk_i),
        .rst_ni(rst_ni),

        .mem_req_i(mem_req_i),
        .mem_rsp_o(mem_rsp_o),

        .mem_req_o(mem_req_o),
        .mem_rsp_i(mem_rsp_i)
    );

    // ========================================================================
    // STIMULUS GENERATION
    // ========================================================================

    clk_rst_gen #(
        .RstClkCycles(RST_CYCLES),
        .ClkPeriod(CLK_PERIOD)
    ) i_clk_gen (
        .clk_o(clk_i),
        .rst_no(rst_ni)
    );

    for(genvar i = 0; i < NumIn; i++) begin : mst_agent_gen
        lagd_mem_narr_master_agent #(
            .AddrWidth(AddrWidth),
            .DataWidth(DataWidth),
            .BeWidth(BeWidth),
            .mem_req_t(mem_req_t),
            .mem_rsp_t(mem_rsp_t)
        ) mst_agent (
            .clk_i(clk_i),
            .rst_ni(rst_ni),

            .mem_req_o(mem_req_i[i]),
            .mem_rsp_i(mem_rsp_o[i])
        );
    end