// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`timescale 1ns / 1ps

`ifndef DBG
`define DBG 0
`endif

module tb_partial_energy_calc;

    localparam int BITJ = 4;
    localparam int BITH = 4;
    localparam int DATASPIN = 256;
    localparam int SCALING_BIT = 5;
    localparam int ENERGY_TOTAL_BIT = 16;

    localparam int NUM_TESTS = 3; // number of test cases

    // Testbench signals
    logic signed [DATASPIN-1:0] spin_i;
    logic signed [DATASPIN-1:0] spin_mask_i;
    logic signed [DATASPIN*BITJ-1:0] weight_i;
    logic signed [BITH-1:0] hbias_i;
    logic signed [SCALING_BIT-1:0] hscaling_i;
    logic signed [ENERGY_TOTAL_BIT-1:0] out;
    logic signed [ENERGY_TOTAL_BIT-1:0] expected_output;

    // Module instantiation
    partial_energy_calc #(
        .BITJ(BITJ),
        .BITH(BITH),
        .DATASPIN(DATASPIN),
        .SCALING_BIT(SCALING_BIT),
        .ENERGY_TOTAL_BIT(ENERGY_TOTAL_BIT)
    ) dut (
        .spin_i(spin_i),
        .spin_mask_i(spin_mask_i),
        .weight_i(weight_i),
        .hbias_i(hbias_i),
        .hscaling_i(hscaling_i),
        .energy_o(out)
    );

    // Testcases
    // Test patterns for adder tree
    logic signed [DATASPIN-1:0] test_spin[NUM_TESTS] = '{
        {256{1'd0}}, // All zeros
        {128{1'b0, 1'b1}}, // Alternating 0 and 1
        {256{1'd1}} // All ones
        };
    logic signed [DATASPIN-1:0] test_spin_mask[NUM_TESTS] = '{
        {{1'b1, 255'd0}}, // mask 1st spin
        {{1'b0, 1'b1, 254'b0}},
        {{1'b1, 255'd0}}
        };
    logic signed [DATASPIN*BITJ-1:0] test_weight[NUM_TESTS] = '{
        {256{1'b0}}, // All zeros
        {256{4'b1001}}, // All weights set to -7
        {256{4'b0111}} // All weights set to +7
        };
    logic signed [BITH-1:0] test_hbias[NUM_TESTS] = '{
        'sd0, // Zero bias
        -'sd7,
        'sd0
        };
    logic signed [SCALING_BIT-1:0] test_hscaling[NUM_TESTS] = '{
        'sd1,
        'sd16,
        'sd1
        };
    // Expected outputs for each test pattern
    logic signed [ENERGY_TOTAL_BIT-1:0] expected_outputs[NUM_TESTS] = '{
        'sd0,
        -'sd105,
        'sd1785
        };

    // Run tests
    initial begin
        if (`DBG) begin
            $display("Debug mode enabled. Running with detailed output.");
            $dumpfile("tb_partial_energy_calc.vcd");
            $dumpvars(0,tb_partial_energy_calc);
        end
        $display("Starting testbench. Running %0d tests...", NUM_TESTS);
        for (int i = 0; i < NUM_TESTS; i++) begin
            spin_i = test_spin[i];
            spin_mask_i = test_spin_mask[i];
            weight_i = test_weight[i];
            hbias_i = test_hbias[i];
            hscaling_i = test_hscaling[i];
            expected_output = expected_outputs[i];
            #5;
            assert (out == expected_output)
                else $fatal("Test %0d failed: expected_output='h%0h, got 'h%0h",
                            i, expected_outputs[i], out);
            $write( "Test %0d,\t expected_output='h%0h,\t\t got 'h%0h\n",
                i, expected_output, out);
        end
        #10;
        $display("All tests (#%0d) completed successfully.", NUM_TESTS);
        $finish;
    end
endmodule
