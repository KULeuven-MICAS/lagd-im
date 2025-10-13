// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`timescale 1ns / 1ps

`ifndef DBG
`define DBG 0
`endif

module tb_flip_manager;

    // Module parameters
    localparam int DATASPIN = 256; // number of spins
    localparam int ENERGY_TOTAL_BIT = 32; // bit width of total energy
    localparam int SPIN_DEPTH = 2; // depth of spin/energy FIFOs
    localparam int FLIP_ICON_DEPTH = 1024; // number of entries in flip
    localparam int PIPES = 0; // number of pipeline stages

    // Testbench parameters
    localparam int CLKCYCLE = 2;
    localparam int MEM_LATENCY = 0; // latency of memories in cycles
    localparam int SPIN_LATENCY = 10; // latency of spin input in cycles
    localparam bit RANDOM_TEST = 1; // set to 1 for random tests, 0 for fixed tests
    localparam int NUM_TESTS = 1_000_000; // number of test cases

    // Testbench internal signals
    logic clk_i;
    logic rst_ni;
    logic en_i;
    logic flush_i;
    logic cmpt_en_i;
    logic cmpt_stop_i;
    logic spin_pop_valid_o;
    logic [DATASPIN-1:0] spin_pop_o;
    logic spin_pop_ready_i;
    logic spin_valid_i;
    logic [DATASPIN-1:0] spin_i;
    logic spin_ready_o;
    logic energy_valid_i;
    logic energy_ready_o;
    logic signed [ENERGY_TOTAL_BIT-1:0] energy_i;
    logic flip_ren_o;
    logic [$clog2(FLIP_ICON_DEPTH)-1:0] flip_raddr_o;
    logic [DATASPIN-1:0] flip_rdata_i;
    logic debug_flip_disable_i;

    // Module instantiation
    flip_manager #(
        .DATASPIN(DATASPIN),
        .SPIN_DEPTH(SPIN_DEPTH),
        .ENERGY_TOTAL_BIT(ENERGY_TOTAL_BIT),
        .FLIP_ICON_DEPTH(FLIP_ICON_DEPTH),
        .PIPES(PIPES)
    ) dut (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .en_i(en_i),
        .flush_i(flush_i),
        .cmpt_en_i(cmpt_en_i),
        .cmpt_stop_i(cmpt_stop_i),
        .spin_pop_valid_o(spin_pop_valid_o),
        .spin_pop_o(spin_pop_o),
        .spin_pop_ready_i(spin_pop_ready_i),
        .spin_valid_i(spin_valid_i),
        .spin_i(spin_i),
        .spin_ready_o(spin_ready_o),
        .energy_valid_i(energy_valid_i),
        .energy_ready_o(energy_ready_o),
        .energy_i(energy_i),
        .flip_ren_o(flip_ren_o),
        .flip_raddr_o(flip_raddr_o),
        .flip_rdata_i(flip_rdata_i),
        .debug_flip_disable_i(debug_flip_disable_i)
    );

    // Clock generation
    initial begin
        clk_i = 1;
        forever #(CLKCYCLE/2) clk_i = ~clk_i;
    end

    // Reset generation
    initial begin
        rst_ni = 0;
        #(10 * CLKCYCLE);
        rst_ni = 1;
    end

    // Initial values for debug signal and energy ready signal
    initial begin
        debug_flip_disable_i = 0;
    end

    // Run tests
    initial begin
        if (`DBG) begin
            $display("Debug mode enabled. Running with detailed output.");
            $dumpfile("tb_flip_manager.vcd");
            $dumpvars(2, tb_flip_manager);
            #(2000 * CLKCYCLE); // To avoid generating too large VCD files
            $display("Testbench timeout reached. Ending simulation.");
            $finish;
        end
        else begin
            // #(200000 * CLKCYCLE);
            // $display("Testbench timeout reached. Ending simulation.");
            // $finish;
        end
    end

    // ========================================================================
    // Reference behavior model
    // ========================================================================


    // ========================================================================
    // Tasks and functions
    // ========================================================================
    // Task for scoreboard

    // ========================================================================
    // Testbench task and timer setup
    // ========================================================================


endmodule
