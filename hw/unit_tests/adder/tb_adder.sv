// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`timescale 1ns / 1ps

`ifndef DBG
`define DBG 0
`endif

module tb_adder;

    // Testbench signals
    logic signed [7:0] a;
    logic signed [7:0] b;
    logic signed [7:0] expected_output;
    logic signed [7:0] out;

    // Module instantiation
    adder #(
        .DATAW(8)
    ) adder1 (
        .a(a),
        .b(b),
        .sum(out)
    );

    // Testcases - just as an example
    parameter int NUM_TESTS = 7;
    logic signed [7:0] test_a[NUM_TESTS] = '{0, 1, 8, 124, 124, -127, -127};
    logic signed [7:0] test_b[NUM_TESTS] = '{0, 2, -8, 3, 4, -1, -2};
    logic signed [7:0] expected_outputs[NUM_TESTS] = '{0, 3, 0, 127, 127, -128, -128};

    // Run tests
    initial begin
        if (`DBG) begin
            $display("Debug mode enabled. Running with detailed output.");
            $dumpfile("tb_adder.vcd");
            $dumpvars(0,tb_adder);
        end
        $display("Starting adder testbench. Running %0d tests...", NUM_TESTS);
        for (int i = 0; i < NUM_TESTS; i++) begin
            a = test_a[i];
            b = test_b[i];
            expected_output = expected_outputs[i];
            #5;
            assert (out == expected_output)
                else $fatal("Test %0d failed: a=%0d, b=%0d, expected_output=%0d, got %0d",
                            i, test_a[i], test_b[i], expected_outputs[i], out);
            $write( "Test %0d passed: a=%0d,\t b=%0d,\t expected_output=%0d,\t got %0d\n",
                i, a, b, expected_output, out);
        end
        #10;
        $display("All tests completed successfully.");
        $finish;
    end
endmodule
