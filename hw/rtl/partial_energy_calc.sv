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
    parameter int SCALING_BIT = 5,
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
    localparam int MULTBIT = BITH + SCALING_BIT - 1; // bit width of the multiplier output

    // Internal signals
    logic signed [DATASPIN-1:0][BITJ-1:0] weight_2c; // weight in 2's complement format
    logic masked_bit; // masked bit
    logic signed [MULTBIT-1:0] hbias_scaled; // scaled hbias
    logic signed [DATASPIN-1:0][MULTBIT-1:0] mult_out; // multiplier output
    logic signed [ENERGY_TOTAL_BIT-1:0] energy_local; // local energy value

    // Generate variables
    genvar i;

    // ========================================================================
    // Convert weight digits from sign-magnitude to 2's complement
    // ========================================================================
    generate
        for (i = 0; i < DATASPIN; i++) begin : weight_unpack
            assign weight_2c[i] = weight_i[i*BITJ + (BITJ-1) : i*BITJ]; // extract each weight
        end
    endgenerate

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
    // calculate hbias * scaling factor
    always_comb begin
        case(hscaling_i)
            'd1: hbias_scaled = $signed(hbias_i);
            'd2: hbias_scaled = $signed(hbias_i) << 1;
            'd4: hbias_scaled = $signed(hbias_i) << 2;
            'd8: hbias_scaled = $signed(hbias_i) << 3;
            'd16: hbias_scaled = $signed(hbias_i) << 4;
            default: hbias_scaled = $signed(hbias_i);
    end

    always_comb begin
        for (int i = 0; i < DATASPIN; i++) begin
            if (spin_mask_i[i]) begin: bias_mult
            mult_out[i] = hbias_scaled;
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