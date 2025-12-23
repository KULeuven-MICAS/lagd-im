// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Analog RX module, which receives spin data from digital macro and sends to analog macro.

`include "common_cells/registers.svh"

module analog_rx #(
    parameter integer NUM_SPIN = 256,
    parameter integer COUNTER_BITWIDTH = 8
)(
    input logic clk_i,
    input logic rst_ni,
    input logic en_i,
    // config interface
    input  logic rx_configure_enable_i,
    input  logic [COUNTER_BITWIDTH-1:0] cycle_per_spin_write_i,
    input  logic [NUM_SPIN-1:0] spin_wwl_strobe_i,
    input  logic [NUM_SPIN-1:0] spin_mode_i,
    input  logic [COUNTER_BITWIDTH-1:0] cycle_per_spin_compute_i,
    // spin interface: rx <-> digital
    input  logic spin_pop_valid_i,
    output logic spin_pop_ready_o,
    input  logic [NUM_SPIN-1:0] spin_pop_i,
    input  logic analog_macro_idle_i,
    // spin interface: tx -> analog macro
    output logic [NUM_SPIN-1:0] spin_wwl_o,
    output logic [NUM_SPIN-1:0] spin_compute_en_o,
    output logic [NUM_SPIN-1:0] wbl_o,
    // status
    output logic analog_rx_idle_o,
    output logic analog_macro_cmpt_finish_o
);
    // Internal signals
    logic spin_pop_handshake;
    logic write_counter_overflow;
    logic compute_counter_overflow;
    logic [NUM_SPIN-1:0] spin_pop_comb;
    logic [NUM_SPIN-1:0] spin_wwl_strobe_reg;
    logic [NUM_SPIN-1:0] spin_mode_reg;
    logic [NUM_SPIN-1:0] spin_wwl_comb;
    logic [NUM_SPIN-1:0] spin_compute_en_comb;
    logic rx_busy;
    logic spin_pop_cond, cmpt_finish_cond;
    logic spin_pop_ready_reset_cond;
    logic spin_wwl_reset_cond, spin_compute_reset_cond;
    logic cmpt_finish_reset_cond;
    logic config_cond;

    assign analog_rx_idle_o = !rx_busy;
    assign spin_pop_handshake = spin_pop_valid_i & spin_pop_ready_o;
    assign spin_pop_comb = spin_pop_handshake ? spin_pop_i : 'd0;
    assign spin_wwl_comb = spin_pop_handshake ? spin_wwl_strobe_reg : 'd0;
    assign spin_compute_en_comb = spin_pop_handshake ? spin_mode_reg : 'd0;

    assign spin_pop_cond = en_i & spin_pop_handshake;
    assign spin_pop_ready_reset_cond = !en_i | analog_macro_idle_i;
    assign spin_wwl_reset_cond = !en_i | write_counter_overflow;
    assign spin_compute_reset_cond = !en_i | compute_counter_overflow;
    assign cmpt_finish_cond = en_i & compute_counter_overflow;
    assign cmpt_finish_reset_cond = !en_i | spin_pop_handshake;
    assign config_cond = en_i & rx_configure_enable_i;

    `FFLARNC(spin_pop_ready_o, 1'b0, spin_pop_cond, spin_pop_ready_reset_cond, 1'b1, clk_i, rst_ni)
    `FFL(wbl_o, spin_pop_comb, spin_pop_cond, 'd0, clk_i, rst_ni)
    `FFLARNC(spin_wwl_o, spin_wwl_comb, spin_pop_cond, spin_wwl_reset_cond, 'd0, clk_i, rst_ni)
    `FFLARNC(spin_compute_en_o, spin_compute_en_comb, spin_pop_cond, spin_compute_reset_cond, 'd0, clk_i, rst_ni)
    `FFLARNC(analog_macro_cmpt_finish_o, 1'b1, cmpt_finish_cond, cmpt_finish_reset_cond, 1'b0, clk_i, rst_ni)

    // configure registers
    `FFLARNC(rx_busy, 1'b1, spin_pop_cond, spin_wwl_reset_cond, 1'b0, clk_i, rst_ni)
    `FFL(spin_wwl_strobe_reg, spin_wwl_strobe_i, config_cond, 'b0, clk_i, rst_ni)
    `FFL(spin_mode_reg, spin_mode_i, config_cond, 'b0, clk_i, rst_ni)

    step_counter #(
        .COUNTER_BITWIDTH (COUNTER_BITWIDTH),
        .PARALLELISM (1)
    ) u_step_counter_spin_write (
        .clk_i (clk_i),
        .rst_ni (rst_ni),
        .en_i (en_i),
        .load_i (rx_configure_enable_i),
        .d_i (cycle_per_spin_write_i),
        .recount_en_i (spin_pop_handshake),
        .step_en_i (en_i),
        .q_o (),
        .overflow_o (write_counter_overflow)
    );

    step_counter #(
        .COUNTER_BITWIDTH (COUNTER_BITWIDTH),
        .PARALLELISM (1)
    ) u_step_counter_spin_compute (
        .clk_i (clk_i),
        .rst_ni (rst_ni),
        .en_i (en_i),
        .load_i (rx_configure_enable_i),
        .d_i (cycle_per_spin_compute_i),
        .recount_en_i (spin_pop_handshake),
        .step_en_i (en_i),
        .q_o (),
        .overflow_o (compute_counter_overflow)
    );

endmodule
