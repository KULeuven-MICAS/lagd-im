// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Jiacong Sun <jiacong.sun@kuleuven.be>

`timescale 1ns / 1ps

`ifndef DBG
`define DBG 0
`endif

`ifndef VCD_FILE
`define VCD_FILE "tb_digital_macro.vcd"
`endif

`define True 1'b1
`define False 1'b0

module tb_digital_macro;

    // Module parameters
    localparam int bit_j = 4;
    localparam int bit_h = 4;
    localparam int num_spin = 256;
    localparam int scaling_bit = 4; // limited by analog wbl which is reused by sfc, h and j
    localparam int parallelism = 4;
    localparam int local_energy_bit = 16;
    localparam int energy_total_bit = 32;
    localparam int little_endian = `False;
    localparam int pipesintf = 1;
    localparam int pipesmid = 1;
    localparam int spin_depth = 2;
    localparam int flip_icon_depth = 1024;
    localparam int counter_bitwidth = 16;
    localparam int synchronizer_pipe_depth = 3;

    // Testbench parameters
    localparam int CLKCYCLE = 2;

    // Testbench internal signals
    logic clk_i;
    logic rst_ni;
    logic en_i;
    logic config_valid_em_i;
    logic config_valid_fm_i;
    logic config_valid_aw_i;
    logic [ $clog2(num_spin)-1 : 0 ] config_counter_i;
    logic [ num_spin-1 : 0 ] config_spin_initial_i;
    logic config_spin_initial_skip_i;
    logic [ counter_bitwidth-1 : 0] cfg_trans_num_i;
    logic [ counter_bitwidth-1 : 0] cycle_per_dt_write_i;
    logic [ counter_bitwidth-1 : 0] cycle_per_spin_write_i;
    logic [ counter_bitwidth-1 : 0] cycle_per_spin_compute_i;
    logic [ num_spin-1 : 0 ] spin_wwl_strobe_i;
    logic [ num_spin-1 : 0 ] spin_mode_i;
    logic [ $clog2(synchronizer_pipe_depth)-1 : 0 ] synchronizer_pipe_num_i;
    logic synchronizer_mode_i;
    logic dt_cfg_enable_i;
    logic j_mem_ren_o;
    logic [ $clog2(num_spin / parallelism)-1 : 0 ] j_raddr_o;
    logic [ num_spin*bit_j*parallelism-1 : 0 ] j_rdata_i;
    logic h_ren_o;
    logic [ bit_h*num_spin-1 : 0 ] h_rdata_i;
    logic sfc_ren_o;
    logic [ scaling_bit-1 : 0 ] sfc_rdata_i;
    logic flush_i;
    logic en_comparison_i;
    logic cmpt_en_i;
    logic cmpt_idle_o;
    logic host_readout_i;
    logic flip_ren_o;
    logic [ $clog2(flip_icon_depth)+1-1 : 0 ] flip_raddr_o;
    logic [ $clog2(flip_icon_depth)+1-1 : 0 ] icon_last_raddr_plus_one_i;
    logic [ num_spin-1 : 0 ] flip_rdata_i;
    logic flip_disable_i;
    logic weight_ren_o;
    logic [ $clog2(num_spin / parallelism)-1 : 0 ] weight_raddr_o;
    logic [ num_spin*bit_j*parallelism-1 : 0 ] weight_i;
    logic [ bit_h*parallelism-1 : 0 ] hbias_i;
    logic [ scaling_bit-1 : 0 ] hscaling_i;
    logic [ num_spin-1 : 0 ] j_one_hot_wwl_o;
    logic h_wwl_o;
    logic sfc_wwl_o;
    logic [num_spin*bit_j-1 : 0 ] wbl_o;
    logic [ num_spin-1 : 0 ] spin_wwl_o;
    logic [num_spin-1 : 0 ] spin_compute_en_o;
    logic [ num_spin-1 : 0 ] analog_spin_i;


    initial begin
        en_i = 1;
    end

    // Module instantiation
    digital_macro #(
        .bit_j(bit_j),
        .bit_h(bit_h),
        .num_spin(num_spin),
        .scaling_bit(scaling_bit),
        .parallelism(parallelism),
        .energy_total_bit(energy_total_bit),
        .little_endian(little_endian),
        .pipesintf(pipesintf),
        .pipesmid(pipesmid),
        .spin_depth(spin_depth),
        .flip_icon_depth(flip_icon_depth),
        .counter_bitwidth(counter_bitwidth),
        .synchronizer_pipe_depth(synchronizer_pipe_depth)
    ) dut (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .en_i(en_i),
        .config_valid_em_i(config_valid_em_i),
        .config_valid_fm_i(config_valid_fm_i),
        .config_valid_aw_i(config_valid_aw_i),
        .config_counter_i(config_counter_i),
        .config_spin_initial_i(config_spin_initial_i),
        .config_spin_initial_skip_i(config_spin_initial_skip_i),
        .cfg_trans_num_i(cfg_trans_num_i),
        .cycle_per_dt_write_i(cycle_per_dt_write_i),
        .cycle_per_spin_write_i(cycle_per_spin_write_i),
        .cycle_per_spin_compute_i(cycle_per_spin_compute_i),
        .spin_wwl_strobe_i(spin_wwl_strobe_i),
        .spin_mode_i(spin_mode_i),
        .synchronizer_pipe_num_i(synchronizer_pipe_num_i),
        .synchronizer_mode_i(synchronizer_mode_i),
        .dt_cfg_enable_i(dt_cfg_enable_i),
        .j_mem_ren_o(j_mem_ren_o),
        .j_raddr_o(j_raddr_o),
        .j_rdata_i(j_rdata_i),
        .h_ren_o(h_ren_o),
        .h_rdata_i(h_rdata_i),
        .sfc_ren_o(sfc_ren_o),
        .sfc_rdata_i(sfc_rdata_i),
        .flush_i(flush_i),
        .en_comparison_i(en_comparison_i),
        .cmpt_en_i(cmpt_en_i),
        .cmpt_idle_o(cmpt_idle_o),
        .host_readout_i(host_readout_i),
        .flip_ren_o(flip_ren_o),
        .flip_raddr_o(flip_raddr_o),
        .icon_last_raddr_plus_one_i(icon_last_raddr_plus_one_i),
        .flip_rdata_i(flip_rdata_i),
        .flip_disable_i(flip_disable_i),
        .weight_ren_o(weight_ren_o),
        .weight_raddr_o(weight_raddr_o),
        .weight_i(weight_i),
        .hbias_i(hbias_i),
        .hscaling_i(hscaling_i),
        .j_one_hot_wwl_o(j_one_hot_wwl_o),
        .h_wwl_o(h_wwl_o),
        .sfc_wwl_o(sfc_wwl_o),
        .wbl_o(wbl_o),
        .spin_wwl_o(spin_wwl_o),
        .spin_compute_en_o(spin_compute_en_o),
        .analog_spin_i(analog_spin_i)
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
        en_i = 1;
    end

    // Run tests
    initial begin
        if (`DBG) begin
            $display("Debug mode enabled. Running with detailed output.");
            $dumpfile(`VCD_FILE);
            $dumpvars(4, tb_digital_macro); // Dump all variables in testbench module
            $timeformat(-9, 1, " ns", 9);
            #(600 * CLKCYCLE); // To avoid generating huge VCD files
            $display("Testbench timeout reached. Ending simulation.");
            $finish;
        end
        else begin
            $timeformat(-9, 1, " ns", 9);
            #(2_000_000 * CLKCYCLE);
            $display("Testbench timeout reached. Ending simulation.");
            $finish;
        end
    end

endmodule
