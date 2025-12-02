// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Analog TX module, which transmits spin data from analog macro to digital macro.

`include "../lib/registers.svh"

module analog_tx #(
    parameter integer num_spin = 256,
    parameter integer counter_bitwidth = 8,
    parameter integer synchronizer_pipe_depth = 3
)(
    input logic clk_i,
    input logic rst_ni,
    input logic en_i,
    // config interface
    input  logic tx_configure_enable_i,
    input  logic [$clog2(synchronizer_pipe_depth)-1:0] synchronizer_pipe_num_i, // 0: one-shot; 1: continuous
    input  logic synchronizer_mode_i,
    // spin interface: tx <- analog macro
    input  logic [num_spin-1:0] spin_i,
    // spin interface: rx -> tx
    input  logic analog_macro_cmpt_finish_i,
    // spin interface: tx <-> digital
    output logic spin_valid_o,
    input  logic spin_ready_i,
    output logic [num_spin-1:0] spin_o,
    // status
    output logic analog_tx_idle_o
);
    // Internal signals
    logic [$clog2(synchronizer_pipe_depth)-1:0] synchronizer_pipe_num_reg;
    logic synchronizer_mode_reg;
    logic spin_handshake;
    logic analog_macro_cmpt_finish_nxt, analog_macro_cmpt_finish_pulse;
    logic [synchronizer_pipe_depth:0][num_spin-1:0] spin_shift_reg;
    logic [synchronizer_pipe_depth:0] analog_macro_cmpt_finish_pulse_reg;
    logic synchronizer_counter_overflow;
    genvar i;

    assign analog_tx_idle_o = !spin_valid_o;
    assign spin_handshake = spin_valid_o & spin_ready_i;
    assign analog_macro_cmpt_finish_pulse = analog_macro_cmpt_finish_i & ~analog_macro_cmpt_finish_nxt;
    assign spin_shift_reg[0] = spin_i;
    assign analog_macro_cmpt_finish_pulse_reg[0] = analog_macro_cmpt_finish_pulse;

    always_comb begin
        if (synchronizer_pipe_num_reg < synchronizer_pipe_depth)
            spin_o = spin_shift_reg[synchronizer_pipe_num_reg];
        else
            spin_o = spin_shift_reg[0];
    end

    // Shift register for synchronizing spins from analog macro
    generate
        for (i = 0; i < synchronizer_pipe_depth; i = i + 1) begin : gen_spin_shift_reg
            if (i > 0) begin
                `FFL(analog_macro_cmpt_finish_pulse_reg[i+1], analog_macro_cmpt_finish_pulse_reg[i], en_i & (!synchronizer_mode_reg), '0, clk_i, rst_ni)
                `FFL(spin_shift_reg[i+1], spin_shift_reg[i], en_i & (synchronizer_mode_reg | analog_macro_cmpt_finish_pulse_reg[i]), '0, clk_i, rst_ni)
            end
        end
    endgenerate

    `FFL(synchronizer_pipe_num_reg, synchronizer_pipe_num_i, en_i & tx_configure_enable_i, synchronizer_pipe_depth, clk_i, rst_ni)
    `FFL(synchronizer_mode_reg, synchronizer_mode_i, en_i & tx_configure_enable_i, 1'b0, clk_i, rst_ni)
    `FFLARNC(spin_valid_o, 1'b1, en_i & synchronizer_counter_overflow, !en_i | spin_handshake, 1'b0, clk_i, rst_ni)
    `FFL(analog_macro_cmpt_finish_nxt, analog_macro_cmpt_finish_i, en_i, 1'b0, clk_i, rst_ni)

    step_counter #(
        .COUNTER_BITWIDTH (counter_bitwidth),
        .PARALLELISM (1)
    ) u_step_counter_synchronizer (
        .clk_i (clk_i),
        .rst_ni (rst_ni),
        .en_i (en_i),
        .load_i (tx_configure_enable_i),
        .d_i (synchronizer_pipe_num_i),
        .recount_en_i (en_i & analog_macro_cmpt_finish_pulse),
        .step_en_i (en_i),
        .q_o (),
        .overflow_o (synchronizer_counter_overflow)
    );

endmodule
