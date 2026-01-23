// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

`include "lagd_typedef.svh"
`include "lagd_define.svh"

module fixture_lagd_chip ();

  //==============================================
  // DUT
  //==============================================

  logic pad_clk_i;
  logic pad_rst_ni;
  logic pad_boot_mode_0_i;
  logic pad_boot_mode_1_i;
  logic pad_jtag_tck_i;
  logic pad_jtag_trst_ni;
  logic pad_jtag_tms_i;
  logic pad_jtag_tdi_i;
  logic pad_jtag_tdo_o;
  logic pad_uart_tx_o;
  logic pad_uart_rx_i;
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

  //==============================================
  // Verification IP
  //==============================================

  `LAGD_TYPEDEF_ALL(lagd_, `IC_L1_J_MEM_DATA_WIDTH, `IC_L1_FLIP_MEM_DATA_WIDTH, lagd_pkg::CheshireCfg)

  vip_cheshire_soc #(
    .DutCfg(lagd_pkg::CheshireCfg),
    .axi_ext_mst_req_t(lagd_axi_mst_req_t),
    .axi_ext_mst_rsp_t(lagd_axi_mst_rsp_t),
    .axi_ext_llc_req_t(lagd_axi_slv_req_t),
    .axi_ext_llc_rsp_t(lagd_axi_slv_rsp_t)
  ) vip (
    .clk(pad_clk_i),
    .rst_n(pad_rst_ni),
    .boot_mode({pad_boot_mode_1_i, pad_boot_mode_0_i}),
    .test_mode(1'b0),
    .axi_llc_mst_req('0),
    .axi_llc_mst_rsp(),
    .axi_slink_mst_req('0),
    .axi_slink_mst_rsp(),
    .jtag_tck(pad_jtag_tck_i),
    .jtag_trst_n(pad_jtag_trst_ni),
    .jtag_tms(pad_jtag_tms_i),
    .jtag_tdi(pad_jtag_tdi_i),
    .jtag_tdo(pad_jtag_tdo_o),
    .uart_tx(pad_uart_tx_o),
    .uart_rx(pad_uart_rx_i),
    .i2c_sda(1'bz),
    .i2c_scl(1'bz),
    .spih_sck(1'bz),
    .spih_csb({lagd_pkg::SpihNumCs{1'bz}}),
    .spih_sd(4'bzzzz),
    .slink_rcv_clk_i(),
    .slink_rcv_clk_o('0),
    .slink_i(),
    .slink_o('0)
  );

  // TODO: Add here Master SPI

endmodule : fixture_lagd_chip