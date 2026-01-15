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
    parameter memory_island_pkg::mem_cfg_t Cfg = lagd_mem_cfg_pkg::L2MemCfg,
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
    logic test_complete;

    lagd_axi_slv_req_t [NumAxiNarrowReqSafe-1:0] axi_narrow_req_i;
    lagd_axi_slv_rsp_t [NumAxiNarrowReqSafe-1:0] axi_narrow_rsp_o;

    lagd_axi_wide_slv_req_t [NumAxiWideReqSafe-1:0] axi_wide_req_i;
    lagd_axi_wide_slv_rsp_t [NumAxiWideReqSafe-1:0] axi_wide_rsp_o;

    lagd_mem_narr_req_t [NumDirectNarrowReqSafe-1:0] mem_narrow_req_i;
    lagd_mem_narr_rsp_t [NumDirectNarrowReqSafe-1:0] mem_narrow_rsp_o;

    lagd_mem_wide_req_t [NumDirectWideReqSafe-1:0] mem_wide_req_i;
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

    axi_rand_generator #(
        .AddrWidth(Cfg.AddrWidth),
        .DataWidth(Cfg.NarrowDataWidth),
        .IdWidth(Cfg.AxiNarrowIdWidth),
        .UserWidth(2),
        .TestRegionStart(0),
        .TestRegionEnd(MemorySizeBytes)
    ) i_axi_stimulus (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .axi_bus(axi_dv),
        .test_complete_o(test_complete)
    );

    // ========================================================================
    // TEST CONTROL
    // ========================================================================

    initial begin
        // Wait for test to complete
        wait(test_complete);
        $finish(0);
    end


endmodule