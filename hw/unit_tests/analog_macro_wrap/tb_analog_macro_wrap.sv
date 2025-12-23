// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Jiacong Sun <jiacong.sun@kuleuven.be>

`timescale 1ns / 1ps

`ifndef DBG
`define DBG 0
`endif

`ifndef VCD_FILE
`define VCD_FILE "tb_analog_macro_wrap.vcd"
`endif

module tb_analog_macro_wrap;

    // Module parameters
    localparam int NUM_SPIN = 256; // number of spins
    localparam int BITDATA = 4; // bit width of J and h, sfc
    localparam int COUNTER_BITWIDTH = 16;
    localparam int SYNCHRONIZER_PIPE_DEPTH = 3;
    localparam int PARALLELISM = 4; // number of parallel data in J memory
    localparam int J_ADDRESS_WIDTH = $clog2(NUM_SPIN / PARALLELISM);

    // Testbench parameters
    localparam int CLKCYCLE = 2;

    // Testbench internal signals
    logic clk_i;
    logic rst_ni;
    logic en_i;
    logic analog_wrap_configure_enable_i;
    logic [COUNTER_BITWIDTH-1:0] cfg_trans_num_i;
    logic [COUNTER_BITWIDTH-1:0] cycle_per_dt_write_i;
    logic [COUNTER_BITWIDTH-1:0] cycle_per_spin_write_i;
    logic [COUNTER_BITWIDTH-1:0] cycle_per_spin_compute_i;
    logic [NUM_SPIN-1:0] spin_wwl_strobe_i;
    logic [NUM_SPIN-1:0] spin_mode_i;
    logic [$clog2(SYNCHRONIZER_PIPE_DEPTH)-1:0] synchronizer_pipe_num_i;
    logic synchronizer_mode_i;
    logic dt_cfg_enable_i;
    logic j_mem_ren_o;
    logic [J_ADDRESS_WIDTH-1:0] j_raddr_o;
    logic [NUM_SPIN*BITDATA*PARALLELISM-1:0] j_rdata_i;
    logic h_ren_o;
    logic [NUM_SPIN*BITDATA-1:0] h_rdata_i;
    logic [NUM_SPIN-1:0] j_one_hot_wwl_o;
    logic h_wwl_o;
    logic [NUM_SPIN*BITDATA-1:0] wbl_o;
    logic spin_pop_valid_i;
    logic spin_pop_ready_o;
    logic [NUM_SPIN-1:0] spin_pop_i;
    logic [NUM_SPIN-1:0] spin_wwl_o;
    logic [NUM_SPIN-1:0] spin_compute_en_o;
    logic [NUM_SPIN-1:0] spin_i;
    logic spin_valid_o;
    logic spin_ready_i;
    logic [NUM_SPIN-1:0] spin_o;
    logic dt_cfg_idle_o;
    logic analog_rx_idle_o;
    logic analog_tx_idle_o;

    initial begin
        en_i = 1;
    end

    // Module instantiation
    analog_macro_wrap #(
        .NUM_SPIN(NUM_SPIN),
        .BITDATA(BITDATA),
        .PARALLELISM(PARALLELISM),
        .COUNTER_BITWIDTH(COUNTER_BITWIDTH),
        .SYNCHRONIZER_PIPEDEPTH(SYNCHRONIZER_PIPE_DEPTH)
    ) dut (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .en_i(en_i),
        .analog_wrap_configure_enable_i(analog_wrap_configure_enable_i),
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
        .j_one_hot_wwl_o(j_one_hot_wwl_o),
        .h_wwl_o(h_wwl_o),
        .wbl_o(wbl_o),
        .spin_pop_valid_i(spin_pop_valid_i),
        .spin_pop_ready_o(spin_pop_ready_o),
        .spin_pop_i(spin_pop_i),
        .spin_wwl_o(spin_wwl_o),
        .spin_compute_en_o(spin_compute_en_o),
        .spin_i(spin_i),
        .spin_valid_o(spin_valid_o),
        .spin_ready_i(spin_ready_i),
        .spin_o(spin_o),
        .dt_cfg_idle_o(dt_cfg_idle_o),
        .analog_rx_idle_o(analog_rx_idle_o),
        .analog_tx_idle_o(analog_tx_idle_o)
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
            $dumpvars(4, tb_analog_macro_wrap); // Dump all variables in testbench module
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
