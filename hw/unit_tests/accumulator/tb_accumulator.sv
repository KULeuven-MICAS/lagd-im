// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`timescale 1ns / 1ps

`ifndef DBG
`define DBG 0
`endif

module tb_accumulator;

    localparam int IN_WIDTH = 16;
    localparam int ACCUM_WIDTH = 32;
    localparam int CLKCYCLE = 2;

    localparam int NUM_TESTS = 3; // number of test cases

    // Testbench signals
    logic signed [IN_WIDTH-1:0] data_i;
    logic clk_i;
    logic rst_ni;
    logic en_i;
    logic clear_i;
    logic valid_i;
    logic signed [ACCUM_WIDTH-1:0] accum_o;
    logic overflow_o;
    logic valid_o;
    logic signed [ACCUM_WIDTH-1:0] expected_output;

    logic clear_test_done;

    // Module instantiation
    accumulator #(
        .IN_WIDTH(IN_WIDTH),
        .ACCUM_WIDTH(ACCUM_WIDTH)
    ) dut (
        .data_i(data_i),
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .en_i(en_i),
        .clear_i(clear_i),
        .valid_i(valid_i),
        .accum_o(accum_o),
        .overflow_o(overflow_o),
        .valid_o(valid_o)
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

    // Flag signal
    initial begin
        clear_test_done = 0;
    end

    // Clear signal test
    initial begin
        en_i = 0;
        clear_i = 0;
        valid_i = 0;
        data_i = 'd8;
        wait (rst_ni == 1);
        @(posedge clk_i);
        en_i = 1;
        clear_i = 0;
        valid_i = 1;
        repeat (20) begin
            @(posedge clk_i);
            clear_i = ($urandom_range(0, 9) > 5); // ~50% chance to clear
            #CLKCYCLE;
        end
        clear_i = 1;
        #CLKCYCLE;
        clear_i = 0;
        clear_test_done = 1;
    end

    // Accumulation test
    // use random data, random valid signal and random enable signal
    initial begin
        wait (clear_test_done == 1);
        @(posedge clk_i);
        en_i = 1;
        clear_i = 0;
        valid_i = 0;
        repeat (100) begin
            @(posedge clk_i);
            data_i = $urandom_range(-32768, 32767); // random signed 16-bit number
            valid_i = ($urandom_range(0, 9) > 5); // ~50% chance to be valid
            #CLKCYCLE;
        end
        valid_i = 0;
        en_i = 0;
    end
    // Calculate expected output
    always @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            expected_output <= 0;
        end else if (clear_i) begin
            expected_output <= 0;
        end else if (en_i & valid_i) begin
            expected_output <= expected_output + data_i;
        end else begin
            expected_output <= expected_output;
        end
    end

    // Run tests
    initial begin
        if (`DBG) begin
            $display("Debug mode enabled. Running with detailed output.");
            $dumpfile("tb_accumulator.vcd");
            $dumpvars(0,tb_accumulator);
        end
        #100;
        $finish;
    end
endmodule
