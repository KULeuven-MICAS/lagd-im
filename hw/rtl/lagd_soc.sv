// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

// Top-level module for LAGD system-on-chip

`include "lagd_define.svh"
`include "lagd_config.svh"
`include "lagd_typedef.svh"


module lagd_soc import lagd_pkg::*; #(
    // lagd_soc config
    parameter NUM_AXI_SLV = `LAGD_NUM_AXI_SLV,
    parameter NUM_REG_SLV = `LAGD_NUM_REG_SLV,
) (
    input logic         clk_i,
    input logic         rtc_i,  // Real Time clock input reference
    input logic         rst_ni,
    input logic         test_mode_i,
    input logic [1:0]   boot_mode_i,
    // JTAG interface
    input  logic  jtag_tck_i,
    input  logic  jtag_trst_ni,
    input  logic  jtag_tms_i,
    input  logic  jtag_tdi_i,
    output logic  jtag_tdo_o,
    output logic  jtag_tdo_oe_o,
    // UART interface
    output logic  uart_tx_o,
    input  logic  uart_rx_i,
    // UART modem flow control
    output logic  uart_rts_no,
    output logic  uart_dtr_no, // open,
    input  logic  uart_cts_ni,
    input  logic  uart_dsr_ni, // =1,
    input  logic  uart_dcd_ni,  // =1,
    input  logic  uart_rin_ni,  // =1,
    // SPI host interface
    output logic                  spih_sck_o,
    output logic                  spih_sck_en_o,
    output logic [SpihNumCs-1:0]  spih_csb_o,
    output logic [SpihNumCs-1:0]  spih_csb_en_o,
    output logic [ 3:0]           spih_sd_o,
    output logic [ 3:0]           spih_sd_en_o,
    input  logic [ 3:0]           spih_sd_i,
    // Serial link interface
    input  logic [SlinkNumChan-1:0]                     slink_rcv_clk_i,
    output logic [SlinkNumChan-1:0]                     slink_rcv_clk_o,
    input  logic [SlinkNumChan-1:0][SlinkNumLanes-1:0]  slink_i,
    output logic [SlinkNumChan-1:0][SlinkNumLanes-1:0]  slink_o
);

    // defines axi and register interface types
    `LAGD_TYPEDEF_ALL(lagd_, Cfg.cheshire_cfg)

    //////////////////////////////////////////////////////////
    // Wire declarations /////////////////////////////////////
    //////////////////////////////////////////////////////////
    // External AXI interconnect
    lagd_slv_req_t  [NUM_AXI_SLV-1:0] axi_ext_slv_req;
    lagd_slv_rsp_t  [NUM_AXI_SLV-1:0] axi_ext_slv_rsp;
    // Register interface
    lagd_reg_req_t  [NUM_REG_SLV-1:0] reg_ext_req;
    lagd_reg_rsp_t  [NUM_REG_SLV-1:0] reg_ext_rsp;

    //////////////////////////////////////////////////////////
    // Cheshire instantiation  ///////////////////////////////
    //////////////////////////////////////////////////////////
    cheshire_soc #(
        .Cfg                (Cfg.cheshire_cfg),
        .axi_ext_slv_req_t  (lagd_slv_req_t),
        .axi_ext_slv_rsp_t  (lagd_slv_rsp_t),
        .reg_ext_req_t      (lagd_reg_req_t),
        .reg_ext_rsp_t      (lagd_reg_rsp_t)
    ) i_cheshire_soc (
        .clk_i          (clk_i),
        .rst_ni         (rst_ni),
        .test_mode_i    (test_mode_i),
        .boot_mode_i    (boot_mode_i),
        .rtc_i          (rtc_i),
        // External AXI crosbar ports
        .axi_ext_slv_req_o  (lagd_ext_slv_req),
        .axi_ext_slv_rsp_i  (lagd_ext_slv_rsp),
        // Register interface
        .reg_ext_req_o  (lagd_reg_ext_req),
        .reg_ext_rsp_i  (lagd_reg_ext_rsp),
        // JTAG interface
        .jtag_tck_i     (jtag_tck_i),
        .jtag_trst_ni   (jtag_trst_ni),
        .jtag_tms_i     (jtag_tms_i),
        .jtag_tdi_i     (jtag_tdi_i),
        .jtag_tdo_o     (jtag_tdo_o),
        .jtag_tdo_oe_o  (jtag_tdo_oe_o),
        // UART interface
        .uart_tx_o  (uart_tx_o),
        .uart_rx_i  (uart_rx_i),
        // UART modem flow control
        .uart_rts_no    (uart_rts_no),
        .uart_dtr_no    (uart_dtr_no), // open,
        .uart_cts_ni    (uart_cts_ni),
        .uart_dsr_ni    (uart_dsr_ni), // =1,
        .uart_dcd_ni    (uart_dcd_ni), // =1,
        .uart_rin_ni    (uart_rin_ni), // =1,
        // SPI host interface
        .spih_sck_o     (spih_sck_o),
        .spih_sck_en_o  (spih_sck_en_o),
        .spih_csb_o     (spih_csb_o),
        .spih_csb_en_o  (spih_csb_en_o),
        .spih_sd_o      (spih_sd_o),
        .spih_sd_en_o   (spih_sd_en_o),
        .spih_sd_i      (spih_sd_i),
        // Serial link interface
        .slink_rcv_clk_i    (slink_rcv_clk_i),
        .slink_rcv_clk_o    (slink_rcv_clk_o),
        .slink_i            (slink_i),
        .slink_o            (slink_o)
    );

    //////////////////////////////////////////////////////////
    // Stack memory  /////////////////////////////////////////
    //////////////////////////////////////////////////////////
    axi_memory_island_wrap #(
        .AddrWidth          (lagd_mem_pkg::CVA6StackMemCfg.AddrWidth),
        .NarrowDataWidth    (lagd_mem_pkg::CVA6StackMemCfg.NarrowDataWidth),
        .AxiNarrowIdWidth   (lagd_mem_pkg::CVA6StackMemCfg.AxiNarrowIdWidth),
        .WideDataWidth      (lagd_mem_pkg::CVA6StackMemCfg.WideDataWidth),
        .NumWideBanks       (lagd_mem_pkg::CVA6StackMemCfg.NumWideBanks),

        .axi_narrow_req_t   (lagd_slv_req_t),
        .axi_narrow_rsp_t   (lagd_slv_rsp_t),
        .NumNarrowReq       (lagd_mem_pkg::CVA6StackMemCfg.NumNarrowReq),
        .NarrowRW           (lagd_mem_pkg::CVA6StackMemCfg.NarrowRW),
        .WideRW             (lagd_mem_pkg::CVA6StackMemCfg.WideRW),

        .SpillNarrowReqEntry    (lagd_mem_pkg::CVA6StackMemCfg.SpillNarrowReqEntry),
        .SpillNarrowRspEntry    (lagd_mem_pkg::CVA6StackMemCfg.SpillNarrowRspEntry),
        .SpillNarrowReqRouted   (lagd_mem_pkg::CVA6StackMemCfg.SpillNarrowReqRouted),
        .SpillNarrowRspRouted   (lagd_mem_pkg::CVA6StackMemCfg.SpillNarrowRspRouted),

        .SpillReqBank (lagd_mem_pkg::CVA6StackMemCfg.SpillReqBank),
        .SpillRspBank (lagd_mem_pkg::CVA6StackMemCfg.SpillRspBank),

        .WordsPerBank  (lagd_mem_pkg::CVA6StackMemCfg.WordsPerBank)
    ) i_stack_mem (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),
        // AXI slave interface
        .axi_s_req_i(axi_ext_slv_req[LagdSlvIdxEnum.STACK_MEM]),
        .axi_s_rsp_o(axi_ext_slv_rsp[LagdSlvIdxEnum.STACK_MEM])
    );

    //////////////////////////////////////////////////////////
    // L2 SPM  ///////////////////////////////////////////////
    //////////////////////////////////////////////////////////
    axi_memory_island_wrap #(
        .AddrWidth          (lagd_mem_pkg::L2MemCfg.AddrWidth),
        .NarrowDataWidth    (lagd_mem_pkg::L2MemCfg.NarrowDataWidth),
        .AxiNarrowIdWidth   (lagd_mem_pkg::L2MemCfg.AxiNarrowIdWidth),
        .WideDataWidth      (lagd_mem_pkg::L2MemCfg.WideDataWidth),
        .NumWideBanks       (lagd_mem_pkg::L2MemCfg.NumWideBanks),

        .axi_narrow_req_t   (lagd_slv_req_t),
        .axi_narrow_rsp_t   (lagd_slv_rsp_t),
        .NumNarrowReq       (lagd_mem_pkg::L2MemCfg.NumNarrowReq),
        .NarrowRW           (lagd_mem_pkg::L2MemCfg.NarrowRW),
        .WideRW             (lagd_mem_pkg::L2MemCfg.WideRW),

        .SpillNarrowReqEntry    (lagd_mem_pkg::L2MemCfg.SpillNarrowReqEntry),
        .SpillNarrowRspEntry    (lagd_mem_pkg::L2MemCfg.SpillNarrowRspEntry),
        .SpillNarrowReqRouted   (lagd_mem_pkg::L2MemCfg.SpillNarrowReqRouted),
        .SpillNarrowRspRouted   (lagd_mem_pkg::L2MemCfg.SpillNarrowRspRouted),

        .SpillReqBank (lagd_mem_pkg::L2MemCfg.SpillReqBank),
        .SpillRspBank (lagd_mem_pkg::L2MemCfg.SpillRspBank),

        .WordsPerBank  (lagd_mem_pkg::L2MemCfg.WordsPerBank),
    ) i_l2_mem (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),
        // AXI slave interface
        .axi_s_req_i(axi_ext_slv_req[LagdSlvIdxEnum.L2_MEM]),
        .axi_s_rsp_o(axi_ext_slv_rsp[LagdSlvIdxEnum.L2_MEM])
    );

    //////////////////////////////////////////////////////////
    // Ising cores instantiation ////////////////////////////
    //////////////////////////////////////////////////////////
    generate
        for (genvar i = 0; i < `NUM_ISING_CORES; i++) begin : gen_cores
            ising_core_wrap #(
                .l1_mem_cfg     (IsingCoreL1MemCfg),
                .axi_slv_req_t  (lagd_slv_req_t),
                .axi_slv_rsp_t  (lagd_slv_rsp_t),
                .reg_slv_req_t  (lagd_reg_req_t),
                .reg_slv_rsp_t  (lagd_reg_rsp_t)
            ) i_core (
                .clk_i      (clk_i),
                .rst_ni     (rst_ni),
                // AXI slave interface
                .axi_s_req_i(axi_ext_slv_req[LagdSlvIdxEnum.ISING_CORES_BASE + i]),
                .axi_s_rsp_o(axi_ext_slv_rsp[LagdSlvIdxEnum.ISING_CORES_BASE + i]),
                // Register interface
                .reg_s_req_i(reg_ext_req[i]),
                .reg_s_rsp_o(reg_ext_rsp[i])
            );
        end
    endgenerate

endmodule