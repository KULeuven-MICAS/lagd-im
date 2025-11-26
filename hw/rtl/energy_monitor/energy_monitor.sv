// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Module description:
// Energy monitor module.
//
// Parameters:
// - BITJ: bit precision of J
// - BITH: bit precision of h
// - DATASPIN: number of spins
// - SCALING_BIT: number of bits of scaling factor for h
// - LOCAL_ENERGY_BIT: bit precision of partial energy value
// - ENERGY_TOTAL_BIT: bit precision of total energy value
// - PIPES: number of pipeline stages for each input path
//
// Port definitions:
// - clk_i: input clock signal
// - rst_ni: asynchornous reset, active low
// - en_i: module enable signal
// - config_valid_i: input config valid signal
// - config_counter_i: configuration counter
// - config_ready_o: output config ready signal
// - spin_valid_i: input spin valid signal
// - spin_i: input spin data
// - spin_ready_o: output spin ready signal
// - weight_valid_i: input weight valid signal
// - weight_i: input weight data
// - hbias_i: h bias
// - hscaling_i: h scaling factor
// - weight_ready_o: output weight ready signal
// - energy_valid_o: output energy valid signal
// - energy_ready_i: input energy ready signal
// - energy_o: output energy value
// - debug_en_i: debug enable signal
// - accum_overflow_o: accumulator overflow signal for debug
//
// Case tested:
// - BITJ=4, BITH=4, DATASPIN=256, SCALING_BIT=5, LOCAL_ENERGY_BIT=16, ENERGY_TOTAL_BIT=32, PIPES=0/1/2
// -- All spins are 1, all weights are +1, hbias=+1, hscaling=1, 20 same cases
// -- All spins are 0, all weights are +1, hbias=+1, hscaling=1, 20 same cases
// -- All spins are 0, all weights are -1, hbias=-1, hscaling=1, 20 same cases
// -- All spins are 1, all weights are -1, hbias=-1, hscaling=1, 20 same cases
// -- All spins are 1, all weights are +7, hbias=+7, hscaling=16, 20 same cases
// -- All spins are 0, all weights are -7, hbias=-7, hscaling=16, 20 same cases
// -- All spins and weights are random, hbias and hscaling are random, 1,000,000 different cases

`include "../lib/registers.svh"

module energy_monitor #(
    parameter int BITJ = 4,
    parameter int BITH = 4,
    parameter int DATASPIN = 256,
    parameter int SCALING_BIT = 5,
    parameter int LOCAL_ENERGY_BIT = 16,
    parameter int ENERGY_TOTAL_BIT = 32,
    parameter int PIPES = 1,
    parameter int DATAJ = DATASPIN * BITJ,
    parameter int SPINIDX_BIT = $clog2(DATASPIN)
)(
    input logic clk_i,
    input logic rst_ni,
    input logic en_i,

    input logic config_valid_i,
    input logic [SPINIDX_BIT-1:0] config_counter_i,
    output logic config_ready_o,

    input logic spin_valid_i,
    input logic [DATASPIN-1:0] spin_i,
    output logic spin_ready_o,

    input logic weight_valid_i,
    input logic [DATAJ-1:0] weight_i,
    input logic signed [BITH-1:0] hbias_i,
    input logic unsigned [SCALING_BIT-1:0] hscaling_i,
    output logic weight_ready_o,

    output logic energy_valid_o,
    input logic energy_ready_i,
    output logic signed [ENERGY_TOTAL_BIT-1:0] energy_o,

    input logic debug_en_i,
    output logic accum_overflow_o
);
    // pipe all input signals
    logic config_valid_pipe;
    logic [SPINIDX_BIT-1:0] config_counter_pipe;
    logic config_ready_pipe;

    logic [DATASPIN-1:0] spin_pipe;
    logic spin_valid_pipe;
    logic spin_ready_pipe;

    logic [DATAJ-1:0] weight_pipe;
    logic signed [BITH-1:0] hbias_pipe;
    logic unsigned [SCALING_BIT-1:0] hscaling_pipe;
    logic weight_valid_pipe;
    logic weight_ready_pipe;

    // internal signals
    logic [DATASPIN-1:0] spin_cached;
    logic [SPINIDX_BIT-1:0] counter_q;
    logic counter_ready;
    logic cmpt_done;
    logic current_spin;
    logic signed [LOCAL_ENERGY_BIT-1:0] local_energy;

    // handshake signals
    logic spin_handshake;
    logic weight_handshake;

    assign spin_handshake = spin_valid_pipe && spin_ready_pipe;
    assign weight_handshake = weight_valid_pipe && weight_ready_pipe;
    assign energy_handshake = energy_valid_o && energy_ready_i;

    // pipeline interfaces
    bp_pipe #(
        .DATAW(SPINIDX_BIT),
        .PIPES(PIPES)
    ) u_pipe_config (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .data_i(config_counter_i),
        .data_o(config_counter_pipe),
        .valid_i(config_valid_i),
        .valid_o(config_valid_pipe),
        .ready_i(config_ready_pipe),
        .ready_o(config_ready_o)
    );
    bp_pipe #(
        .DATAW(DATASPIN),
        .PIPES(PIPES)
    ) u_pipe_spin (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .data_i(spin_i),
        .data_o(spin_pipe),
        .valid_i(spin_valid_i),
        .valid_o(spin_valid_pipe),
        .ready_i(spin_ready_pipe),
        .ready_o(spin_ready_o)
    );
    bp_pipe #(
        .DATAW(DATAJ + BITH + SCALING_BIT),
        .PIPES(PIPES)
    ) u_pipe_weight (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .data_i({weight_i, hbias_i, hscaling_i}),
        .data_o({weight_pipe, hbias_pipe, hscaling_pipe}),
        .valid_i(weight_valid_i),
        .valid_o(weight_valid_pipe),
        .ready_i(weight_ready_pipe),
        .ready_o(weight_ready_o)
    );

    // Logic FSM
    logic_ctrl u_logic_ctrl (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .en_i(en_i),
        .config_valid_i(config_valid_pipe),
        .config_ready_o(config_ready_pipe),
        .spin_valid_i(spin_valid_pipe),
        .spin_ready_o(spin_ready_pipe),
        .weight_valid_i(weight_valid_pipe),
        .weight_ready_o(weight_ready_pipe),
        .counter_ready_i(counter_ready),
        .cmpt_done_i(cmpt_done),
        .energy_valid_o(energy_valid_o),
        .energy_ready_i(energy_ready_i),
        .debug_en_i(debug_en_i)
    );

    // Counter path
    counter_ctrl #(
        .COUNTER_BITWIDTH(SPINIDX_BIT),
        .PIPES(PIPES)
    ) u_counter_ctrl (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .en_i(en_i),
        .config_valid_i(config_valid_pipe),
        .config_counter_i(config_counter_pipe),
        .config_ready_i(config_ready_pipe),
        .recount_en_i(spin_handshake),
        .step_en_i(weight_handshake),
        .q_o(counter_q),
        .counter_ready_o(counter_ready)
    );

    // Spin path
    vector_caching #(
        .DATAWIDTH(DATASPIN)
    ) u_spin_cache (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .en_i(en_i),
        .data_valid_i(spin_handshake),
        .data_i(spin_pipe),
        .data_o(spin_cached)
    );

    // N-to-1 mux for a vector
    assign current_spin = en_i ? spin_cached[counter_q] : 1'b0;

    partial_energy_calc #(
        .BITJ(BITJ),
        .BITH(BITH),
        .DATASPIN(DATASPIN),
        .SCALING_BIT(SCALING_BIT),
        .LOCAL_ENERGY_BIT(LOCAL_ENERGY_BIT)
    ) u_partial_energy_calc (
        .spin_vector_i(spin_cached),
        .current_spin_i(current_spin),
        .weight_i(weight_pipe),
        .hbias_i(hbias_pipe),
        .hscaling_i(hscaling_pipe),
        .energy_o(local_energy)
        );

    accumulator #(
        .IN_WIDTH(LOCAL_ENERGY_BIT),
        .ACCUM_WIDTH(ENERGY_TOTAL_BIT)
    ) u_accumulator (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .en_i(en_i),
        .clear_i(energy_handshake), // clear when the output energy is accepted
        .valid_i(weight_handshake),
        .data_i(local_energy),
        .accum_o(energy_o),
        .overflow_o(accum_overflow_o), // for debug
        .valid_o(cmpt_done)
    );

endmodule
