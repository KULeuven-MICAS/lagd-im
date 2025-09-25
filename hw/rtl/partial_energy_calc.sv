// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Module description:
// Energy calculator for a single spin (pure combinational, no clk/enable signal).
//
// Parameters:
// - BITJ: bit precision of J
// - BITH: bit precision of h
// - DATASPIN: number of spins
// - SCALING_BIT: number of bits of scaling factor for h
// - ENERGY_TOTAL_BIT: bit precision of total energy value

// `include "third_parties/cheshire/.bender/git/checkouts/common_cells-7f7ae0f5e6bf7fb5/include/common_cells/registers.svh"

module partial_energy_calc #(
    parameter int BITJ = 4,
    parameter int BITH = 4,
    parameter int DATASPIN = 256,
    parameter int SCALING_BIT = 4,
    parameter int ENERGY_TOTAL_BIT = 16,
    parameter int DATAJ = DATASPIN * BITJ,
    parameter int SPINIDX_BIT = $clog2(DATASPIN)
)(
    // input logic clk_i, // input clock signal
    // input logic rst_ni, // asynchornous reset, active low
    input logic [DATASPIN-1:0] spin_i, // input spin data
    input logic [DATASPIN-1:0] spin_mask_i, // spin mask
    input logic [DATAJ-1:0] weight_i, // input weight data
    input logic [BITH-1:0] hbias_i, // h bias
    input logic [SCALING_BIT-1:0] hscaling_i, // h scaling factor
    output logic signed [ENERGY_TOTAL_BIT-1:0] energy_o // output energy value
);
    // Parameters
    localparam int MULTBIT = BITH + SCALING_BIT; // bit width of the multiplier output

    // Internal signals
    logic [DATASPIN-1:0][BITJ-1:0] weight_sm; // weight in signed magnitude format
    logic signed [DATASPIN-1:0][BITJ-1:0] weight_2c; // weight in 2's complement format
    logic masked_bit; // masked bit
    logic signed [DATASPIN-1:0][MULTBIT-1:0] mult_out; // multiplier output
    logic signed [ENERGY_TOTAL_BIT-1:0] energy_local; // local energy value

    // Generate variables
    genvar i;

    // ========================================================================
    // Convert weight digits from sign-magnitude to 2's complement
    // ========================================================================
    generate
        for (i = 0; i < DATASPIN; i++) begin : weight_unpack
            assign weight_sm[i] = weight_i[i*BITJ + (BITJ-1) : i*BITJ]; // extract each weight
        end
    endgenerate

    always_comb begin
        for (int i = 0; i < DATASPIN; i++) begin
            if (weight_sm[i][BITJ-1] == 1'b0) begin
                weight_2c[i] = $signed(weight_sm[i]);
            end else begin
                weight_2c[i] = $signed({1'b1, (~weight_sm[i][BITJ-2:0]) + 1'b1});
            end
        end
    end

    // ========================================================================
    // Extract masked bit
    // ========================================================================
    always_comb begin
        masked_bit = 1'b0;
        for (int i = 0; i < DATASPIN; i++) begin
            if (spin_mask_i[i]) begin
                masked_bit = spin_i[i];
            end
        end
    end

    // ========================================================================
    // Do multiplication
    // ========================================================================
    always_comb begin
        for (int i = 0; i < DATASPIN; i++) begin
            if (spin_mask_i[i]) begin: bias_mult
            mult_out[i] = $signed(hbias_i) * $signed({1'b0, hscaling_i});
            end
            else begin: weight_mult
            mult_out[i] = spin_i[i] ? weight_2c[i] : -weight_2c[i];
            end
        end
    end

    // ========================================================================
    // Accumulate the multiplication results
    // ========================================================================
    adder_tree #(
        .N(DATASPIN),
        .DATAW(MULTBIT)
    ) u_adder_tree (
        .data_i(mult_out),
        .sum_o(energy_local)
    );

    // ========================================================================
    // Multiply with masked bit
    // ========================================================================
    assign energy_o = masked_bit ? energy_local : -energy_local;

endmodule