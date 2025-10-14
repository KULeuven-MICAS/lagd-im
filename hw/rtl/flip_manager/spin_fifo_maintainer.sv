// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Module description:
//
// spin_maintainer
// Maintains a small FIFO of "spin" bit-vectors and exposes push/pop handshakes
// together with a simple completion status register used to gate pops.
// 
// Parameters:
// - SPIN_DEPTH   : number of entries in the spin FIFO
// - DATASPIN     : bit width of each spin entry
// - ADDR_DEPTH   : width of usage / address output (derived from SPIN_DEPTH)
//
// Behaviour summary:
// - Accepts spins on (spin_push_valid_i, spin_push_i) when spin_push_ready_o is high.
// - Provides spins on (spin_pop_valid_o, spin_pop_o) when downstream asserts spin_pop_ready_i.
// - spin_pop_valid_o is asserted only when:
//     * module enable (en_i) is high,
//     * FIFO is not empty,
//     * completion is enabled (cmpt_en_i) or completion status latched,
//     * and cmpt_stop_i is low.
// - A completion status register (cmpt_busy_o) is set when cmpt_en_i && en_i,
//   and cleared by cmpt_stop_i or flush_i.
// - flush_i is forwarded to the FIFO to clear its contents.
// 
// Ports:
// - clk_i, rst_ni : clock and asynchronous active-low reset
// - en_i          : module enable
// - flush_i       : flush FIFO and related state
// - cmpt_en_i     : arm/set completion status when asserted with en_i
// - cmpt_stop_i   : clear completion status and inhibit pops
// - host_readout_i: allow pops regardless of completion status (for host readout)
// - spin_push_valid_i, spin_push_i : input push handshake and data
// - spin_push_ready_o               : push-ready from FIFO
// - spin_pop_valid_o, spin_pop_o    : output pop handshake and data
// - spin_pop_ready_i                : downstream ready for pop
// - cmpt_busy_o                   : latched completion status
// - debug_fifo_usage_o              : FIFO usage count (debug)
//
// Case tested:
// - None

`include "../lib/registers.svh"
`include "../lib/fifo_v3.sv"

module spin_fifo_maintainer #(
    parameter int SPIN_DEPTH = 2,
    parameter int DATASPIN = 256,
    parameter int unsigned ADDR_DEPTH = (SPIN_DEPTH > 1) ? $clog2(SPIN_DEPTH) : 1
)(
    input logic clk_i,
    input logic rst_ni,
    input logic en_i,

    input logic flush_i,

    input logic cmpt_en_i,
    input logic cmpt_stop_i,
    input logic host_readout_i,

    input logic spin_push_valid_i,
    input logic [DATASPIN-1:0] spin_push_i,
    input logic spin_push_none_i,
    output logic spin_push_ready_o,

    output logic spin_pop_valid_o,
    output logic [DATASPIN-1:0] spin_pop_o,
    input logic spin_pop_ready_i,
    output logic cmpt_busy_o,
    output logic [ADDR_DEPTH-1:0] debug_fifo_usage_o
);

    // Internal signals
    logic fifo_full;
    logic fifo_empty;
    logic cmpt_busy_reg;
    logic fifo_pop_comb;
    logic fifo_push_comb;
    logic within_cmpt;

    // FIFO to store the spins
    fifo_v3 #(
        .FALL_THROUGH(1'b0),
        .DATA_WIDTH(DATASPIN),
        .DEPTH(SPIN_DEPTH),
        .RESET_VALUE(0)
    ) spin_fifo (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .flush_i(flush_i),
        .full_o(fifo_full),
        .empty_o(fifo_empty),
        .usage_o(debug_fifo_usage_o),
        .data_i(spin_push_i),
        .push_none_i(spin_push_none_i),
        .push_i(fifo_push_comb),
        .data_o(spin_pop_o),
        .pop_i(fifo_pop_comb)
    );

    // Control logic
    // assign within_cmpt = (cmpt_en_i | cmpt_busy_reg) & ~cmpt_stop_i;
    assign within_cmpt = cmpt_busy_reg & ~cmpt_stop_i;
    assign spin_pop_valid_o = en_i & ~fifo_empty & (within_cmpt | host_readout_i);
    assign fifo_pop_comb = spin_pop_valid_o & spin_pop_ready_i;
    assign spin_push_ready_o = ~fifo_full & en_i;
    assign fifo_push_comb = spin_push_valid_i & spin_push_ready_o;

    assign cmpt_busy_o = cmpt_busy_reg;

    // Sequential logic
    `FFLARNC(cmpt_busy_reg, 1'b1, cmpt_en_i & en_i, cmpt_stop_i | flush_i, 1'b0, clk_i, rst_ni);

endmodule