// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

`include "lagd_typedef.svh"
`include "lagd_define.svh"


module tc_digital_io #(
    parameter int VerticalIO = 0
) (
    // Input data
    input wire data_i,
    // Output data
    output wire data_o,
    // IO interface towards pad + ctrl
    input wire io_direction_oe_ni,
    input wire [3:0] io_driving_strength_i,
    input wire io_pullup_en_i,
    input wire io_pulldown_en_i,
    inout wire io
);

`ifndef VERILATOR
  // Pull-ups and pull-downs
  assign (weak1, weak0) io = io_pullup_en_i ? 1'b1 : 1'bz;
  assign (weak0, weak1) io = io_pulldown_en_i ? 1'b0 : 1'bz;
`endif

  // IO chip -> pad
  assign io = io_direction_oe_ni ? 1'bz : data_i;

  // IO pad -> chip
  assign data_o = io;
endmodule : tc_digital_io

module fixture_lagd_chip #(
  parameter int unsigned ChipTest = 0
) ();
  localparam SPITCK = 20ns; // SPI clock 50MHz
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
  // Internal SPI signals
  logic spi_sck_i;
  logic spi_csb_i;
  logic [3:0] spi_oen_o;
  logic [3:0] spi_sdi_i;  // Input data from SPI lines
  logic [3:0] spi_sdo_o;  // Output data to SPI lines

  // EXTRENAL SPIS Signals
  logic spis_sck_i;
  logic spis_csb_i;
  logic spis_drive_enable;
  tri [3:0] spis_sd_io;  // Bidirectional SPI data lines
  logic [3:0] spis_sd_i;
  logic [3:0] spis_sd_o;

  logic pll_test_done;

  //==============================================
  // DUT
  //==============================================
  generate 
  if (ChipTest == 1) begin : gen_dut_lagd_chip
    $info("Instantiating lagd_chip as DUT");
  
    // PLL Control Signals
    logic pll_strb;
    logic pll_data;
    logic pll_cfg_vld_strb;

    wire pad_clk_i; assign pad_clk_i = clk;
    wire pad_clk_o;
    wire pad_rtc_i; assign pad_rtc_i = rtc;
    wire pad_rst_ni; assign pad_rst_ni = rst_n;
    wire pad_boot_mode_0_i; assign pad_boot_mode_0_i = boot_mode[0];
    wire pad_boot_mode_1_i; assign pad_boot_mode_1_i = boot_mode[1];
    wire pad_jtag_tck_i; assign pad_jtag_tck_i = jtag_tck;
    wire pad_jtag_trst_ni; assign pad_jtag_trst_ni = jtag_trst_n;
    wire pad_jtag_tms_i; assign pad_jtag_tms_i = jtag_tms;
    wire pad_jtag_tdi_i; assign pad_jtag_tdi_i = jtag_tdi;
    wire pad_jtag_tdo_o; assign jtag_tdo = pad_jtag_tdo_o;
    wire pad_uart_tx_o; assign uart_tx = pad_uart_tx_o;
    wire pad_uart_rx_i; assign pad_uart_rx_i = uart_rx;
    wire pad_uart_rts_no;
    wire pad_uart_cts_ni; assign pad_uart_cts_ni = 1'b1;
    wire pad_spi_sck_i; assign pad_spi_sck_i = spis_sck_i;
    wire pad_spi_cs_i; assign pad_spi_cs_i = spis_csb_i;
    tri pad_spi_sd_0_io; assign pad_spi_sd_0_io = spis_sd_io[0]; assign spis_sd_o[0] = pad_spi_sd_0_io;
    tri pad_spi_sd_1_io; assign pad_spi_sd_1_io = spis_sd_io[1]; assign spis_sd_o[1] = pad_spi_sd_1_io;
    tri pad_spi_sd_2_io; assign pad_spi_sd_2_io = spis_sd_io[2]; assign spis_sd_o[2] = pad_spi_sd_2_io;
    tri pad_spi_sd_3_io; assign pad_spi_sd_3_io = spis_sd_io[3]; assign spis_sd_o[3] = pad_spi_sd_3_io;
    wire pad_clk_sel_i; assign pad_clk_sel_i = 1'b1;
    wire pad_pll_strb_i; assign pad_pll_strb_i = pll_strb;
    wire pad_pll_data_i; assign pad_pll_data_i = pll_data;
    wire pad_pll_data_o;
    wire pad_pll_cfg_vld_strb_i; assign pad_pll_cfg_vld_strb_i = pll_cfg_vld_strb;
    wire pad_pll_fb_clk_io;
    wire pad_pll_lock_o;
    wire pll_iref_i;
    wire pll_vco_vctrl_io;
    wire galena_j_iref_0_i;
    wire galena_j_vup_0_i;
    wire galena_j_vdn_0_i;
    wire galena_h_iref_0_i;
    wire galena_h_vup_0_i;
    wire galena_h_vdn_0_i;
    wire galena_vread_0_i;
    wire galena_j_iref_1_i;
    wire galena_j_vup_1_i;
    wire galena_j_vdn_1_i;
    wire galena_h_iref_1_i;
    wire galena_h_vup_1_i;
    wire galena_h_vdn_1_i;
    wire galena_vread_1_i;

    lagd_chip dut (.*);
    pll_tester i_pll_tester (
      .clk_i(clk),
      .data_strb_o(pll_strb),
      .data_o(pll_data),
      .cfg_vld_strb_o(pll_cfg_vld_strb),
      .test_done(pll_test_done)
    );
  end else begin : gen_dut_soc
    $info("Instantiating lagd_soc as DUT");
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
    assign pll_test_done = 1'b1; // Not testing PLL in SoC test, so tie this to done
    
    wire [`NUM_ISING_CORES-1:0] galena_j_iref_i;
    wire [`NUM_ISING_CORES-1:0] galena_j_vup_i;
    wire [`NUM_ISING_CORES-1:0] galena_j_vdn_i;
    wire [`NUM_ISING_CORES-1:0] galena_h_iref_i;
    wire [`NUM_ISING_CORES-1:0] galena_h_vup_i;
    wire [`NUM_ISING_CORES-1:0] galena_h_vdn_i;
    wire [`NUM_ISING_CORES-1:0] galena_vread_i;

    lagd_soc dut (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .rtc_i(rtc_i),
      .test_mode_i(test_mode_i),
      .boot_mode_i(boot_mode_i),
      .jtag_tck_i(jtag_tck_i),
      .jtag_trst_ni(jtag_trst_ni),
      .jtag_tms_i(jtag_tms_i),
      .jtag_tdi_i(jtag_tdi_i),
      .jtag_tdo_o(jtag_tdo_o),
      .jtag_tdo_oe_o(jtag_tdo_oe_o),
      .uart_tx_o(uart_tx_o),
      .uart_rx_i(uart_rx_i),
      .uart_rts_no(uart_rts_no),
      .uart_dtr_no(uart_dtr_no),
      .uart_cts_ni(uart_cts_ni),
      .uart_dsr_ni(uart_dsr_ni),
      .uart_dcd_ni(uart_dcd_ni),
      .uart_rin_ni(uart_rin_ni),
      .spi_sck_i(spi_sck_i),
      .spi_cs_i(spi_csb_i),
      .spi_oen_o(spi_oen_o),
      .spi_sdi_i(spi_sdi_i),
      .spi_sdo_o(spi_sdo_o),
      .galena_j_vup_i(galena_j_vup_i),
      .galena_j_vdn_i(galena_j_vdn_i),
      .galena_h_vup_i(galena_h_vup_i),
      .galena_h_vdn_i(galena_h_vdn_i),
      .galena_vread_i(galena_vread_i)
    );
  assign spis_sd_o = spis_sd_io;
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
    .axi_ext_llc_rsp_t(lagd_axi_slv_rsp_t),
    .ClkPeriodSys(2ns),
    .ClkPeriodJtag(5ns)
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
  

  initial begin
    spis_sck_i = 0;
    spis_csb_i = 1;
    spis_drive_enable = 0;
    spis_sd_i = 4'h0;
    forever begin
      #(SPITCK/2);
      spis_sck_i = ~spis_sck_i;
    end
  end
  // Assign bidirectional behavior to spis_sd_io
  assign spis_sd_io = spis_drive_enable ? spis_sd_i : 4'bz; 
  `include "lagd_test/spi_test_lib.sv"
  initial begin
    #10ns;
    spi_init();
    #100ns;
    // Switch the clocks on
    spi_write_u32(32'h0000001f, 32'h8000_0000);
    #1us;
    spi_read_u32(32'h8000_0000); 
  end
  // Connect the CHIP SPI signals using the tc io cell
  assign spi_sck_i = spis_sck_i;
  assign spi_csb_i = spis_csb_i;
  // For multi-bit SPI IO
  generate
    if (ChipTest == 0) begin : gen_pad_spis_io
      for ( genvar i = 0; i < 4; i = i + 1) begin: i_pad_spis_io_gen
        tc_digital_io i_pad_spis_io (
          .data_i(spi_sdo_o[i]), // Data from core to pad
          .data_o(spi_sdi_i[i]),
          .io_direction_oe_ni(spi_oen_o[i]),
          .io_driving_strength_i(4'b0),
          .io_pullup_en_i(1'b0),
          .io_pulldown_en_i(1'b0),
          .io(spis_sd_io[i])
        );
      end
    end
  endgenerate  

endmodule : fixture_lagd_chip
