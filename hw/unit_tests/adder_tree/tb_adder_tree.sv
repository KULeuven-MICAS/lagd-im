// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`timescale 1ns / 1ps

`ifndef DBG
`define DBG 0
`endif

module tb_adder_tree;

    localparam int N = 256; // number of inputs
    localparam int DATAW = 8; // bit width of each input
    localparam int OUT_WIDTH = $clog2(N) + DATAW; // bit width of the output

    localparam int NUM_TESTS = 4; // number of test cases

    // Testbench signals
    logic signed [N*DATAW-1:0] a;
    logic signed [OUT_WIDTH-1:0] expected_output;
    logic signed [OUT_WIDTH-1:0] out;

    // Module instantiation
    adder_tree #(
        .N(N),
        .DATAW(DATAW)
    ) adder_tree1 (
        .data_i(a),
        .sum_o(out)
    );

    // Testcases
    // Test patterns for adder tree
    logic signed [N*DATAW-1:0] test_a[NUM_TESTS] = '{
        {N{8'sd0}}, // All zeros
        {N{8'sd127}}, // All max positive
        {N{-8'sd128}},  // All max negative
        {N{8'sd64}}
        };
    logic signed [OUT_WIDTH-1:0] expected_outputs[NUM_TESTS] = '{
        'sd0,
        'sd32512,
        -'sd32768,
        'sd16384
        };

    // Run tests
    initial begin
        if (`DBG) begin
            $display("Debug mode enabled. Running with detailed output.");
            $dumpfile("tb_adder_tree.vcd");
            $dumpvars(0,tb_adder_tree);
        end
        $display("Starting adder tree testbench. Running %0d tests...", NUM_TESTS);
        for (int i = 0; i < NUM_TESTS; i++) begin
            a = test_a[i];
            expected_output = expected_outputs[i];
            #5;
            assert (out == expected_output)
                else $fatal("Test %0d failed: a=%0d, expected_output=%0d, got %0d",
                            i, test_a[i], expected_outputs[i], out);
            $write( "Test %0d,\t expected_output=%0d,\t\t got %0d\n",
                i, expected_output, out);
        end
        #10;
        $display("All tests (#%0d) completed successfully.", NUM_TESTS);
        $finish;
    end
endmodule
