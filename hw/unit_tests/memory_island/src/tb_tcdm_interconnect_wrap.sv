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

// [0] Stack Memory Test 16KB: it is a passthrough test with a single master and single bank
// [1] L2 Memory Test 64KB: 1 input, 4 output banks
// [2] J memory wide 32KB: 1 input, 1 output, wide data (4096 bits)
// [3] J memory narr 32KB: 1 input, 64 output banks
// [4] Flip memory wide 32KB: 1 input, 1 output, wide data (256 bits)
// [5] Flip memory narr 32KB: 1 input, 4 output banks

`timescale 1ns/1ps

// Project-wide includes
`include "lagd_define.svh"
`include "lagd_typedef.svh"

// Testbench includes
`include "lagd_test/tb_common.svh"
`include "tb_config.svh"

module tb_tcdm_interconnect_wrap #(
    parameter int unsigned NumIn = 1,
    parameter int unsigned NumOut = 4,
    parameter int unsigned AddrWidth = 16,
    parameter int unsigned DataWidth = 64,
    parameter int unsigned FullAddrWidth = 48,
    parameter int unsigned AddrMemWidth = 11,
    parameter int unsigned BeWidth = 8,
    parameter int unsigned RespLat = 1,

    parameter type mem_req_t = logic,
    parameter type mem_rsp_t = logic
) ();

    // Debug setup
    `SETUP_DEBUG(dbg, vcd_file, tb_tcdm_interconnect_wrap)
    `LAGD_TYPEDEF_ALL(lagd_, `IC_L1_J_MEM_DATA_WIDTH, lagd_pkg::CheshireCfg)

    // ========================================================================
    // SIGNALS AND INTERFACES
    // ========================================================================

    logic clk_i, rst_ni;
    lagd_mem_narr_req_t [NumIn-1:0] mem_req_i;
    lagd_mem_narr_rsp_t [NumIn-1:0] mem_rsp_o;
    lagd_mem_narr_req_t [NumOut-1:0] mem_req_o;
    lagd_mem_narr_rsp_t [NumOut-1:0] mem_rsp_i;

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
        .mem_req_t(lagd_mem_narr_req_t),
        .mem_rsp_t(lagd_mem_narr_rsp_t)
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

    logic [NumIn:0] daisy_chain_start;
    initial begin
        daisy_chain_start[0] = 1'b1;
    end
    for(genvar i = 0; i < NumIn; i++) begin : mst_agent_gen
        mem_seq_generator #(
            .AddrWidth(AddrWidth),
            .DataWidth(DataWidth),
            .TestRegionStart(0),
            .TestRegionEnd(1 << ($clog2(BeWidth) + $clog2(NumOut))),
            .NumTransactions(NumOut),
            .mem_req_t(lagd_mem_narr_req_t)
        ) mst_agent (
            .clk_i(clk_i),
            .rst_ni(rst_ni),
            .start_test_i(daisy_chain_start[i]),
            .req_o(mem_req_i[i]),
            .read_ready_i(mem_rsp_o[i].q_ready),
            .test_complete_o(daisy_chain_start[i+1])
        );
    end
    for(genvar j = 0; j < NumOut; j++) begin : slv_agent_gen
        initial begin
            mem_rsp_i[j].q_ready = 1'b1; // not correct! should be a gnt
        end
    end
    assign test_complete = daisy_chain_start[NumIn];
    // ========================================================================
    // TEST CONTROL
    // ========================================================================

    initial begin
        wait(test_complete);
        repeat (10) @(posedge clk_i);
        $finish(0);
    end
endmodule