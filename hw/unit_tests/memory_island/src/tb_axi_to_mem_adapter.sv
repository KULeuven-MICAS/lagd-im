// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

// Test from lagd_chip:
//      AddrWidth: 48
//      DataWidth: 64
//      IdWidth: 6
//      BufDepth: 2
//      ReadWrite: 0

`timescale 1ns/1ps

// Project-wide includes
`include "lagd_define.svh"
`include "lagd_typedef.svh"

// ETH AXI and memory interface includes
`include "axi/assign.svh"
`include "common_cells/assertions.svh"

// Testbench includes
`include "lagd_test/tb_common.svh"
`include "tb_config.svh"

module tb_axi_to_mem_adapter import lagd_pkg::*; #(
    parameter int unsigned AddrWidth = 48,
    parameter int unsigned DataWidth = 64,
    parameter int unsigned IdWidth = 6,
    parameter int unsigned BufDepth = 2,
    parameter bit ReadWrite = 1'b0
)();

    // Debug setup
    `SETUP_DEBUG(dbg, vcd_file, tb_axi_to_mem_adapter)
    `LAGD_TYPEDEF_ALL(lagd_, `IC_L1_J_MEM_DATA_WIDTH, CheshireCfg)

    // ========================================================================
    // SIGNALS AND INTERFACES
    // ========================================================================

    logic clk_i, rst_ni;
    logic test_complete;
    logic mismatch;

    lagd_axi_slv_req_t axi_req_i, axi_mst_req;
    lagd_axi_slv_rsp_t axi_rsp_o, axi_mst_rsp;

    lagd_mem_narr_req_t [ReadWrite:0] mem_req_o;
    lagd_mem_narr_rsp_t [ReadWrite:0] mem_rsp_i;

    // AXI bus for stimulus generation
    AXI_BUS_DV #(
        .AXI_ADDR_WIDTH(AddrWidth),
        .AXI_DATA_WIDTH(DataWidth),
        .AXI_ID_WIDTH(IdWidth),
        .AXI_USER_WIDTH(2)
    ) axi_dv (clk_i);

    `AXI_ASSIGN_TO_REQ(axi_mst_req, axi_dv)
    `AXI_ASSIGN_FROM_RESP(axi_dv, axi_mst_rsp)

    // ========================================================================
    // DUT INSTANTIATION
    // ========================================================================

    axi_to_mem_adapter #(
        .axi_req_t(lagd_axi_slv_req_t),
        .axi_rsp_t(lagd_axi_slv_rsp_t),
        .mem_req_t(lagd_mem_narr_req_t),
        .mem_rsp_t(lagd_mem_narr_rsp_t),
        .AddrWidth(AddrWidth),
        .DataWidth(DataWidth),
        .IdWidth(IdWidth),
        .BufDepth(BufDepth),
        .ReadWrite(ReadWrite)
    ) i_dut (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .axi_req_i(axi_req_i),
        .axi_rsp_o(axi_rsp_o),
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

    axi_rand_generator #(
        .AddrWidth(AddrWidth),
        .DataWidth(DataWidth),
        .IdWidth(IdWidth),
        .UserWidth(2)
    ) i_axi_stimulus (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .axi_bus(axi_dv),
        .test_complete_o(test_complete)
    );

    // ========================================================================
    // MEMORY MODEL
    // ========================================================================

    // Memory model
    localparam int unsigned NumWords = (TEST_REGION_END - TEST_REGION_START + 1) * 8 / DataWidth;
    virtual_memory #(
        .mem_req_t(lagd_mem_narr_req_t),
        .mem_rsp_t(lagd_mem_narr_rsp_t),
        .NumWords(NumWords),
        .DataWidth(DataWidth),
        .ReadWrite(ReadWrite)
    ) i_memory (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .mem_req_i(mem_req_o),
        .mem_rsp_o(mem_rsp_i)
    );

    // ========================================================================
    // GOLDEN MODEL AND COMPARATOR
    // ========================================================================

    tb_golden_model #(
        .axi_aw_chan_t(lagd_axi_slv_aw_chan_t),
        .axi_w_chan_t(lagd_axi_slv_w_chan_t),
        .axi_b_chan_t(lagd_axi_slv_b_chan_t),
        .axi_ar_chan_t(lagd_axi_slv_ar_chan_t),
        .axi_r_chan_t(lagd_axi_slv_r_chan_t),
        .axi_req_t(lagd_axi_slv_req_t),
        .axi_rsp_t(lagd_axi_slv_rsp_t),
        .AddrWidth(AddrWidth),
        .DataWidth(DataWidth),
        .IdWidth(IdWidth),
        .UserWidth(2)
    ) i_golden (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .axi_mst_req_i(axi_mst_req),
        .axi_mst_rsp_o(axi_mst_rsp),
        .axi_dut_req_o(axi_req_i),
        .axi_dut_rsp_i(axi_rsp_o),
        .mismatch_o(mismatch)
    );

    // ========================================================================
    // TEST CONTROL
    // ========================================================================

    initial begin
        // Wait for test to complete
        wait(test_complete);
        $finish(0);

        // Check for mismatches
        // if (mismatch) begin
        //     $error("Comparison mismatch detected!");
        //     $finish(1);
        // end else begin
        //     $display("Test completed successfully - no mismatches!");
        //     $finish(0);
        // end
    end

    // Simulation timeout watchdog
    // initial begin
    //     #(SIM_TIMEOUT);
    //     $error("Simulation timeout after %0tns", SIM_TIMEOUT);
    //     $finish(1);
    // end

endmodule