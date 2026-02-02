// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Jiacong Sun <jiacong.sun@kuleuven.be>

`timescale 1ns / 1ps

`ifndef DBG
`define DBG 0
`endif

`ifndef VCD_FILE
`define VCD_FILE "tb_ising_core_wrap.vcd"
`endif

`include "../../rtl/include/lagd_config.svh"
`include "../../rtl/include/lagd_define.svh"
`include "../../rtl/include/lagd_platform.svh"
`include "../../rtl/include/lagd_typedef.svh"

module tb_ising_core_wrap;
    import lagd_mem_cfg_pkg::*;
    import ising_logic_pkg::*;
    import lagd_pkg::*;

    localparam int CLKCYCLE = 2;

    // defines axi and register interface types
    `LAGD_TYPEDEF_ALL(lagd_, `IC_L1_J_MEM_DATA_WIDTH, `IC_L1_FLIP_MEM_DATA_WIDTH, CheshireCfg)

    // Clock and reset
    logic clk_i;
    logic rst_ni;

    // External AXI interconnect
    lagd_axi_slv_req_t axi_ext_slv_req_0;
    lagd_axi_slv_rsp_t axi_ext_slv_rsp_0;
    lagd_axi_slv_req_t axi_ext_slv_req_1;
    lagd_axi_slv_rsp_t axi_ext_slv_rsp_1;
    // Register interface
    lagd_reg_req_t reg_ext_req;
    lagd_reg_rsp_t reg_ext_rsp;

    // Galena wires
    wire galena_j_iref_i;
    wire galena_j_vup_i;
    wire galena_j_vdn_i;
    wire galena_h_iref_i;
    wire galena_h_vdn_i;
    wire galena_h_vup_i;
    wire galena_vread_i;

    // Module instantiation
    ising_core_wrap #(
        .l1_mem_cfg_j      (lagd_mem_cfg_pkg::IsingCoreL1MemCfgJ    ),
        .l1_mem_cfg_flip   (lagd_mem_cfg_pkg::IsingCoreL1MemCfgFlip ),
        .logic_cfg         (ising_logic_pkg::IsingLogicCfg          ),
        .axi_slv_req_t     (lagd_axi_slv_req_t                      ),
        .axi_slv_rsp_t     (lagd_axi_slv_rsp_t                      ),
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
        .axi_slv_aw_chan_t (lagd_axi_slv_aw_chan_t                  ),
        .axi_slv_w_chan_t  (lagd_axi_slv_w_chan_t                   ),
        .axi_slv_b_chan_t  (lagd_axi_slv_b_chan_t                   ),
        .axi_slv_ar_chan_t (lagd_axi_slv_ar_chan_t                  ),
        .axi_slv_r_chan_t  (lagd_axi_slv_r_chan_t                   ),
        .reg_req_t         (lagd_reg_req_t                          ),
        .reg_rsp_t         (lagd_reg_rsp_t                          )
    ) i_core (
        .clk_i             (clk_i                                   ),
        .rst_ni            (rst_ni                                  ),
        // AXI slave interface
        .axi_s_req_0_i       (axi_ext_slv_req_0                     ),
        .axi_s_rsp_0_o       (axi_ext_slv_rsp_0                     ),
        .axi_s_req_1_i       (axi_ext_slv_req_1                     ),
        .axi_s_rsp_1_o       (axi_ext_slv_rsp_1                     ),
        // Register interface
        .reg_s_req_i       (reg_ext_req                             ),
        .reg_s_rsp_o       (reg_ext_rsp                             ),
        // Galena wires
        .galena_j_iref_i   (galena_j_iref_i                         ),
        .galena_j_vup_i    (galena_j_vup_i                          ),
        .galena_j_vdn_i    (galena_j_vdn_i                          ),
        .galena_h_iref_i   (galena_h_iref_i                         ),
        .galena_h_vup_i    (galena_h_vup_i                          ),
        .galena_h_vdn_i    (galena_h_vdn_i                          ),
        .galena_vread_i    (galena_vread_i                          )
    );

    // Clock generation
    initial begin
        clk_i = 0;
        forever #(CLKCYCLE/2) clk_i = ~clk_i;
    end

    // Reset generation
    initial begin
        rst_ni = 0;
        #(5 * CLKCYCLE);
        rst_ni = 1;
        #(5 * CLKCYCLE);
    end

    // Run tests
    initial begin
        if (`DBG) begin
            $display("Debug mode enabled. Running with detailed output.");
            $dumpfile(`VCD_FILE);
            $dumpvars(4, tb_ising_core_wrap); // Dump all variables in testbench module
            $timeformat(-9, 1, " ns", 9);
            #(200 * CLKCYCLE); // To avoid generating huge VCD files
            $display("Testbench timeout reached. Ending simulation.");
            $finish;
        end
        else begin
            $timeformat(-9, 1, " ns", 9);
            #(10 * CLKCYCLE);
            $display("Testbench timeout reached. Ending simulation.");
            $finish;
        end
    end

endmodule
