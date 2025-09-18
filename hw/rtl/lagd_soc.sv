// Copyright 2025 KU Leuven.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

// Top-level module for LAGD system-on-chip

module lagd_soc import lagd_pkg::*; #(
    // lagd_soc config
    parameter lagd_cfg_t Cfg = default_lagd_cfg,
    // interconnect types
    parameter type 
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
    input  logic  uart_dcd_ni  // =1,
    input  logic  uart_rin_ni  // =1,
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
)
endmodule