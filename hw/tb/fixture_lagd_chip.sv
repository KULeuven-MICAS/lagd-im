// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

`include "lagd_typedef.svh"
`include "lagd_define.svh"

`ifndef LAGD_CHIP
`define LAGD_CHIP 0
`endif

module fixture_lagd_chip ();

  localparam int unsigned ChipTest = `LAGD_CHIP;
  logic [1:0] boot_mode;
  logic clk;
  logic rst_n;
  logic rtc;
  logic jtag_tck;
  logic jtag_trst_n;
  logic jtag_tms;
  logic jtag_tdi;
  logic jtag_tdo;
  logic jtag_tdo_oe;
  logic uart_tx;
  logic uart_rx;

  
  //==============================================
  // DUT
  //==============================================
  generate 
  if (ChipTest == 1) begin : gen_dut_lagd_chip
    logic pad_clk_i;
    logic pad_rst_ni;
    logic pad_boot_mode_0_i; assign pad_boot_mode_0_i = boot_mode[0];
    logic pad_boot_mode_1_i; assign pad_boot_mode_1_i = boot_mode[1];
    logic pad_jtag_tck_i; assign pad_jtag_tck_i = jtag_tck;
    logic pad_jtag_trst_ni; assign pad_jtag_trst_ni = jtag_trst_n;
    logic pad_jtag_tms_i; assign pad_jtag_tms_i = jtag_tms;
    logic pad_jtag_tdi_i; assign pad_jtag_tdi_i = jtag_tdi;
    logic pad_jtag_tdo_o; assign jtag_tdo = pad_jtag_tdo_o;
    logic pad_uart_tx_o; assign uart_tx = pad_uart_tx_o;
    logic pad_uart_rx_i; assign pad_uart_rx_i = uart_rx;
    logic pad_uart_rts_no;
    logic pad_uart_cts_ni;
    logic pad_spi_sck_i;
    logic pad_spi_cs_i;
    logic pad_spi_sd_0_io;
    logic pad_spi_sd_1_io;
    logic pad_spi_sd_2_io;
    logic pad_spi_sd_3_io;
    logic pad_clk_sel_i;
    logic pad_pll_strb_i;
    logic pad_pll_data_i;
    logic pad_pll_data_o;
    logic pad_pll_cfg_vld_strb_i;
    logic pad_pll_fb_clk_io;
    logic pll_vdda_i;
    logic pll_iref_i;
    logic pll_vco_vctrl_io;
    logic galena_vdd_i;
    logic galena_cu_iref_0_i;
    logic galena_cu_vup_0_i;
    logic galena_cu_vdn_0_i;
    logic galena_h_iref_0_i;
    logic galena_h_vup_0_i;
    logic galena_h_vdn_0_i;
    logic galena_cu_iref_1_i;
    logic galena_cu_vup_1_i;
    logic galena_cu_vdn_1_i;
    logic galena_h_iref_1_i;
    logic galena_h_vup_1_i;
    logic galena_h_vdn_1_i;

    lagd_chip dut (.*);
  end else begin : gen_dut_soc
    logic clk_i; assign clk_i = clk;
    logic rst_ni; assign rst_ni = rst_n;
    logic rtc_i; assign rtc_i = rtc;
    logic test_mode_i; assign test_mode_i = 1'b0;
    logic [1:0] boot_mode_i; assign boot_mode_i = boot_mode;
    logic jtag_tck_i; assign jtag_tck_i = jtag_tck;
    logic jtag_trst_ni; assign jtag_trst_ni = jtag_trst_n;
    logic jtag_tms_i; assign jtag_tms_i = jtag_tms;
    logic jtag_tdi_i; assign jtag_tdi_i = jtag_tdi;
    logic jtag_tdo_o; assign jtag_tdo = jtag_tdo_o;
    logic jtag_tdo_oe_o; assign jtag_tdo_oe = jtag_tdo_oe_o;
    logic uart_tx_o; assign uart_tx = uart_tx_o;
    logic uart_rx_i; assign uart_rx_i = uart_rx;
    logic uart_rts_no;
    logic uart_dtr_no;
    logic uart_cts_ni; assign uart_cts_ni = 1'b1;
    logic uart_dsr_ni; assign uart_dsr_ni = 1'b1;
    logic uart_dcd_ni; assign uart_dcd_ni = 1'b1;
    logic uart_rin_ni; assign uart_rin_ni = 1'b1;
    logic spi_sck_i;
    logic spi_cs_i;
    logic [3:0] spi_oen_o;
    logic [3:0] spi_sdi_i; assign spi_sdi_i = 4'b0;
    logic [3:0] spi_sdo_o;
    logic [lagd_pkg::SlinkNumChan-1:0] slink_rcv_clk_i; assign slink_rcv_clk_i = 1'b0;
    logic [lagd_pkg::SlinkNumChan-1:0] slink_rcv_clk_o;
    logic [lagd_pkg::SlinkNumChan-1:0][lagd_pkg::SlinkNumLanes-1:0] slink_i; assign slink_i = 1'b0;
    logic [lagd_pkg::SlinkNumChan-1:0][lagd_pkg::SlinkNumLanes-1:0] slink_o;
    wire [`NUM_ISING_CORES-1:0] galena_j_iref_i;
    wire [`NUM_ISING_CORES-1:0] galena_j_vup_i;
    wire [`NUM_ISING_CORES-1:0] galena_j_vdn_i;
    wire [`NUM_ISING_CORES-1:0] galena_h_iref_i;
    wire [`NUM_ISING_CORES-1:0] galena_h_vup_i;
    wire [`NUM_ISING_CORES-1:0] galena_h_vdn_i;
    wire [`NUM_ISING_CORES-1:0] galena_vread_i;

    lagd_soc dut (.*);
  end
  endgenerate

  //==============================================
  // Verification IP
  //==============================================

  `LAGD_TYPEDEF_ALL(lagd_, `IC_L1_J_MEM_DATA_WIDTH, `IC_L1_FLIP_MEM_DATA_WIDTH, lagd_pkg::CheshireCfg)
  tri i2c_sda;
  tri i2c_scl;
  tri spih_sck;
  tri [lagd_pkg::SpihNumCs-1:0] spih_csb;
  tri [3:0] spih_sd;
  vip_cheshire_soc #(
    .DutCfg(lagd_pkg::CheshireCfg),
    .axi_ext_mst_req_t(lagd_axi_mst_req_t),
    .axi_ext_mst_rsp_t(lagd_axi_mst_rsp_t),
    .axi_ext_llc_req_t(lagd_axi_slv_req_t),
    .axi_ext_llc_rsp_t(lagd_axi_slv_rsp_t)
  ) vip (
    .clk(clk),
    .rst_n(rst_n),
    .rtc(rtc),
    .boot_mode(boot_mode),
    .test_mode(),
    .axi_llc_mst_req('0),
    .axi_llc_mst_rsp(),
    .axi_slink_mst_req('0),
    .axi_slink_mst_rsp(),
    .jtag_tck(jtag_tck),
    .jtag_trst_n(jtag_trst_n),
    .jtag_tms(jtag_tms),
    .jtag_tdi(jtag_tdi),
    .jtag_tdo(jtag_tdo),
    .uart_tx(uart_tx),
    .uart_rx(uart_rx),
    .i2c_sda(i2c_sda),
    .i2c_scl(i2c_scl),
    .spih_sck(spih_sck),
    .spih_csb(spih_csb),
    .spih_sd(spih_sd),
    .slink_rcv_clk_i(),
    .slink_rcv_clk_o('0),
    .slink_i(),
    .slink_o('0)
  );

  // TODO: Add here Master SPI

endmodule : fixture_lagd_chip