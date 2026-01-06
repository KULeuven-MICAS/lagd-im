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

`timescale 1ns / 1ps

`include "lagd_define.svh"
`include "lagd_typedef.svh"

`include "axi/assign.svh"
`include "common_cells/assertions.svh"
`include "lagd_test/tb_common.svh"

module tb_axi_to_mem_adapter import lagd_pkg::*; #(
    parameter int unsigned AddrWidth = 48,
    parameter int unsigned DataWidth = 64,
    parameter int unsigned IdWidth = 6,
    parameter int unsigned BufDepth = 2,
    parameter bit ReadWrite = 1'b0
)();
    localparam int unsigned dbg = `DBG;
    localparam string vcd_file = `VCD_FILE;
    `SETUP_DEBUG(dbg, vcd_file, tb_axi_to_mem_adapter)
    `LAGD_TYPEDEF_ALL(lagd_, `IC_L1_J_MEM_DATA_WIDTH, CheshireCfg)
    
    // DUT ports declaration -----
    logic clk_i;
    logic rst_ni;
    lagd_axi_slv_req_t axi_req_i;
    lagd_axi_slv_rsp_t axi_rsp_o;
    lagd_mem_narr_rsp_t [ReadWrite:0] mem_rsp_i;
    lagd_mem_narr_req_t [ReadWrite:0] mem_req_o;
    // --------------------------
    // Instantiate DUT
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
    ) DUT (.*);
    // --------------------------

    // Clock/Reset generation
    clk_rst_gen #(
        .RstClkCycles(3),
        .ClkPeriod(`TC)
    ) i_clk_gen (
        .clk_o(clk_i),
        .rst_no(rst_ni)
    );

    // Random Master AXI generator
    localparam int unsigned TxInFlight = 16;
    localparam int unsigned UserWidth = 2;
    typedef axi_test::axi_rand_master#(
        .AW(AddrWidth),
        .DW(DataWidth),
        .IW(IdWidth),
        .UW(UserWidth),
        // Stimuli application and test time
        .TA(`TA),
        .TT(`TT),
        // Maximum number of read and write transactions in flight
        .MAX_READ_TXNS(TxInFlight),
        .MAX_WRITE_TXNS(TxInFlight),
        .SIZE_ALIGN(0),
        .AXI_MAX_BURST_LEN(0),
        .TRAFFIC_SHAPING(0),
        .AXI_EXCLS(1'b0),
        .AXI_ATOPS(1'b0),
        .AXI_BURST_FIXED(1'b0),
        .AXI_BURST_INCR(1'b1),
        .AXI_BURST_WRAP(1'b0),
        .UNIQUE_IDS(1'b0)
    ) axi_rand_master_t;
    axi_rand_master_t rand_master;

    // Response DV monitors
    AXI_BUS_DV #(
        .AXI_ADDR_WIDTH(AddrWidth),
        .AXI_DATA_WIDTH(DataWidth),
        .AXI_ID_WIDTH  (IdWidth),
        .AXI_USER_WIDTH(UserWidth)
    ) axi_dv (
        clk_i
    );

    logic rand_mem_filled;
    logic end_of_sim;
    localparam int unsigned TestRegionStart = 0;
    localparam int unsigned TestRegionEnd = 16*1024 - 1;
    localparam int unsigned TestNumWrites = 200;
    localparam int unsigned TestNumReads  = 200;

    // Simulation generation
    `AXI_ASSIGN_TO_REQ(axi_req_i, axi_dv)
    `AXI_ASSIGN_FROM_RESP(axi_dv, axi_rsp_o)
    initial begin
        rand_master = new(axi_dv);
        rand_mem_filled <= 1'b0;
        end_of_sim <= 1'b0;
        rand_master.add_memory_region(TestRegionStart, TestRegionEnd, 
                                      axi_pkg::DEVICE_NONBUFFERABLE);
        rand_master.reset();
        @(posedge rst_ni);
        rand_master.run(TestNumReads, TestNumWrites);
        rand_mem_filled <= 1'b1;
        // Wait for all transactions to complete
        repeat(100) @(posedge clk_i);
        end_of_sim <= 1'b1;
        $display("Test completed successfully!");
        $finish;
    end

    // Instance tc_sram for memory model
    localparam int unsigned NumWords = (TestRegionEnd - TestRegionStart + 1)*8 / DataWidth;
    logic [ReadWrite:0] rdata_valid;
    tc_sram #(
        .NumWords(NumWords),
        .DataWidth(DataWidth),
        .NumPorts(1 + ReadWrite)
    ) u_tc_sram (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .req_i(mem_req_o[0].q_valid),
        .we_i(mem_req_o[0].q.write),
        .addr_i(mem_req_o[0].q.addr[$clog2(DataWidth/8)+: $clog2(NumWords)]),
        .wdata_i(mem_req_o[0].q.data),
        .be_i(mem_req_o[0].q.strb),
        .rdata_o(mem_rsp_i[0].p.data)
    );

    assign mem_rsp_i[0].p.valid = rdata_valid[0];
    assign mem_rsp_i[0].q_ready = 1'b1;
    localparam int unsigned TA = `TA;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            rdata_valid <= '0;
        end else begin
        rdata_valid <= #TA mem_req_o[0].q_valid;
        end
    end

    // Simulation timeout watchdog
    initial begin
        #2000000ns;  // 1ms timeout
    //    $error("Simulation timeout!");
    //    $finish;
    end
endmodule