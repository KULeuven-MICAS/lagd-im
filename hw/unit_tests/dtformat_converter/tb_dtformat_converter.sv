// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`timescale 1ns / 1ps

`ifndef DBG
`define DBG 0
`endif

module tb_dtformat_converter;

    localparam int N = 256; // number of inputs
    localparam int DATAW = 4; // bit width of each input

    localparam int NUM_TESTS = 2; // number of test cases

    // Testbench signals
    logic [N-1:0][DATAW-1:0] a;
    logic signed [N-1:0][DATAW-1:0] expected_output;
    logic signed [N-1:0][DATAW-1:0] out;

    // Module instantiation
    dtformat_converter #(
        .N(N),
        .DATAW(DATAW)
    ) dut (
        .data_2c_i(a),
        .data_sm_o(out)
    );

    // Testcases
    logic signed [N-1:0][DATAW-1:0] test_a[NUM_TESTS] = '{
        {N{4'b0111}}, // all +7
        {N{4'b1111}} // all -7
        };
    logic signed [N-1:0][DATAW-1:0] expected_outputs[NUM_TESTS] = '{
        {N{4'b0111}}, // all +7
        {N{4'b1001}} // all -7
        };

    // Run tests
    initial begin
        if (`DBG) begin
            $display("Debug mode enabled. Running with detailed output.");
            $dumpfile("tb_dtformat_converter.vcd");
            $dumpvars(0,tb_dtformat_converter);
        end
        $display("Starting dtformat converter testbench. Running %0d tests...", NUM_TESTS);
        for (int i = 0; i < NUM_TESTS; i++) begin
            a = test_a[i];
            expected_output = expected_outputs[i];
            #5;
            assert (out == expected_output)
                else $fatal("Test %0d failed: expected_output=%0h, got %0h",
                            i, expected_outputs[i], out);
            $write( "Test %0d,\t expected_output=%0h,\t\t got %0h\n",
                i, expected_output, out);
        end
        #10;
        $display("All tests (#%0d) completed successfully.", NUM_TESTS);
        $finish;
    end
endmodule
