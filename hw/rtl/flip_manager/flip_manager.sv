// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Flip manager
// Manages spin configuration, buffering, energy-maintenance and flip engine interface.
// Coordinates three sub-modules: energy_fifo_maintainer, spin_fifo_maintainer and flip_engine.
//
// Parameters:
// - DATASPIN: width of a spin vector (number of spins per word)
// - SPIN_DEPTH: depth (entries) of internal spin FIFOs
// - ENERGY_TOTAL_BIT: bit-width of the total energy value
// - FLIP_ICON_DEPTH: depth of flip icon memory
// - FLIP_ICON_ADDR_DEPTH: address width for flip icon memory (usually $clog2(FLIP_ICON_DEPTH))
//
// Ports:
// - clk_i, rst_ni: clock and active-low async reset
// - en_i: module enable
// - flush_i: synchronous flush/clear
//
// Completion/control interface:
// - cmpt_en_i: completion mode enable
// - cmpt_idle_o: completion finished indicator
//
// Spin configuration input (configuration or energy-maintainer driven):
// - spin_configure_valid_i: config push valid
// - spin_configure_i: config spin vector (DATASPIN bits)
// - spin_configure_push_none_i: config push-none indicator
// - spin_configure_ready_o: config ready
//
// Spin output (flipped spins from flip_engine):
// - spin_pop_valid_o: popped/flipped spin valid
// - spin_pop_o: popped/flipped spin vector (DATASPIN bits)
// - spin_pop_ready_i: consumer ready for popped spin
//
// Spin input (direct spin stream for energy maintainer):
// - spin_valid_i: incoming spin valid
// - spin_i: incoming spin vector
// - spin_ready_o: source ready
//
// Energy input (for energy FIFO maintainer):
// - energy_valid_i: energy input valid
// - energy_ready_o: energy input ready
// - energy_i: signed total energy value (ENERGY_TOTAL_BIT bits)
//
// Flip memory interface:
// - flip_ren_o: read enable to flip icon memory
// - flip_raddr_o: read address to flip icon memory (FLIP_ICON_ADDR_DEPTH bits)
// - flip_rdata_i: read data from flip icon memory (DATASPIN bits)
//
// Debug:
// - flip_disable_i: disable flipping
//
// Notes:
// - This module arbitrates between configuration-driven pushes and energy-driven pushes into the spin FIFO.
// - It exposes FIFO usage debug signals from submodules (debug_*_fifo_usage).

`include "../lib/registers.svh"

module flip_manager #(
    parameter int DATASPIN = 256,
    parameter int SPIN_DEPTH = 2,
    parameter int ENERGY_TOTAL_BIT = 32,
    parameter int FLIP_ICON_DEPTH = 1024,
    parameter int FLIP_ICON_ADDR_DEPTH = $clog2(FLIP_ICON_DEPTH)
)(
    input logic clk_i,
    input logic rst_ni,
    input logic en_i,
    input logic flush_i,
    input logic en_comparison_i,

    input logic cmpt_en_i,
    output logic cmpt_idle_o,
    input logic host_readout_i,

    input logic spin_configure_valid_i,
    input logic [DATASPIN-1:0] spin_configure_i,
    input logic spin_configure_push_none_i,
    output logic spin_configure_ready_o,

    output logic spin_pop_valid_o,
    output logic [DATASPIN-1:0] spin_pop_o,
    input logic spin_pop_ready_i,

    input logic spin_valid_i,
    input logic [DATASPIN-1:0] spin_i,
    output logic spin_ready_o,

    input logic energy_valid_i,
    output logic energy_ready_o,
    input logic signed [ENERGY_TOTAL_BIT-1:0] energy_i,

    output logic flip_ren_o,
    output logic [FLIP_ICON_ADDR_DEPTH+1-1:0] flip_raddr_o,
    input logic [FLIP_ICON_ADDR_DEPTH+1-1:0] icon_last_raddr_plus_one_i,
    input logic [DATASPIN-1:0] flip_rdata_i,

    input logic flip_disable_i
);
    // Internal signals
    logic cmpt_busy;
    logic spin_pop_valid_p;
    logic [DATASPIN-1:0] spin_pop_p;
    logic spin_pop_ready_p;
    logic spin_maintainer_push;
    logic [DATASPIN-1:0] spin_maintainer_income;
    logic spin_maintainer_push_from_en;
    logic [DATASPIN-1:0] spin_maintainer_income_from_en;
    logic spin_maintainer_push_none_from_en;
    logic spin_maintainer_push_ready;
    logic spin_maintainer_push_none;
    logic cmpt_stop_reg;
    logic icon_finish;
    logic fifo_full_and_idle_comb;
    logic fifo_full_and_idle_reg;

    logic spin_pop_handshake;
    logic energy_handshake;

    assign spin_configure_ready_o = spin_maintainer_push_ready & cmpt_idle_o;
    assign spin_maintainer_push = cmpt_busy ? spin_maintainer_push_from_en : spin_configure_valid_i;
    assign spin_maintainer_income = cmpt_busy ? spin_maintainer_income_from_en : spin_configure_i;
    assign spin_maintainer_push_none = cmpt_busy ? spin_maintainer_push_none_from_en : spin_configure_push_none_i;

    assign spin_pop_handshake = spin_pop_valid_o & spin_pop_ready_i;
    assign energy_handshake = energy_valid_i & energy_ready_o & (~cmpt_idle_o);

    assign cmpt_idle_o = ~cmpt_busy;
    // assign fifo_full_and_idle_comb = ~(cmpt_busy | spin_maintainer_push_ready);
    // assign cmpt_idle_o = fifo_full_and_idle_comb ? fifo_full_and_idle_comb : fifo_full_and_idle_reg;

    // `FFLARNC(fifo_full_and_idle_reg, 1'b1, fifo_full_and_idle_comb & en_i, cmpt_en_i | flush_i, 1'b0, clk_i, rst_ni);

    // Instantiate energy maintainer
    energy_fifo_maintainer #(
        .DATASPIN(DATASPIN),
        .SPIN_DEPTH(SPIN_DEPTH),
        .ENERGY_TOTAL_BIT(ENERGY_TOTAL_BIT)
    ) u_energy_fifo_maintainer (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .en_i(en_i),
        .flush_i(flush_i),
        .en_comparison_i(en_comparison_i),
        .spin_valid_o(spin_maintainer_push_from_en),
        .spin_o(spin_maintainer_income_from_en),
        .spin_push_none_o(spin_maintainer_push_none_from_en),
        .spin_ready_i(spin_maintainer_push_ready),
        .spin_valid_i(spin_valid_i),
        .spin_i(spin_i),
        .spin_ready_o(spin_ready_o),
        .energy_valid_i(energy_valid_i),
        .energy_ready_o(energy_ready_o),
        .energy_i(energy_i),
        .debug_fifo_usage_o()
    );

    // Instantiate spin FIFO maintainer
    spin_fifo_maintainer #(
        .SPIN_DEPTH(SPIN_DEPTH),
        .DATASPIN(DATASPIN)
    ) u_spin_fifo_maintainer (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .en_i(en_i),
        .flush_i(flush_i),
        .cmpt_en_i(cmpt_en_i),
        .icon_finish_i(icon_finish),
        .host_readout_i(host_readout_i),
        .spin_push_valid_i(spin_maintainer_push),
        .spin_push_i(spin_maintainer_income),
        .spin_push_none_i(spin_maintainer_push_none),
        .spin_push_ready_o(spin_maintainer_push_ready),
        .spin_pop_valid_o(spin_pop_valid_p),
        .spin_pop_o(spin_pop_p),
        .spin_pop_ready_i(spin_pop_ready_p),
        .cmpt_busy_o(cmpt_busy),
        .debug_fifo_usage_o()
    );

    // Instantiate flip engine
    flip_engine #(
        .DATASPIN(DATASPIN),
        .FLIP_ICON_DEPTH(FLIP_ICON_DEPTH),
        .FLIP_ICON_ADDR_DEPTH(FLIP_ICON_ADDR_DEPTH)
    ) u_flip_engine (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .en_i(en_i),
        .cmpt_en_i(cmpt_en_i),
        .flush_i(flush_i),
        .prev_spin_valid_i(spin_pop_valid_p),
        .prev_spin_i(spin_pop_p),
        .prev_spin_ready_o(spin_pop_ready_p),
        .flipped_spin_ready_i(spin_pop_ready_i),
        .flipped_spin_o(spin_pop_o),
        .flipped_spin_valid_o(spin_pop_valid_o),
        .flip_ren_o(flip_ren_o),
        .flip_raddr_o(flip_raddr_o),
        .flip_rdata_i(flip_rdata_i),
        .icon_last_raddr_plus_one_i(icon_last_raddr_plus_one_i),
        .icon_finish_o(icon_finish),
        .flip_disable_i(flip_disable_i)
    );

endmodule
