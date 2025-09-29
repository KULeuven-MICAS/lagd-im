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

`include "../../third_parties/cheshire/.bender/git/checkouts/common_cells-7f7ae0f5e6bf7fb5/include/common_cells/registers.svh"

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
    input logic clk_i, // input clock signal
    input logic rst_ni, // asynchornous reset, active low
    input logic en_i, // module enable signal

    input logic config_valid_i, // input config valid signal
    input logic [SPINIDX_BIT-1:0] config_counter_i, // configuration counter
    output logic config_ready_o, // output config ready signal

    input logic spin_valid_i, // input spin valid signal
    input logic [DATASPIN-1:0] spin_i, // input spin data
    output logic spin_ready_o, // output spin ready signal

    input logic weight_valid_i, // input weight valid signal
    input logic [DATAJ-1:0] weight_i, // input weight data
    input logic signed [BITH-1:0] hbias_i, // h bias
    input logic unsigned [SCALING_BIT-1:0] hscaling_i, // h scaling factor
    output logic weight_ready_o, // output weight ready signal

    output logic energy_valid_o, // output energy valid signal
    input logic energy_ready_i, // input energy ready signal
    output logic signed [ENERGY_TOTAL_BIT-1:0] energy_o, // output energy value

    input logic debug_en_i, // debug enable signal
    output logic counter_overflow_o, // counter overflow signal for debug
    output logic accum_overflow_o // accumulator overflow signal for debug
);
    // pipe all input signals
    logic config_valid_pipe;
    logic config_counter_pipe;
    logic config_ready_pipe;

    logic [DATASPIN-1:0] spin_pipe;
    logic spin_valid_pipe;
    logic spin_ready_pipe;

    logic [DATAJ-1:0] weight_pipe;
    logic signed [BITH-1:0] hbias_pipe;
    logic unsigned [SCALING_BIT-1:0] hscaling_pipe;
    logic weight_valid_pipe;
    logic weight_ready_pipe;

    // handshake signals
    logic spin_handshake;
    logic weight_handshake;

    assign spin_handshake = spin_valid_pipe && spin_ready_pipe;
    assign weight_handshake = weight_valid_pipe && weight_ready_pipe;

    // pipeline interfaces
    bp_pipe #(
        .DATAW(COUNTER_BITWIDTH),
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
        .config_ready_o(config_ready_pipe),
        .recount_en_i(spin_ready_pipe && spin_valid_pipe),
        .step_en_i(weight_ready_pipe && weight_valid_pipe),
        .q_o(counter_q),
        .counter_overflow_o(counter_overflow_o), // for debug
        .counter_ready_o(counter_ready)
    );

    // Spin path
    vector_mux #(
        .DATASPIN(DATASPIN)
    ) u_spin_mux (
        .en_i(en_i),
        .idx_i(counter_q),
        .data_i(spin_pipe),
        .data_o(current_spin)
    );

    partial_energy_calc #(
        .BITJ(BITJ),
        .BITH(BITH),
        .DATASPIN(DATASPIN),
        .SCALING_BIT(SCALING_BIT),
        .LOCAL_ENERGY_BIT(LOCAL_ENERGY_BIT)
    ) u_partial_energy_calc (
        .spin_i(spin_pipe),
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
        .clear_i(1'b0), // no clear signal
        .valid_i(weight_handshake),
        .data_i(local_energy),
        .accum_o(energy_o),
        .overflow_o(accum_overflow_o), // for debug
        .valid_o(cmpt_done)
    );

endmodule
