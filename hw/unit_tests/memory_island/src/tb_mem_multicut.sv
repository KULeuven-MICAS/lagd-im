// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

// Test from lagd_chip:
//      AddrWidth: 48
//      DataWidth: 64
//      NumCutsReq: 0
//      NumCutsRsp: 0

//cuts do not work :)

`timescale 1ns/1ps

// Project-wide includes
`include "lagd_define.svh"
`include "lagd_typedef.svh"

// ETH AXI and memory interface includes
`include "common_cells/assertions.svh"

// Testbench includes
`include "lagd_test/tb_common.svh"
`include "tb_config.svh"

module tb_mem_multicut import lagd_pkg::*; #(
    parameter int unsigned AddrWidth = 48,
    parameter int unsigned DataWidth = 64,
    parameter int unsigned NumCutsReq = 0,
    parameter int unsigned NumCutsRsp = 0
)();

    // Debug setup
    `SETUP_DEBUG(dbg, vcd_file, tb_mem_multicut)
    `LAGD_TYPEDEF_ALL(lagd_, `IC_L1_J_MEM_DATA_WIDTH, CheshireCfg)

    // ========================================================================
    // SIGNALS AND INTERFACES
    // ========================================================================

    logic clk_i, rst_ni;

    lagd_mem_narr_req_t mem_req_o, mem_mst_req;
    lagd_mem_narr_rsp_t mem_rsp_o, mem_mst_rsp;

    logic read_ready_i, read_ready_o, mem_ready_i;

    logic test_complete;

    // ========================================================================
    // DUT INSTANTIATION
    // ========================================================================

    mem_multicut #(
        .AddrWidth(AddrWidth),
        .DataWidth(DataWidth),
        .NumCutsReq(NumCutsReq),
        .NumCutsRsp(NumCutsRsp),
        .mem_req_t(lagd_mem_narr_req_t),
        .mem_rsp_t(lagd_mem_narr_rsp_t)
    ) dut (
        .clk_i(clk_i),
        .rst_ni(rst_ni),

        .req_i(mem_mst_req),
        .req_o(mem_req_o),

        .rsp_i(mem_mst_rsp),
        .rsp_o(mem_rsp_o),

        .read_ready_i(read_ready_i),
        .read_ready_o(read_ready_o)
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

    mem_dummy_generator #(
        .AddrWidth(AddrWidth),
        .DataWidth(DataWidth),
        .mem_req_t(lagd_mem_narr_req_t),
        .mem_rsp_t(lagd_mem_narr_rsp_t)
    ) i_mem_gen (
        .clk_i(clk_i),
        .rst_ni(rst_ni),

        .req_o(mem_mst_req),
        .read_ready_i(read_ready_i),

        .rsp_o(mem_mst_rsp),
        .mem_ready_i(mem_ready_i),
        .test_complete_o(test_complete)
    );
    // ========================================================================
    // TESTBENCH CONTROL
    // ========================================================================
    initial begin
        read_ready_i = 1'b1;
        mem_ready_i  = 1'b1;
        wait(test_complete);
        $finish(0);
    end
endmodule