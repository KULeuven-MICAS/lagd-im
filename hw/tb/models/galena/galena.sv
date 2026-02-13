// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Jiacong Sun <jiacong.sun@kuleuven.be>

// Behavior model for galena

`ifndef STATE_OUT_FILE_1
`define STATE_OUT_FILE_1 "../../unit_tests/digital_macro/data/states_out_1"
`endif

`ifndef STATE_OUT_FILE_2
`define STATE_OUT_FILE_2 "../../unit_tests/digital_macro/data/states_out_2"
`endif

import galena_pkg::*;

module galena #(
) (

    // --- Analog pins ----
    inout j_iref_aio ,  // not used in the behavior model, but included for completeness
    inout j_vup_aio  ,  // not used in the behavior model, but included for completeness
    inout j_vdn_aio  ,  // not used in the behavior model, but included for completeness
    inout h_iref_aio ,  // not used in the behavior model, but included for completeness
    inout h_vup_aio  ,  // not used in the behavior model, but included for completeness
    inout h_vdn_aio  ,  // not used in the behavior model, but included for completeness
    inout vread_aio  ,  // not used in the behavior model, but included for completeness

    // --- Digital pins ---
    input [WBL_WIDTH-1:0] wbl_i,
    input [WBL_WIDTH-1:0] wblb_i, // not used in the behavior model, but included for completeness
    input [WBL_WIDTH-1:0] wbl_floating_i,

    input [WWL_WIDTH-1:0] wwl_i,
    input [WWL_WIDTH-1:0] wwl_vdd_i,
    input [WWL_WIDTH-1:0] wwl_vread_i,

    input [NUM_SPIN-1:0] write_spin_i,
    input [NUM_SPIN-1:0] feedback_i,

    output logic [WBL_WIDTH-1:0] wbl_read_o,
    output logic [WBL_WIDTH-1:0] wblb_read_o,
    output logic [NUM_SPIN-1:0] bct_read_o
);
    timeunit 1ns;
    timeprecision 1ps;

    // Internal signals
    logic [WWL_WIDTH-1:0] [WBL_WIDTH-1:0] data_array;
    logic [NUM_SPIN-1:0] spin_cache;
    logic [SPIN_ICON_DEPTH-1:0] [NUM_SPIN-1:0] state_out;
    logic [$clog2(SPIN_ICON_DEPTH)-1:0] j = 0;
    real spin_delay = 0;

    // ========================================================================
    // BEHAVIOR MODEL
    // ========================================================================
    assign wblb_read_o = ~wbl_read_o;

    generate
        for (genvar i = 0; i < WWL_WIDTH; i++) begin: data_writing
            always_ff @(posedge wwl_i[i]) begin
                data_array[i] <= wbl_i;
            end
        end
    endgenerate

    always_comb begin
        wbl_read_o = {WBL_WIDTH{1'bx}};
        for (int i = 0; i < WWL_WIDTH; i++) begin
            if (wwl_i[i] && wbl_floating_i == {WBL_WIDTH{1'b1}}) begin
                wbl_read_o = data_array[i];
            end
        end
    end

    generate
        if (DATA_FROM_FILE) begin
            initial begin
                state_out = load_state_out_ref(`STATE_OUT_FILE_1, `STATE_OUT_FILE_2);
            end
            always_ff @(posedge write_spin_i[0]) begin // the behavior model assumes write_spin_i is all-one or all-zero
                spin_cache <= state_out[j];
                j <= (j + 1) % SPIN_ICON_DEPTH;
            end
        end else begin
            always_ff @(posedge write_spin_i[0]) begin
                for (int i = 0; i < NUM_SPIN; i++) begin
                    spin_cache[i] <= wbl_i[BIT_DATA*i + SPIN_WBL_OFFSET];
                end
            end
        end
    endgenerate

    generate
        for (genvar i = 0; i < NUM_SPIN; i++) begin: spin_readout
            initial begin
                forever begin
                    @(posedge feedback_i[i]); // Wait for rising edge of feedback_i[i]
                    spin_delay = $urandom_range(SPIN_DELAY_MIN*1000, SPIN_DELAY_MAX*1000) / 1000.0; // random delay
                    #spin_delay;
                    bct_read_o[i] = spin_cache[i];
                    @(negedge feedback_i[i]); // Wait for falling edge of feedback_i[i]
                    bct_read_o[i] = 1'bx;
                end
            end
        end
    endgenerate

    // ========================================================================
    // CHECKS
    // ========================================================================
    // one-hot check on wwl_i
    always_comb begin
        if (!$onehot0(wwl_i)) begin
            $fatal(1, "Error: wwl_i is not one-hot: 'h%h", wwl_i);
        end
    end

    // all-zero/one check on wbl_floating_i, wwl_vdd_i, wwl_vread_i, write_spin_i, feedback_i
    always_comb begin
        if (wbl_floating_i != 0 && wbl_floating_i != {WBL_WIDTH{1'b1}}) begin
            $fatal(1, "Error: wbl_floating_i is not all-zero or all-one: 'h%h", wbl_floating_i);
        end
        if (wwl_vdd_i != 0 && wwl_vdd_i != {WWL_WIDTH{1'b1}}) begin
            $fatal(1, "Error: wwl_vdd_i is not all-zero or all-one: 'h%h", wwl_vdd_i);
        end
        if (wwl_vread_i != 0 && wwl_vread_i != {WWL_WIDTH{1'b1}}) begin
            $fatal(1, "Error: wwl_vread_i is not all-zero or all-one: 'h%h", wwl_vread_i);
        end
        if (write_spin_i != 0 && write_spin_i != {NUM_SPIN{1'b1}}) begin
            $fatal(1, "Error: write_spin_i is not all-zero or all-one: 'h%h", write_spin_i);
        end
        if (feedback_i != 0 && feedback_i != {NUM_SPIN{1'b1}}) begin
            $fatal(1, "Error: feedback_i is not all-zero or all-one: 'h%h", feedback_i);
        end
    end

    // check: wwl_vdd_i and wwl_vread_i cannot be both 1
    always_comb begin
        if ($countones(wwl_vdd_i & wwl_vread_i) > 0) begin
            $fatal(1, "Error: wwl_vdd_i and wwl_vread_i cannot be both 1: 'h%h", wwl_vdd_i & wwl_vread_i);
        end
    end

    // check: wwl_i and write_spin_i cannot be both 1
    always_comb begin
        if ($countones(wwl_i) > 0 && $countones(write_spin_i) > 0) begin
            $fatal(1, "Error: wwl_i and write_spin_i cannot be both 1: wwl_i: 'h%h, write_spin_i: 'h%h", wwl_i, write_spin_i);
        end
    end

endmodule
