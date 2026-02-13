// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Jiacong Sun <jiacong.sun@kuleuven.be>

`timescale 1ns / 1ps

`ifndef DBG
`define DBG 0
`endif

`ifndef VCD_FILE
`define VCD_FILE "tb_analog_model.vcd"
`endif

`ifndef DATA_FROM_FILE
`define DATA_FROM_FILE 0
`endif

import galena_pkg::*;

module tb_analog_model;

    // Parameters
    parameter CLKCYCLE = 2;

    // testbench internal signals
    wire j_iref_aio;
    wire j_vup_aio;
    wire j_vdn_aio;
    wire h_iref_aio;
    wire h_vup_aio;
    wire h_vdn_aio;
    wire vread_aio;
    logic [WBL_WIDTH-1:0] wbl_i;
    logic [WBL_WIDTH-1:0] wblb_i;
    logic [WBL_WIDTH-1:0] wbl_floating_i;
    logic [WWL_WIDTH-1:0] wwl_i;
    logic [WWL_WIDTH-1:0] wwl_vdd_i;
    logic [WWL_WIDTH-1:0] wwl_vread_i;
    logic [NUM_SPIN-1:0] write_spin_i;
    logic [NUM_SPIN-1:0] feedback_i;
    logic [WBL_WIDTH-1:0] wbl_read_o;
    logic [WBL_WIDTH-1:0] wblb_read_o;
    logic [NUM_SPIN-1:0] bct_read_o;
    logic [WBL_WIDTH-1:0] data_array_word_0;

    assign data_array_word_0 = dut.data_array[0];

    // Module instantiation
    galena #(
    ) dut (
        .j_iref_aio     (j_iref_aio     ),
        .j_vup_aio      (j_vup_aio      ),
        .j_vdn_aio      (j_vdn_aio      ),
        .h_iref_aio     (h_iref_aio     ),
        .h_vup_aio      (h_vup_aio      ),
        .h_vdn_aio      (h_vdn_aio      ),
        .vread_aio      (vread_aio      ),
        .wbl_i          (wbl_i          ),
        .wblb_i         (wblb_i         ),
        .wbl_floating_i (wbl_floating_i ),
        .wwl_i          (wwl_i          ),
        .wwl_vdd_i      (wwl_vdd_i      ),
        .wwl_vread_i    (wwl_vread_i    ),
        .write_spin_i   (write_spin_i   ),
        .feedback_i     (feedback_i     ),
        .wbl_read_o     (wbl_read_o     ),
        .wblb_read_o    (wblb_read_o    ),
        .bct_read_o     (bct_read_o     )
    );

    // Run tests
    initial begin
        if (`DBG) begin
            $display("Debug mode enabled. Running with detailed output.");
            $dumpfile(`VCD_FILE);
            $dumpvars(3, tb_analog_model); // Dump all variables in testbench module
            $timeformat(-9, 1, " ns", 9);
            #(1_000 * CLKCYCLE); // To avoid generating huge VCD files
            $display("[Time: %t] testbench timeout reached. Ending simulation.", $time);
            $finish;
        end
        else begin
            $timeformat(-9, 1, " ns", 9);
            #(1_000 * CLKCYCLE);
            $display("[Time: %t] testbench timeout reached. Ending simulation.", $time);
            $finish;
        end
    end

    initial begin
        wbl_i = 'd0;
        wblb_i = 'd0;
        wbl_floating_i = 'd0;
        wwl_i = 'd0;
        wwl_vdd_i = 'd0;
        wwl_vread_i = 'd0;
        write_spin_i = 'd0;
        feedback_i = 'd0;
        #(10 * CLKCYCLE);
        wwl_i[0] = 1'b1; // Write to the first wordline
        wbl_i = {WBL_WIDTH/8{8'h5A}}; // Write data
        wblb_i = ~wbl_i;
        wwl_vdd_i = {WWL_WIDTH{1'b1}};
        #(2 * CLKCYCLE);
        wwl_i[0] = 1'b0; // Deassert the wordline
        #(2 * CLKCYCLE);
        write_spin_i = {NUM_SPIN{1'b1}}; // Trigger the spin update
        #(2 * CLKCYCLE);
        write_spin_i = {NUM_SPIN{1'b0}}; // Deassert the spin update
        feedback_i = {NUM_SPIN{1'b1}};
        #(20 * CLKCYCLE);
        $display("[Time: %t] bct_read_o: 'h%h", $time, bct_read_o);
        feedback_i = {NUM_SPIN{1'b0}};

        #(2 * CLKCYCLE);
        write_spin_i = {NUM_SPIN{1'b1}}; // Trigger the spin update again
        #(2 * CLKCYCLE);
        write_spin_i = {NUM_SPIN{1'b0}}; // Deassert the spin update
        feedback_i = {NUM_SPIN{1'b1}};
        #(20 * CLKCYCLE);
        $display("[Time: %t] bct_read_o: 'h%h", $time, bct_read_o);
        feedback_i = {NUM_SPIN{1'b0}};
        #(2 * CLKCYCLE);
        $finish;
    end

endmodule
