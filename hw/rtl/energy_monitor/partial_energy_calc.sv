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
// - LOCAL_ENERGY_BIT: bit precision of local energy value
// - PIPES: number of pipeline stages at the adder tree interface
//
// Port definitions:
// - clk_i: input clock signal
// - rst_ni: asynchornous reset, active low
// - en_i: enable signal
// - data_valid_i: input data valid signal
// - spin_vector_i: input spin data
// - current_spin_i: current spin value
// - weight_i: input weight data
// - hbias_i: h bias
// - hscaling_i: h scaling factor (must be a power of 2, including 0)
// - energy_o: output energy value

`include "common_cells/registers.svh"

module partial_energy_calc #(
    parameter int BITJ = 4,
    parameter int BITH = 4,
    parameter int DATASPIN = 256,
    parameter int SCALING_BIT = 4,
    parameter int PIPES = 0,
    parameter int MULTBIT = BITH + SCALING_BIT - 1, // bit width of the multiplier output
    parameter int LOCAL_ENERGY_BIT = $clog2(DATASPIN) + MULTBIT,
    parameter int DATAJ = DATASPIN * BITJ
    )(
    input logic clk_i,
    input logic rst_ni,
    input logic en_i,
    input logic data_valid_i,
    input logic [DATASPIN-1:0] spin_vector_i,
    input logic current_spin_i,
    input logic [DATAJ-1:0] weight_i,
    input logic signed [BITH-1:0] hbias_i,
    input logic unsigned [SCALING_BIT-1:0] hscaling_i,
    output logic signed [LOCAL_ENERGY_BIT-1:0] energy_o
);
    // Internal signals
    logic signed [DATASPIN-1:0][MULTBIT-1:0] weight_extended; // sign extended weight
    logic signed [MULTBIT-1:0] hbias_extended; // sign extention of hbias
    logic signed [MULTBIT-1:0] hbias_scaled; // scaled hbias
    logic signed [DATASPIN-1:0][MULTBIT-1:0] mult_out; // multiplier output
    logic signed [LOCAL_ENERGY_BIT-1:0] energy_local_wo_hbias; // local energy value without hbias
    logic signed [LOCAL_ENERGY_BIT-1:0] energy_local; // local energy value
    logic signed [MULTBIT-1:0] hbias_scaled_pipe;
    logic current_spin_pipe;

    // Generate variables
    genvar i;

    // ========================================================================
    // Sign extension of weight
    // ========================================================================
    generate
        for (i = 0; i < DATASPIN; i++) begin : weight_signext
            assign weight_extended[i] = {{(MULTBIT-BITJ){weight_i[(i+1)*BITJ-1]}}, weight_i[(i+1)*BITJ-1 -: BITJ]};
        end
    endgenerate

    // ========================================================================
    // Do multiplication
    // ========================================================================
    // calculate hbias * scaling factor
    assign hbias_extended = {{(MULTBIT-BITH){hbias_i[BITH-1]}}, hbias_i}; // sign extension
    always_comb begin
        case(hscaling_i)
            'd1: hbias_scaled = hbias_extended;
            'd2: hbias_scaled = hbias_extended << 1;
            'd4: hbias_scaled = hbias_extended << 2;
            'd8: hbias_scaled = hbias_extended << 3;
            'd16: hbias_scaled = hbias_extended << 4;
            default: hbias_scaled = hbias_extended;
        endcase
    end

    always_comb begin: weight_mult
        for (int i = 0; i < DATASPIN; i++) begin
            mult_out[i] = spin_vector_i[i] ? weight_extended[i] : -weight_extended[i];
        end
    end

    // ========================================================================
    // Accumulate the multiplication results
    // ========================================================================
    adder_tree #(
        .N(DATASPIN),
        .DATAW(MULTBIT),
        .PIPES(PIPES)
    ) u_adder_tree (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .data_valid_i(data_valid_i),
        .en_i(en_i),
        .data_i(mult_out),
        .sum_o(energy_local_wo_hbias)
    );

    // ========================================================================
    // Generate pipeline for hbias_scaled
    // ========================================================================
    bp_pipe #(
        .DATAW(MULTBIT),
        .PIPES(PIPES)
    ) u_pipe_hbias (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .data_i(hbias_scaled),
        .data_o(hbias_scaled_pipe),
        .valid_i(data_valid_i),
        .valid_o(),
        .ready_i(1'b1),
        .ready_o()
    );

    assign energy_local = energy_local_wo_hbias + hbias_scaled_pipe;

    // ========================================================================
    // Multiply with current spin
    // ========================================================================
    bp_pipe #(
        .DATAW(1),
        .PIPES(PIPES)
    ) u_pipe_current_spin (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .data_i(current_spin_i),
        .data_o(current_spin_pipe),
        .valid_i(data_valid_i),
        .valid_o(),
        .ready_i(1'b1),
        .ready_o()
    );
    assign energy_o = current_spin_pipe ? energy_local : -energy_local;

endmodule