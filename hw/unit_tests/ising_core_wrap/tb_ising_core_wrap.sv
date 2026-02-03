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
    localparam int HSCALING = 5'd4;

    // defines axi and register interface types
    `LAGD_TYPEDEF_ALL(lagd_, `IC_L1_J_MEM_DATA_WIDTH, `IC_L1_FLIP_MEM_DATA_WIDTH, CheshireCfg)

    // Testbench signals
    logic clk_i;
    logic rst_ni;
    logic reg_config_done;
    logic flush_en, en_aw, en_em, en_fm, en_ff, en_ef, en_analog_loop, en_comparison;
    logic cmpt_en, config_valid_aw, config_valid_em, config_valid_fm;
    logic debug_dt_configure_enable, debug_spin_configure_enable, config_spin_initial_skip;
    logic bypass_data_conversion, dt_cfg_enable, host_readout, flip_disable;
    logic enable_flip_detection, debug_j_write_en, debug_j_read_en, debug_spin_write_en, debug_spin_compute_en, debug_spin_read_en;
    logic [$clog2(`NUM_SPIN)-1:0] config_counter;
    logic wwl_vdd_cfg_256, wwl_vread_cfg_256;
    logic [$clog2(`SYNCH_PIPE_DEPTH)-1:0] synchronizer_pipe_num, synchronizer_wbl_pipe_num;
    logic debug_h_wwl;
    logic [`IC_L1_J_MEM_ADDR_WIDTH-1:0] dgt_addr_upper_bound;
    logic ctnus_fifo_read, ctnus_dgt_debug;
    logic [`LAGD_REG_DATA_WIDTH-1:0] global_cfg_reg_1, global_cfg_reg_2;
    logic [(`NUM_SPIN*`BIT_J)-1:0] h_rdata, wbl_floating;

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

    assign global_cfg_reg_1 = {synchronizer_wbl_pipe_num,
                            wwl_vread_cfg_256, wwl_vdd_cfg_256, config_counter,
                            debug_spin_read_en, debug_spin_compute_en, debug_spin_write_en,
                            debug_j_read_en, debug_j_write_en, enable_flip_detection,
                            flip_disable, host_readout, bypass_data_conversion,
                            config_spin_initial_skip, debug_spin_configure_enable,
                            debug_dt_configure_enable, en_comparison, en_analog_loop,
                            en_ef, en_ff, en_fm, en_em, en_aw, flush_en};

    assign global_cfg_reg_2 = {16'd0, ctnus_dgt_debug, ctnus_fifo_read, dgt_addr_upper_bound,
                            debug_h_wwl, synchronizer_pipe_num,
                            dt_cfg_enable, config_valid_fm, config_valid_em,
                            config_valid_aw, cmpt_en};

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

    // Reg configuration process
    initial begin
        reg_config_done = 0;
        reg_ext_req = gen_reg_req('h0, 1'b0, 'd0, 1'b0);
        wait (rst_ni == 1);
        // Initialize reg interfaces
        reg_config();
        reg_config_done = 1;
        #(10 * CLKCYCLE);
        $display("Configuration done. Ending simulation.");
        $finish;
    end

    // Run tests
    initial begin
        if (`DBG) begin
            $display("Debug mode enabled. Running with detailed output.");
            $dumpfile(`VCD_FILE);
            $dumpvars(2, tb_ising_core_wrap); // Dump all variables in testbench module
            $timeformat(-9, 1, " ns", 9);
            #(200 * CLKCYCLE); // To avoid generating huge VCD files
            $display("Testbench timeout reached. Ending simulation.");
            $finish;
        end
        else begin
            $timeformat(-9, 1, " ns", 9);
            #(200 * CLKCYCLE);
            $display("Testbench timeout reached. Ending simulation.");
            $finish;
        end
    end

function automatic lagd_reg_req_t gen_reg_req(
    input logic [`CVA6_ADDR_WIDTH-1:0] addr,
    input logic write,
    input logic [`LAGD_REG_DATA_WIDTH-1:0] wdata,
    input logic valid
);
    lagd_reg_req_t req;
    req.addr  = addr;
    req.write = write;
    req.wdata = wdata;
    req.wstrb = {(`LAGD_REG_DATA_WIDTH/8){1'b1}}; // default all byte lanes enabled
    req.valid = valid;
    return req;
endfunction

task automatic reg_config();
    integer i;
    logic [`LAGD_REG_DATA_WIDTH-1:0] reg_data;

    logic [`NUM_SPIN-1:0] config_spin_initial_0, config_spin_initial_1;
    logic [`COUNTER_BITWIDTH-1:0] cycle_per_spin_write, cycle_per_wwl_low, cycle_per_wwl_high, cfg_trans_num;
    logic [`SCALING_BIT-1:0] dgt_hscaling;
    logic [$clog2(`FLIP_ICON_DEPTH):0] icon_last_raddr_plus_one;
    logic [`COUNTER_BITWIDTH-1:0] debug_spin_read_num, debug_cycle_per_spin_read, cycle_per_spin_compute;
    logic [`NUM_SPIN-1:0] wwl_vdd_cfg, wwl_vread_cfg, spin_wwl_strobe, spin_feedback, debug_j_one_hot_wwl;

    // Prepare configuration values
    flush_en = 1'b0;
    en_aw = 1'b1;
    en_em = 1'b1;
    en_fm = 1'b1;
    en_ff = 1'b1;
    en_ef = 1'b1;
    en_analog_loop = 1'b1;
    en_comparison = 1'b1;
    cmpt_en = 1'b0;
    config_valid_aw = 1'b0;
    config_valid_em = 1'b0;
    config_valid_fm = 1'b0;
    debug_dt_configure_enable = 1'b0;
    debug_spin_configure_enable = 1'b0;
    config_spin_initial_skip = 1'b0;
    bypass_data_conversion = 1'b0;
    dt_cfg_enable = 1'b0;
    host_readout = 1'b0;
    flip_disable = 1'b0;
    enable_flip_detection = 1'b1;
    debug_j_write_en = 1'b0;
    debug_j_read_en = 1'b0;
    debug_spin_write_en = 1'b0;
    debug_spin_compute_en = 1'b0;
    debug_spin_read_en = 1'b0;
    config_counter = `NUM_SPIN-1;
    wwl_vdd_cfg_256 = 1'b1;
    wwl_vread_cfg_256 = 1'b0;
    synchronizer_pipe_num = 'd2;
    synchronizer_wbl_pipe_num = 'd2;
    debug_h_wwl = 1'b0;
    dgt_addr_upper_bound = `NUM_SPIN/`PARALLELISM-1;
    ctnus_fifo_read = 1'b0;
    ctnus_dgt_debug = 1'b0;

    config_spin_initial_0 = {`NUM_SPIN{1'b0}}; // all zeros
    config_spin_initial_1 = {`NUM_SPIN{1'b1}}; // all ones

    cycle_per_spin_write = 'd5;
    cycle_per_wwl_low = 'd5;
    cycle_per_wwl_high = 'd15;
    cfg_trans_num = 'd64;

    dgt_hscaling = HSCALING;
    icon_last_raddr_plus_one = `FLIP_ICON_DEPTH;
    debug_spin_read_num = `FLIP_ICON_DEPTH;
    debug_cycle_per_spin_read = 'd10;
    cycle_per_spin_compute = 'd10;

    wwl_vdd_cfg     = {`NUM_SPIN{1'b1}}; // all high
    wwl_vread_cfg   = {`NUM_SPIN{1'b0}}; // all low
    spin_wwl_strobe = {`NUM_SPIN{1'b1}}; // all high
    spin_feedback   = {`NUM_SPIN{1'b1}}; // all high

    h_rdata = {`NUM_SPIN{4'b1010}}; // alternating 1010
    wbl_floating = {`NUM_SPIN{4'b0000}};
    debug_j_one_hot_wwl = 'd0;

    // Write configuration registers
    // Spin initial configuration, set 0
    for (i = 0; i < `NUM_SPIN/`LAGD_REG_DATA_WIDTH; i = i + 1) begin
        reg_data = config_spin_initial_0[i*`LAGD_REG_DATA_WIDTH +: `LAGD_REG_DATA_WIDTH];
        @ (posedge clk_i);
        reg_ext_req = gen_reg_req(`CVA6_ADDR_WIDTH'h8 + (i * `LAGD_REG_DATA_WIDTH/8), 1'b1, reg_data, 1'b1);
    end
    config_valid_fm = 1'b1;
    @ (posedge clk_i);
    reg_ext_req = gen_reg_req(`CVA6_ADDR_WIDTH'h4, 1'b1, global_cfg_reg_2, 1'b1);
    config_valid_fm = 1'b0;
    @ (posedge clk_i);
    reg_ext_req = gen_reg_req(`CVA6_ADDR_WIDTH'h4, 1'b1, global_cfg_reg_2, 1'b1);
    // Spin initial configuration, set 1
    for (i = 0; i < `NUM_SPIN/`LAGD_REG_DATA_WIDTH; i = i + 1) begin
        reg_data = config_spin_initial_1[i*`LAGD_REG_DATA_WIDTH +: `LAGD_REG_DATA_WIDTH];
        @ (posedge clk_i);
        reg_ext_req = gen_reg_req(`CVA6_ADDR_WIDTH'h8 + (i * `LAGD_REG_DATA_WIDTH/8), 1'b1, reg_data, 1'b1);
    end
    config_valid_fm = 1'b1;
    @ (posedge clk_i);
    reg_ext_req = gen_reg_req(`CVA6_ADDR_WIDTH'h4, 1'b1, global_cfg_reg_2, 1'b1);
    config_valid_fm = 1'b0;
    @ (posedge clk_i);
    reg_ext_req = gen_reg_req(`CVA6_ADDR_WIDTH'h4, 1'b1, global_cfg_reg_2, 1'b1);

    // Counters, set 1
    reg_data = {cycle_per_wwl_high, cfg_trans_num};
    @ (posedge clk_i);
    reg_ext_req = gen_reg_req(`CVA6_ADDR_WIDTH'h28, 1'b1, reg_data, 1'b1);
    // Counters, set 2
    reg_data = {cycle_per_spin_write, cycle_per_wwl_low};
    @ (posedge clk_i);
    reg_ext_req = gen_reg_req(`CVA6_ADDR_WIDTH'h2c, 1'b1, reg_data, 1'b1);
    // Counters, set 3
    reg_data = {debug_cycle_per_spin_read, cycle_per_spin_compute};
    @ (posedge clk_i);
    reg_ext_req = gen_reg_req(`CVA6_ADDR_WIDTH'h30, 1'b1, reg_data, 1'b1);
    // Counters, set 4
    reg_data = {dgt_hscaling, icon_last_raddr_plus_one, debug_spin_read_num};
    @ (posedge clk_i);
    reg_ext_req = gen_reg_req(`CVA6_ADDR_WIDTH'h34, 1'b1, reg_data, 1'b1);
    // WWL VDD
    for (i = 0; i < `NUM_SPIN/`LAGD_REG_DATA_WIDTH; i = i + 1) begin
        reg_data = wwl_vdd_cfg[i*`LAGD_REG_DATA_WIDTH +: `LAGD_REG_DATA_WIDTH];
        @ (posedge clk_i);
        reg_ext_req = gen_reg_req(`CVA6_ADDR_WIDTH'h38 + (i * `LAGD_REG_DATA_WIDTH/8), 1'b1, reg_data, 1'b1);
    end
    // WWL VREAD
    for (i = 0; i < `NUM_SPIN/`LAGD_REG_DATA_WIDTH; i = i + 1) begin
        reg_data = wwl_vread_cfg[i*`LAGD_REG_DATA_WIDTH +: `LAGD_REG_DATA_WIDTH];
        @ (posedge clk_i);
        reg_ext_req = gen_reg_req(`CVA6_ADDR_WIDTH'h58 + (i * `LAGD_REG_DATA_WIDTH/8), 1'b1, reg_data, 1'b1);
    end
    // Spin WWL strobe
    for (i = 0; i < `NUM_SPIN/`LAGD_REG_DATA_WIDTH; i = i + 1) begin
        reg_data = spin_wwl_strobe[i*`LAGD_REG_DATA_WIDTH +: `LAGD_REG_DATA_WIDTH];
        @ (posedge clk_i);
        reg_ext_req = gen_reg_req(`CVA6_ADDR_WIDTH'h78 + (i * `LAGD_REG_DATA_WIDTH/8), 1'b1, reg_data, 1'b1);
    end
    // Spin feedback
    for (i = 0; i < `NUM_SPIN/`LAGD_REG_DATA_WIDTH; i = i + 1) begin
        reg_data = spin_feedback[i*`LAGD_REG_DATA_WIDTH +: `LAGD_REG_DATA_WIDTH];
        @ (posedge clk_i);
        reg_ext_req = gen_reg_req(`CVA6_ADDR_WIDTH'h98 + (i * `LAGD_REG_DATA_WIDTH/8), 1'b1, reg_data, 1'b1);
    end
    // h_rdata
    for (i = 0; i < `NUM_SPIN*`BIT_J/`LAGD_REG_DATA_WIDTH; i = i + 1) begin
        reg_data = h_rdata[i*`LAGD_REG_DATA_WIDTH +: `LAGD_REG_DATA_WIDTH];
        @ (posedge clk_i);
        reg_ext_req = gen_reg_req(`CVA6_ADDR_WIDTH'hb8 + (i * `LAGD_REG_DATA_WIDTH/8), 1'b1, reg_data, 1'b1);
    end
    // wbl_floating
    for (i = 0; i < `NUM_SPIN*`BIT_J/`LAGD_REG_DATA_WIDTH; i = i + 1) begin
        reg_data = wbl_floating[i*`LAGD_REG_DATA_WIDTH +: `LAGD_REG_DATA_WIDTH];
        @ (posedge clk_i);
        reg_ext_req = gen_reg_req(`CVA6_ADDR_WIDTH'h138 + (i * `LAGD_REG_DATA_WIDTH/8), 1'b1, reg_data, 1'b1);
    end
    // debug_j_one_hot_wwl
    for (i = 0; i < `NUM_SPIN/`LAGD_REG_DATA_WIDTH; i = i + 1) begin
        reg_data = debug_j_one_hot_wwl[i*`LAGD_REG_DATA_WIDTH +: `LAGD_REG_DATA_WIDTH];
        @ (posedge clk_i);
        reg_ext_req = gen_reg_req(`CVA6_ADDR_WIDTH'h1b8 + (i * `LAGD_REG_DATA_WIDTH/8), 1'b1, reg_data, 1'b1);
    end
    // load all configurations into the core
    config_valid_aw = 1'b1;
    config_valid_em = 1'b1;
    debug_dt_configure_enable = 1'b1;
    debug_spin_configure_enable = 1'b1;
    @ (posedge clk_i);
    reg_ext_req = gen_reg_req(`CVA6_ADDR_WIDTH'h0, 1'b1, global_cfg_reg_1, 1'b1);
    @ (posedge clk_i);
    reg_ext_req = gen_reg_req(`CVA6_ADDR_WIDTH'h4, 1'b1, global_cfg_reg_2, 1'b1);
    config_valid_aw = 1'b0;
    config_valid_em = 1'b0;
    debug_dt_configure_enable = 1'b0;
    debug_spin_configure_enable = 1'b0;
    @ (posedge clk_i);
    reg_ext_req = gen_reg_req(`CVA6_ADDR_WIDTH'h0, 1'b1, global_cfg_reg_1, 1'b1);
    @ (posedge clk_i);
    reg_ext_req = gen_reg_req(`CVA6_ADDR_WIDTH'h4, 1'b1, global_cfg_reg_2, 1'b1);
    @ (posedge clk_i);
    // Deassert valid signals
    reg_ext_req = gen_reg_req(`CVA6_ADDR_WIDTH'h4, 1'b1, global_cfg_reg_2, 1'b0);
    @ (posedge clk_i);
endtask

endmodule
