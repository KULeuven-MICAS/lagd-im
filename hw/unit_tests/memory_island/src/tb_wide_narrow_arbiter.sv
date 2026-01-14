// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

// NumNarrowBanks:  [  1,  4,   64,   4]
// NumWideBanks:    [  1,  4,    1,   1]
// WideDataWidth:   [ 64, 64, 4096, 256]
// NarrowDataWidth: [ 64, 64,   64,  64]

// Validated only on the third configuration above.

`timescale 1ns/1ps

// Project-wide includes
`include "lagd_define.svh"
`include "lagd_typedef.svh"

// Testbench includes
`include "lagd_test/tb_common.svh"
`include "tb_config.svh"

module tb_wide_narrow_arbiter #(
    parameter int unsigned NumNarrowBanks = 64,
    parameter int unsigned NumWideBanks = 1,
    parameter int unsigned WideDataWidth = 4096,
    parameter int unsigned NarrowDataWidth = 64
) ();

    // Debug setup
    `SETUP_DEBUG(dbg, vcd_file, tb_wide_narrow_arbiter)
    `LAGD_TYPEDEF_ALL(lagd_, `IC_L1_J_MEM_DATA_WIDTH, lagd_pkg::CheshireCfg)

    // ========================================================================
    // SIGNALS AND INTERFACES
    // ========================================================================

    logic clk_i, rst_ni;

    // Narrow ports
    lagd_mem_narr_req_t [NumNarrowBanks-1:0] mem_narrow_req_i;
    lagd_mem_narr_rsp_t [NumNarrowBanks-1:0] mem_narrow_rsp_o;

    // Wide ports
    lagd_mem_wide_req_t [NumWideBanks-1:0] mem_wide_req_i;
    lagd_mem_wide_rsp_t [NumWideBanks-1:0] mem_wide_rsp_o;

    // ========================================================================
    // DUT INSTANTIATION
    // ========================================================================

    wide_narrow_arbiter #(
        .NumNarrowBanks(NumNarrowBanks),
        .NumWideBanks(NumWideBanks),
        .WideDataWidth(WideDataWidth),
        .NarrowDataWidth(NarrowDataWidth),

        .mem_narrow_req_t(lagd_mem_narr_req_t),
        .mem_narrow_rsp_t(lagd_mem_narr_rsp_t),
        .mem_wide_req_t(lagd_mem_wide_req_t),
        .mem_wide_rsp_t(lagd_mem_wide_rsp_t)

    ) dut (
        .clk_i(clk_i),
        .rst_ni(rst_ni),

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

    logic narr_done, wide_done;
    initial begin
        mem_narrow_req_i = '0;
        narr_done = 1'b0;
        @(posedge rst_ni);
        @(posedge clk_i);
        mem_narrow_req_i[0].q_valid <= #TA 1'b1;
        @(posedge clk_i);
        while (mem_narrow_rsp_o[0].q_ready !== 1'b1) begin
            @(posedge clk_i);
        end
        mem_narrow_req_i[0].q_valid <= #TA 1'b0;
        @(posedge clk_i);
        narr_done = 1'b1;
    end

    initial begin
        mem_wide_req_i = '0;
        wide_done = 1'b0;
        @(posedge rst_ni);
        @(posedge clk_i);
        mem_wide_req_i[0].q_valid <= #TA 1'b1;
        @(posedge clk_i);
        while (mem_wide_rsp_o[0].q_ready !== 1'b1) begin
            @(posedge clk_i);
        end
        mem_wide_req_i[0].q_valid <= #TA 1'b0;
        @(posedge clk_i);
        wide_done = 1'b1;
    end

    initial begin
        wait(narr_done && wide_done);
        repeat (10) @(posedge clk_i);
        $finish;
    end
endmodule