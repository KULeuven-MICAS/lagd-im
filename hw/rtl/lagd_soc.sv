// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

// Top-level module for LAGD system-on-chip

`include "lagd_define.svh"
`include "lagd_typedef.svh"


module lagd_soc import lagd_pkg::*; (
    input logic clk_i,
    input logic rtc_i,  // Real Time clock input reference
    input logic rst_ni,
    input logic test_mode_i,
    input logic [1:0] boot_mode_i,
    // JTAG interface
    input logic jtag_tck_i,
    input logic jtag_trst_ni,
    input logic jtag_tms_i,
    input logic jtag_tdi_i,
    output logic jtag_tdo_o,
    output logic jtag_tdo_oe_o,
    // UART interface
    output logic uart_tx_o,
    input  logic uart_rx_i,
    // UART modem flow control
    output logic uart_rts_no,
    output logic uart_dtr_no, // open,
    input logic uart_cts_ni,
    input logic uart_dsr_ni, // =1,
    input logic uart_dcd_ni,  // =1,
    input logic uart_rin_ni,  // =1,
    // SPI slave interface
    input logic spi_sck_i,
    input logic spi_cs_i,
    output logic [3:0] spi_oen_o,
    input logic [3:0] spi_sdi_i,
    output logic [3:0] spi_sdo_o,
    // Serial link interface
    input logic [SlinkNumChan-1:0] slink_rcv_clk_i,
    output logic [SlinkNumChan-1:0] slink_rcv_clk_o,
    input logic [SlinkNumChan-1:0][SlinkNumLanes-1:0] slink_i,
    output logic [SlinkNumChan-1:0][SlinkNumLanes-1:0] slink_o,
    // Galena wires
    inout wire [`NUM_ISING_CORES-1:0] galena_j_iref_i,
    inout wire [`NUM_ISING_CORES-1:0] galena_j_vup_i,
    inout wire [`NUM_ISING_CORES-1:0] galena_j_vdn_i,
    inout wire [`NUM_ISING_CORES-1:0] galena_h_iref_i,
    inout wire [`NUM_ISING_CORES-1:0] galena_h_vup_i,
    inout wire [`NUM_ISING_CORES-1:0] galena_h_vdn_i,
    inout wire [`NUM_ISING_CORES-1:0] galena_vread_i
);

    // defines axi and register interface types
    `LAGD_TYPEDEF_ALL(lagd_, `IC_L1_J_MEM_DATA_WIDTH, `IC_L1_FLIP_MEM_DATA_WIDTH, CheshireCfg)

    //////////////////////////////////////////////////////////
    // Wire declarations /////////////////////////////////////
    //////////////////////////////////////////////////////////
    // External AXI interconnect
    lagd_axi_slv_req_t  [`LAGD_NUM_AXI_SLV-1:0] axi_ext_slv_req;
    lagd_axi_slv_rsp_t  [`LAGD_NUM_AXI_SLV-1:0] axi_ext_slv_rsp;
    lagd_axi_mst_req_t  [`LAGD_NUM_AXI_MST-1:0] axi_ext_mst_req;
    lagd_axi_mst_rsp_t  [`LAGD_NUM_AXI_MST-1:0] axi_ext_mst_rsp;
    // Register interface
    lagd_reg_req_t  [`LAGD_NUM_REG_SLV-1:0] reg_ext_req;
    lagd_reg_rsp_t  [`LAGD_NUM_REG_SLV-1:0] reg_ext_rsp;

    //////////////////////////////////////////////////////////
    // Cheshire instantiation  ///////////////////////////////
    //////////////////////////////////////////////////////////
    cheshire_soc #(
        .Cfg                (CheshireCfg),
        .axi_ext_mst_req_t  (lagd_axi_mst_req_t),
        .axi_ext_mst_rsp_t  (lagd_axi_mst_rsp_t),
        .axi_ext_slv_req_t  (lagd_axi_slv_req_t),
        .axi_ext_slv_rsp_t  (lagd_axi_slv_rsp_t),
        .reg_ext_req_t      (lagd_reg_req_t),
        .reg_ext_rsp_t      (lagd_reg_rsp_t)
    ) i_cheshire_soc (
        .clk_i          (clk_i),
        .rst_ni         (rst_ni),
        .test_mode_i    (test_mode_i),
        .boot_mode_i    (boot_mode_i),
        .rtc_i          (rtc_i),
        // External AXI crosbar ports
        .axi_ext_slv_req_o  (axi_ext_slv_req),
        .axi_ext_slv_rsp_i  (axi_ext_slv_rsp),
        .axi_ext_mst_req_i  (axi_ext_mst_req),
        .axi_ext_mst_rsp_o  (axi_ext_mst_rsp),
        // Register interface
        .reg_ext_slv_req_o  (reg_ext_req),
        .reg_ext_slv_rsp_i  (reg_ext_rsp),
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
        // Serial link interface
        .slink_rcv_clk_i    (slink_rcv_clk_i),
        .slink_rcv_clk_o    (slink_rcv_clk_o),
        .slink_i            (slink_i),
        .slink_o            (slink_o),
        // Unused ports
        .axi_llc_mst_req_o(),
        .axi_llc_mst_rsp_i('0),
        .dbg_active_o(),
        .dbg_ext_req_o(),
        .dbg_ext_unavail_i('0),
        .i2c_sda_o(),
        .i2c_sda_i('0),
        .i2c_sda_en_o(),
        .i2c_scl_o(),
        .i2c_scl_i('0),
        .i2c_scl_en_o(),
        .spih_sck_o(),
        .spih_sck_en_o(),
        .spih_csb_o(),
        .spih_csb_en_o(),
        .spih_sd_o(),
        .spih_sd_en_o(),
        .spih_sd_i('0),
        .gpio_o(),
        .gpio_i('0),
        .gpio_en_o(),
        .usb_clk_i('0),
        .usb_rst_ni('0),
        .usb_dm_i('0),
        .usb_dm_o(),
        .usb_dm_oe_o(),
        .usb_dp_i('0),
        .usb_dp_o(),
        .usb_dp_oe_o()
    );

    //////////////////////////////////////////////////////////
    // Axi SPI Slave /////////////////////////////////////////
    //////////////////////////////////////////////////////////
    lagd_axi_spi_slave #(
        .axi_req_t(lagd_axi_mst_req_t),
        .axi_rsp_t(lagd_axi_mst_rsp_t)
    ) i_axi_spi_slave (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        // AXI slave interface
        .axi_req_o(axi_ext_mst_req[0]),
        .axi_rsp_i(axi_ext_mst_rsp[0]),
        .spi_sclk_i(spi_sck_i),
        .spi_cs_i(spi_cs_i),
        .spi_oen_o(spi_oen_o),
        .spi_sdi_i(spi_sdi_i),
        .spi_sdo_o(spi_sdo_o)
    );

    //////////////////////////////////////////////////////////
    // Stack memory  /////////////////////////////////////////
    //////////////////////////////////////////////////////////
    // Note: only narrow AXI type is valid (no other interfaces used)
    memory_island_wrap #(
        .Cfg(lagd_mem_cfg_pkg::CVA6StackMemCfg),
        .axi_narrow_req_t (lagd_axi_slv_req_t),
        .axi_narrow_rsp_t (lagd_axi_slv_rsp_t),
        .axi_wide_req_t (lagd_axi_wide_slv_req_t),
        .axi_wide_rsp_t (lagd_axi_wide_slv_rsp_t),
        .mem_narrow_req_t (lagd_mem_narr_req_t),
        .mem_narrow_rsp_t (lagd_mem_narr_rsp_t),
        .mem_wide_req_t (lagd_mem_f_req_t),
        .mem_wide_rsp_t (lagd_mem_f_rsp_t)
    ) i_stack_mem (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),
        // AXI slave interface
        .axi_narrow_req_i(axi_ext_slv_req[LagdSlvIdxEnum.STACK_MEM]),
        .axi_narrow_rsp_o(axi_ext_slv_rsp[LagdSlvIdxEnum.STACK_MEM]),
        .axi_wide_req_i('0),
        .axi_wide_rsp_o(),
        .mem_narrow_req_i('0),
        .mem_narrow_rsp_o(),
        .mem_wide_req_i('0),
        .mem_wide_rsp_o()
    );

    //////////////////////////////////////////////////////////
    // L2 SPM  ///////////////////////////////////////////////
    //////////////////////////////////////////////////////////
    memory_island_wrap #(
        .Cfg(lagd_mem_cfg_pkg::L2MemCfg),
        .axi_narrow_req_t(lagd_axi_slv_req_t),
        .axi_narrow_rsp_t(lagd_axi_slv_rsp_t),
        .axi_wide_req_t(lagd_axi_wide_slv_req_t),
        .axi_wide_rsp_t(lagd_axi_wide_slv_rsp_t),
        .mem_narrow_req_t(lagd_mem_narr_req_t),
        .mem_narrow_rsp_t(lagd_mem_narr_rsp_t),
        .mem_wide_req_t(lagd_mem_f_req_t),
        .mem_wide_rsp_t(lagd_mem_f_rsp_t)
    ) i_l2_mem (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),
        // AXI slave interface
        .axi_narrow_req_i(axi_ext_slv_req[LagdSlvIdxEnum.L2_MEM]),
        .axi_narrow_rsp_o(axi_ext_slv_rsp[LagdSlvIdxEnum.L2_MEM]),
        .axi_wide_req_i('0),
        .axi_wide_rsp_o(),
        .mem_narrow_req_i('0),
        .mem_narrow_rsp_o(),
        .mem_wide_req_i('0),
        .mem_wide_rsp_o()
    );

    //////////////////////////////////////////////////////////
    // Ising cores instantiation ////////////////////////////
    //////////////////////////////////////////////////////////
    generate
        for (genvar i = 0; i < `NUM_ISING_CORES; i++) begin : gen_cores
            localparam int unsigned IsingCoreJIdx = LagdSlvIdxEnum.ISING_CORES_BASE + 2*i;
            localparam int unsigned IsingCoreFIdx = LagdSlvIdxEnum.ISING_CORES_BASE + 2*i + 1;
            
            ising_core_wrap #(
                .l1_mem_cfg_j      (lagd_mem_cfg_pkg::IsingCoreL1MemCfgJ    ),
                .l1_mem_cfg_flip   (lagd_mem_cfg_pkg::IsingCoreL1MemCfgFlip ),
                .logic_cfg         (ising_logic_pkg::IsingLogicCfg          ),
                .axi_narrow_req_t  (lagd_axi_slv_req_t                      ),
                .axi_narrow_rsp_t  (lagd_axi_slv_rsp_t                      ),
                .axi_wide_req_t    (lagd_axi_wide_slv_req_t                 ),
                .axi_wide_rsp_t    (lagd_axi_wide_slv_rsp_t                 ),
                .mem_narrow_req_t  (lagd_mem_narr_req_t                     ),
                .mem_narrow_rsp_t  (lagd_mem_narr_rsp_t                     ),
                .mem_j_req_t       (lagd_mem_j_req_t                        ),
                .mem_j_rsp_t       (lagd_mem_j_rsp_t                        ),
                .mem_f_req_t       (lagd_mem_f_req_t                        ),
                .mem_f_rsp_t       (lagd_mem_f_rsp_t                        ),
                .reg_req_t         (lagd_reg_req_t                          ),
                .reg_rsp_t         (lagd_reg_rsp_t                          )
            ) i_core (
                .clk_i             (clk_i                                   ),
                .rst_ni            (rst_ni                                  ),
                // AXI slave interface
                .axi_s_req_j_i       (axi_ext_slv_req[IsingCoreJIdx]),
                .axi_s_rsp_j_o       (axi_ext_slv_rsp[IsingCoreJIdx]),
                .axi_s_req_f_i       (axi_ext_slv_req[IsingCoreFIdx]),
                .axi_s_rsp_f_o       (axi_ext_slv_rsp[IsingCoreFIdx]),
                // Register interface
                .reg_s_req_i       (reg_ext_req[i]                          ),
                .reg_s_rsp_o       (reg_ext_rsp[i]                          ),
                // Galena wires
                .galena_j_iref_i   (galena_j_iref_i[i]                      ),
                .galena_j_vup_i    (galena_j_vup_i[i]                       ),
                .galena_j_vdn_i    (galena_j_vdn_i[i]                       ),
                .galena_h_iref_i   (galena_h_iref_i[i]                      ),
                .galena_h_vup_i    (galena_h_vup_i[i]                       ),
                .galena_h_vdn_i    (galena_h_vdn_i[i]                       ),
                .galena_vread_i    (galena_vread_i[i]                       )
            );
        end
    endgenerate

endmodule