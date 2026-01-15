// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Module description:
//
// energy_fifo_maintainer
// Maintains a small FIFO of energy totals and coordinates with a spin
// value path to decide whether an incoming spin should be forwarded,
// held, or deemed unnecessary ("push none") based on energy comparisons.
//
// Parameters:
// - NUM_SPIN         : bit width of each spin entry
// - SPIN_DEPTH       : number of entries in the (conceptual) spin FIFO / depth used for addr width
// - ENERGY_TOTAL_BIT : bit width of each energy entry
// - ADDR_DEPTH       : width of debug FIFO usage output (derived from SPIN_DEPTH)
//
// Behaviour summary:
// - Accepts energy on (energy_valid_i, energy_ready_o). Accepted values are
//   pushed into an internal energy FIFO (energy_fifo).
// - The combinational head of the FIFO is available as energy_pop.
// - When a new energy value is presented, the module compares it to the FIFO
//   head; if energy_i >= energy_pop the module asserts spin_push_none_o to
//   indicate the energy can satisfy the stored requirement (no spin push needed).
// - Provides a simple spin handshake:
//     * Incoming spins are accepted on (spin_valid_i, spin_ready_o) and
//       captured into an internal spin register when accepted.
//     * spin_o presents the live spin input when the input handshake occurs
//       immediately, otherwise the registered spin is presented.
//     * spin_valid_o indicates a spin available to downstream and is gated by
//       the energy handshake / internal register state.
// - flush_i clears FIFO and related registered state.
// - debug_fifo_usage_o exposes the FIFO usage count from the energy FIFO.
//
// Notes:
// - The energy FIFO used here is lagd_fifo_v3 instantiated as energy_fifo.
// - spin_push_none_o is driven by the comparison (energy_i >= energy_pop)
//   and latched for downstream observation.

`include "common_cells/registers.svh"

module energy_fifo_maintainer #(
    parameter int NUM_SPIN = 256,
    parameter int SPIN_DEPTH = 2,
    parameter int ENERGY_TOTAL_BIT = 32,
    parameter int unsigned ADDR_DEPTH = (SPIN_DEPTH > 1) ? $clog2(SPIN_DEPTH) : 1
)(
    input logic clk_i,
    input logic rst_ni,
    input logic en_i,

    input logic flush_i,
    input logic en_comparison_i,

    output logic spin_valid_o,
    output logic [NUM_SPIN-1:0] spin_o,
    output logic spin_push_none_o,
    input logic spin_ready_i,

    input logic energy_valid_i,
    output logic energy_ready_o,
    input logic [NUM_SPIN-1:0] spin_i,
    input logic signed [ENERGY_TOTAL_BIT-1:0] energy_i,

    output logic [ADDR_DEPTH-1:0] debug_fifo_usage_o,
    output logic signed [SPIN_DEPTH-1:0] [ENERGY_TOTAL_BIT-1:0] energy_fifo_o
);

    // Internal signals
    logic fifo_full;
    logic fifo_empty;
    logic fifo_pop_comb;
    logic fifo_push_comb;
    logic fifo_push_none_comb;
    logic signed [ENERGY_TOTAL_BIT-1:0] energy_pop;
    logic energy_handshake;
    logic spin_handshake_n;
    logic [NUM_SPIN-1:0] spin_reg;
    logic spin_push_none_comb;
    logic spin_push_none_reg;
    logic spin_ready_pipe;

    // FIFO to store the spins
    lagd_fifo_v3 #(
        .FALL_THROUGH(1'b0),
        .DATA_WIDTH(ENERGY_TOTAL_BIT),
        .DEPTH(SPIN_DEPTH),
        .RESET_VALUE(1)
    ) energy_fifo (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .flush_i(flush_i),
        .full_o(fifo_full),
        .empty_o(fifo_empty),
        .usage_o(debug_fifo_usage_o),
        .data_i(energy_i),
        .push_none_i(fifo_push_none_comb),
        .push_i(fifo_push_comb),
        .data_o(energy_pop),
        .pop_i(fifo_pop_comb),
        .mem_o(energy_fifo_o)
    );

    // Control logic
    assign energy_ready_o = ~fifo_full & spin_ready_pipe;
    assign energy_handshake = energy_valid_i & energy_ready_o;
    assign fifo_push_comb = energy_handshake;
    assign fifo_push_none_comb = en_comparison_i & (energy_i >= energy_pop);
    assign fifo_pop_comb = spin_handshake_n;
    assign spin_handshake_n = spin_valid_o & spin_ready_i;

    assign spin_push_none_comb = fifo_push_none_comb;

    // Sequential logic
    `FFLARNC(spin_push_none_o, spin_push_none_comb, energy_handshake, flush_i, 1'b0, clk_i, rst_ni);

    bp_pipe #(
        .DATAW(NUM_SPIN),
        .PIPES(1)
    ) u_pipe_spin (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .data_i(spin_i),
        .data_o(spin_o),
        .valid_i(energy_valid_i),
        .valid_o(spin_valid_o),
        .ready_i(spin_ready_i),
        .ready_o(spin_ready_pipe)
    );

endmodule