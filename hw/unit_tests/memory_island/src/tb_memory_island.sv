// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

`timescale 1ns/1ps

`include "lagd_define.svh"
`include "lagd_platform.svh"
`include "lagd_typedef.svh"

// ETH AXI and memory interface includes
`include "axi/assign.svh"
`include "common_cells/assertions.svh"

// Testbench includes
`include "lagd_test/tb_common.svh"
`include "tb_config.svh"

module tb_memory_island import lagd_pkg::*; #(
    parameter memory_island_pkg::mem_cfg_t Cfg = lagd_mem_cfg_pkg::IsingCoreL1MemCfgFlip,
    parameter int unsigned RandTest = 1,
    // Derived parameters - Do not override
    parameter int unsigned MemorySizeBytes = Cfg.WordsPerBank * (Cfg.NarrowDataWidth/8) * Cfg.NumNarrowBanks,
    parameter int unsigned NumAxiNarrowReqSafe = `ZWIDTH_SAFE(Cfg.NumAxiNarrowReq),
    parameter int unsigned NumAxiWideReqSafe = `ZWIDTH_SAFE(Cfg.NumAxiWideReq),
    parameter int unsigned NumDirectNarrowReqSafe = `ZWIDTH_SAFE(Cfg.NumDirectNarrowReq),
    parameter int unsigned NumDirectWideReqSafe = `ZWIDTH_SAFE(Cfg.NumDirectWideReq)
) ();

    // Debug setup
    `SETUP_DEBUG(dbg, vcd_file, tb_memory_island)
    `LAGD_TYPEDEF_ALL(lagd_, `IC_L1_J_MEM_DATA_WIDTH, CheshireCfg)

    // ========================================================================
    // SIGNALS AND INTERFACES
    // ========================================================================

    logic clk_i, rst_ni;
    logic axi_write_complete, direct_write_complete, direct_read_complete;
    logic test_complete;

    lagd_axi_slv_req_t [NumAxiNarrowReqSafe-1:0] axi_narrow_req_i;
    lagd_axi_slv_rsp_t [NumAxiNarrowReqSafe-1:0] axi_narrow_rsp_o;

    lagd_axi_wide_slv_req_t [NumAxiWideReqSafe-1:0] axi_wide_req_i;
    lagd_axi_wide_slv_rsp_t [NumAxiWideReqSafe-1:0] axi_wide_rsp_o;

    lagd_mem_narr_req_t [NumDirectNarrowReqSafe-1:0] mem_narrow_req_i;
    lagd_mem_narr_rsp_t [NumDirectNarrowReqSafe-1:0] mem_narrow_rsp_o;

    lagd_mem_wide_req_t [NumDirectWideReqSafe-1:0] mem_wide_req_i_r, mem_wide_req_i_w, mem_wide_req_i;
    lagd_mem_wide_rsp_t [NumDirectWideReqSafe-1:0] mem_wide_rsp_o;
    // AXI bus for stimulus generation
    AXI_BUS_DV #(
        .AXI_ADDR_WIDTH(Cfg.AddrWidth),
        .AXI_DATA_WIDTH(Cfg.NarrowDataWidth),
        .AXI_ID_WIDTH(Cfg.AxiNarrowIdWidth),
        .AXI_USER_WIDTH(2)
    ) axi_dv (clk_i);

    `AXI_ASSIGN_TO_REQ(axi_narrow_req_i[0], axi_dv)
    `AXI_ASSIGN_FROM_RESP(axi_dv, axi_narrow_rsp_o[0])


    // ========================================================================
    // DUT INSTANTIATION
    // ========================================================================

    memory_island_wrap #(
        .Cfg(Cfg),
        .axi_narrow_req_t(lagd_axi_slv_req_t),
        .axi_narrow_rsp_t(lagd_axi_slv_rsp_t),
        .axi_wide_req_t(lagd_axi_wide_slv_req_t),
        .axi_wide_rsp_t(lagd_axi_wide_slv_rsp_t),
        .mem_narrow_req_t(lagd_mem_narr_req_t),
        .mem_narrow_rsp_t(lagd_mem_narr_rsp_t),
        .mem_wide_req_t(lagd_mem_wide_req_t),
        .mem_wide_rsp_t(lagd_mem_wide_rsp_t)
    ) dut (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .axi_narrow_req_i(axi_narrow_req_i),
        .axi_narrow_rsp_o(axi_narrow_rsp_o),
        .axi_wide_req_i(),  // Never used in lagd_soc
        .axi_wide_rsp_o(),  // Never used in lagd_soc
        .mem_narrow_req_i(mem_narrow_req_i),
        .mem_narrow_rsp_o(mem_narrow_rsp_o),
        .mem_wide_req_i(mem_wide_req_i),
        .mem_wide_rsp_o(mem_wide_rsp_o)
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

    generate
        if (Cfg.NumAxiNarrowReq != 0) begin  : axi_rand_generator
            if (RandTest) begin : gen_random_stimulus
                // Random stimulus generation through AXI master
                axi_rand_generator #(
                    .AddrWidth(Cfg.AddrWidth),
                    .DataWidth(Cfg.NarrowDataWidth),
                    .IdWidth(Cfg.AxiNarrowIdWidth),
                    .UserWidth(2),
                    .TestRegionStart(0),
                    .TestRegionEnd(MemorySizeBytes),
                    .NumReadTransactions(0),
                    .NumWriteTransactions(1)
                ) i_axi_stimulus (
                    .clk_i(clk_i),
                    .rst_ni(rst_ni),
                    .axi_bus(axi_dv),
                    .test_start_i(1'b1),
                    .test_complete_o(axi_write_complete)
                );
            end
        end else begin : no_axi_req
            // No AXI requests, test is complete immediately
            assign axi_write_complete = 1'b1;
        end
    endgenerate

    generate
        if (Cfg.NumDirectWideReq != 0) begin : mem_seq_generator_write
            // Sequential memory stimulus generation
            mem_seq_stim_gen #(
                .AddrWidth(Cfg.AddrWidth),
                .DataWidth(Cfg.WideDataWidth),
                .Write(1),
                .DataRandom(0),
                .RandMaster(1),
                .NumTransactions(10),
                .TestRegionStart(0),
                .TestRegionEnd(MemorySizeBytes),
                .mem_req_t(lagd_mem_wide_req_t),
                .mem_rsp_t(lagd_mem_wide_rsp_t)
            ) i_mem_seq_stimulus (
                .clk_i(clk_i),
                .rst_ni(rst_ni),
                .mem_req_o(mem_wide_req_i_w[0]),
                .mem_rsp_i(mem_wide_rsp_o[0]),
                .test_start_i(axi_write_complete),
                .test_complete_o(direct_write_complete)
            );
        end else begin : no_mem_req_write
            // No direct memory requests, test is complete immediately
            assign direct_write_complete = 1'b1;
        end
    endgenerate

    generate
        if (Cfg.NumDirectWideReq != 0) begin : mem_seq_generator_read
            // Sequential memory stimulus generation
            mem_seq_stim_gen #(
                .AddrWidth(Cfg.AddrWidth),
                .DataWidth(Cfg.WideDataWidth),
                .Write(0),
                .DataRandom(0),
                .RandMaster(1),
                .NumTransactions(10),
                .TestRegionStart(0),
                .TestRegionEnd(MemorySizeBytes),
                .mem_req_t(lagd_mem_wide_req_t),
                .mem_rsp_t(lagd_mem_wide_rsp_t)
            ) i_mem_seq_stimulus (
                .clk_i(clk_i),
                .rst_ni(rst_ni),
                .mem_req_o(mem_wide_req_i_r[0]),
                .mem_rsp_i(mem_wide_rsp_o[0]),
                .test_start_i(direct_write_complete),
                .test_complete_o(direct_read_complete)
            );
        end else begin : no_mem_req_read
            // No direct memory requests, test is complete immediately
            assign direct_read_complete = 1'b1;
        end
    endgenerate

    assign mem_wide_req_i = (direct_write_complete) ? mem_wide_req_i_r : mem_wide_req_i_w;
    // ========================================================================
    // TEST CONTROL
    // ========================================================================
    assign test_complete = axi_write_complete & direct_write_complete & direct_read_complete;
    initial begin
        // Wait for test to complete
        wait(test_complete);
        $finish(0);
    end

endmodule