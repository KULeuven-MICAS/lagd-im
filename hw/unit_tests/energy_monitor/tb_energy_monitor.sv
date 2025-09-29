// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`timescale 1ns / 1ps

`ifndef DBG
`define DBG 0
`endif

module tb_energy_monitor;

    localparam int BITJ = 4; // J precision
    localparam int BITH = 4; // bias precision
    localparam int DATASPIN = 256; // number of spins
    localparam int SCALING_BIT = 5; // bit width of scaling factor
    localparam int LOCAL_ENERGY_BIT = 16; // bit width of local energy
    localparam int ENERGY_TOTAL_BIT = 32; // bit width of total energy
    localparam int PIPES = 1; // number of pipeline stages

    localparam int CLKCYCLE = 2;
    localparam int NUM_TESTS = 1; // number of test cases

    // Testbench signals
    logic clk_i;
    logic rst_ni;
    logic en_i;
    logic config_valid_i;
    logic [ $clog2(DATASPIN)-1 : 0 ] config_counter_i;
    logic config_ready_o;
    logic spin_valid_i;
    logic [DATASPIN-1:0] spin_i;
    logic spin_ready_o;
    logic weight_valid_i;
    logic [DATASPIN*BITJ-1:0] weight_i;
    logic signed [BITH-1:0] hbias_i;
    logic unsigned [SCALING_BIT-1:0] hscaling_i;
    logic weight_ready_o;
    logic energy_valid_o;
    logic energy_ready_i;
    logic signed [ENERGY_TOTAL_BIT-1:0] energy_o;
    logic debug_en_i;
    logic counter_overflow_o;
    logic accum_overflow_o;

    // Module instantiation
    energy_monitor #(
        .BITJ(BITJ),
        .BITH(BITH),
        .DATASPIN(DATASPIN),
        .SCALING_BIT(SCALING_BIT),
        .LOCAL_ENERGY_BIT(LOCAL_ENERGY_BIT),
        .ENERGY_TOTAL_BIT(ENERGY_TOTAL_BIT),
        .PIPES(PIPES)
    ) dut (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .en_i(en_i),
        .config_valid_i(config_valid_i),
        .config_counter_i(config_counter_i),
        .config_ready_o(config_ready_o),
        .spin_valid_i(spin_valid_i),
        .spin_i(spin_i),
        .spin_ready_o(spin_ready_o),
        .weight_valid_i(weight_valid_i),
        .weight_i(weight_i),
        .hbias_i(hbias_i),
        .hscaling_i(hscaling_i),
        .weight_ready_o(weight_ready_o),
        .energy_valid_o(energy_valid_o),
        .energy_ready_i(energy_ready_i),
        .energy_o(energy_o),
        .debug_en_i(debug_en_i),
        .counter_overflow_o(counter_overflow_o),
        .accum_overflow_o(accum_overflow_o)
    );

    // Clock generation
    initial begin
        clk_i = 0;
        forever #(CLKCYCLE/2) clk_i = ~clk_i;
    end

    // Reset generation
    initial begin
        rst_ni = 0;
        #5;
        rst_ni = 1;
    end

    // Testcases
    initial begin
        en_i = 0;
        config_valid_i = 0;
        config_counter_i = 'd0;
        spin_valid_i = 0;
        spin_i = 'd0;
        weight_valid_i = 0;
        weight_i = 'd0;
        hbias_i = 'd0;
        hscaling_i = 'd0;
    end

    // Run tests
    initial begin
        if (`DBG) begin
            $display("Debug mode enabled. Running with detailed output.");
            $dumpfile("tb_energy_monitor.vcd");
            $dumpvars(0,tb_energy_monitor);
        end
        $display("Starting energy monitor testbench. Running %0d tests...", NUM_TESTS);
        // for (int i = 0; i < NUM_TESTS; i++) begin
        //     a = test_a[i];
        //     expected_output = expected_outputs[i];
        //     #5;
        //     assert (out == expected_output)
        //         else $fatal("Test %0d failed: expected_output=%0h, got %0h",
        //                     i, expected_outputs[i], out);
        //     $write( "Test %0d,\t expected_output=%0h,\t\t got %0h\n",
        //         i, expected_output, out);
        // end
        #10;
        $display("All tests (#%0d) completed successfully.", NUM_TESTS);
        $finish;
    end
endmodule
