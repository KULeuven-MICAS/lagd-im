// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

// Module: wide_to_narrow_splitter

// MemAddrWidth:    [   9,   5]
// BankAddrWidth:   [   6,  10]
// MemDataWidth:    [4096, 256]
// BankDataWidth:   [  64,  64]
// WordSize:        [   8,   8]

`timescale 1ns/1ps

// Project-wide includes
`include "lagd_define.svh"
`include "lagd_typedef.svh"

// Testbench includes
`include "lagd_test/tb_common.svh"
`include "tb_config.svh"

module tb_wide_to_narrow_splitter #(
    parameter int unsigned MemAddrWidth = 9,
    parameter int unsigned BankAddrWidth = 6,
    parameter int unsigned MemDataWidth = 4096,
    parameter int unsigned BankDataWidth = 64,
    parameter int unsigned WordSize = 8,
    parameter int unsigned NumBanks = MemDataWidth / BankDataWidth,
    parameter int unsigned BankAddrOffset = $clog2(MemDataWidth/WordSize)
) ();

    // Debug setup
    `SETUP_DEBUG(dbg, vcd_file, tb_wide_to_narrow_splitter)
    `LAGD_TYPEDEF_ALL(lagd_, `IC_L1_J_MEM_DATA_WIDTH, lagd_pkg::CheshireCfg)

    // ========================================================================
    // SIGNALS AND INTERFACES
    // ========================================================================

    logic clk_i, rst_ni;

    lagd_mem_wide_req_t mem_req_i;
    lagd_mem_wide_rsp_t mem_rsp_o;

    lagd_mem_narr_req_t [NumBanks-1:0] bank_req_o;
    lagd_mem_narr_rsp_t [NumBanks-1:0] bank_rsp_i;

    // ========================================================================
    // DUT INSTANTIATION
    // ========================================================================

    wide_to_narrow_splitter #(
        .MemAddrWidth(MemAddrWidth),
        .BankAddrWidth(BankAddrWidth),
        .MemDataWidth(MemDataWidth),
        .BankDataWidth(BankDataWidth),
        .WordSize(WordSize),

        .mem_req_t(lagd_mem_wide_req_t),
        .mem_rsp_t(lagd_mem_wide_rsp_t),
        .bank_req_t(lagd_mem_narr_req_t),
        .bank_rsp_t(lagd_mem_narr_rsp_t)

    ) dut (
        .clk_i(clk_i),
        .rst_ni(rst_ni),

        .mem_req_i(mem_req_i),
        .mem_rsp_o(mem_rsp_o),

        .bank_req_o(bank_req_o),
        .bank_rsp_i(bank_rsp_i)
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

    initial begin
        mem_req_i = '0;
        @(posedge rst_ni);
        mem_req_i.q_valid = 1'b1;
        mem_req_i.q.addr  = 'h0000_1000;
        mem_req_i.q.data  = {{MemDataWidth-64{1'b0}},'hDEAD_BEEF_CAFE_BABE};
        mem_req_i.q.strb  = 'hFFFF;
        mem_req_i.q.write = 1'b1;
        mem_req_i.q.user  = '0;
        @(posedge clk_i);
        mem_req_i.q_valid = 1'b0;
        @(posedge clk_i);
    end
    
    logic end_of_sim;
    initial begin
        end_of_sim = 0;
        bank_rsp_i = '0;
        @(posedge rst_ni);
        wait (bank_req_o[0].q_valid == 1'b1);
        @(posedge clk_i);
        for (int unsigned i = 0; i < NumBanks; i++) begin
            bank_rsp_i[i].p.valid = 1'b1;
            bank_rsp_i[i].p.data  = bank_req_o[i].q.data;
        end
        @(posedge clk_i);
        for (int unsigned i = 0; i < NumBanks; i++) begin
            bank_rsp_i[i].p.valid = 1'b0;
        end
        @(posedge clk_i);
        end_of_sim = 1;
    end

    initial begin
        wait (end_of_sim);
        #100;
        $finish;
    end
endmodule