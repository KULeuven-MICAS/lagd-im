// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Module description:
// Flip manager module.
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

`include "../lib/registers.svh"

module flip_manager #(
    parameter int DATASPIN = 256,
    parameter int SPIN_DEPTH = 2,
    parameter int ENERGY_TOTAL_BIT = 32,
    parameter int FLIP_ICON_DEPTH = 1024,
    parameter int FLIP_ICON_ADDR_DEPTH = $clog2(FLIP_ICON_DEPTH),
    parameter int PIPES = 1
)(
    input logic clk_i,
    input logic rst_ni,
    input logic en_i,
    input logic flush_i,

    input logic cmpt_en_i,
    input logic cmpt_stop_i,

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
    output logic [FLIP_ICON_ADDR_DEPTH-1:0] flip_raddr_o,
    input logic [DATASPIN-1:0] flip_rdata_i,

    input logic debug_flip_disable_i
);
    // Internal signals
    logic debug_cmpt_status;
    logic [($clog2(SPIN_DEPTH))-1:0] debug_spin_fifo_usage, debug_energy_fifo_usage;
    logic spin_pop_valid_p;
    logic [DATASPIN-1:0] spin_pop_p;
    logic spin_pop_ready_n;
    logic spin_maintainer_push;
    logic [DATASPIN-1:0] spin_maintainer_income;
    logic spin_maintainer_push_ready;
    logic spin_maintainer_push_none;
    logic cmpt_stop_comb;
    logic icon_finish;

    // handshake signals
    logic spin_pop_handshake;
    logic energy_handshake;

    assign spin_pop_handshake = spin_pop_valid_o & spin_pop_ready_i;
    assign energy_handshake = energy_valid_i & energy_ready_o;
    assign cmpt_stop_comb = cmpt_stop_i & icon_finish;

    // Instantiate energy maintainer
    energy_maintainer #(
        .DATASPIN(DATASPIN),
        .SPIN_DEPTH(SPIN_DEPTH),
        .ENERGY_TOTAL_BIT(ENERGY_TOTAL_BIT)
    ) energy_maintainer_inst (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .en_i(en_i),
        .flush_i(flush_i),
        .spin_valid_o(spin_maintainer_push),
        .spin_o(spin_maintainer_income),
        .spin_push_none_o(spin_maintainer_push_none),
        .spin_ready_i(spin_maintainer_push_ready),
        .spin_valid_i(spin_valid_i),
        .spin_i(spin_i),
        .spin_ready_o(spin_ready_o),
        .energy_valid_i(energy_valid_i),
        .energy_ready_o(energy_ready_o),
        .energy_i(energy_i),
        .debug_fifo_usage_o(debug_energy_fifo_usage)
    );

    // Instantiate spin FIFO maintainer
    spin_fifo_maintainer #(
        .SPIN_DEPTH(SPIN_DEPTH),
        .DATASPIN(DATASPIN)
    ) spin_fifo_maintainer_inst (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .en_i(en_i),
        .flush_i(flush_i),
        .cmpt_en_i(cmpt_en_i),
        .cmpt_stop_i(cmpt_stop_comb),
        .spin_push_valid_i(spin_maintainer_push),
        .spin_push_i(spin_maintainer_income),
        .spin_push_none_i(spin_maintainer_push_none),
        .spin_push_ready_o(spin_maintainer_push_ready),
        .spin_pop_valid_o(spin_pop_valid_p),
        .spin_pop_o(spin_pop_p),
        .spin_pop_ready_i(spin_pop_ready_n),
        .debug_cmpt_status_o(debug_cmpt_status),
        .debug_fifo_usage_o(debug_spin_fifo_usage)
    );

    // Instantiate flip engine
    flip_engine #(
        .DATASPIN(DATASPIN),
        .FLIP_ICON_DEPTH(FLIP_ICON_DEPTH),
        .FLIP_ICON_ADDR_DEPTH(FLIP_ICON_ADDR_DEPTH)
    ) flip_engine_inst (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .en_i(en_i),
        .cmpt_en_i(cmpt_en_i),
        .flush_i(flush_i),
        .prev_spin_valid_i(spin_pop_valid_p),
        .prev_spin_i(spin_pop_p),
        .prev_spin_ready_o(spin_pop_ready_n),
        .flipped_spin_ready_i(spin_pop_ready_i),
        .flipped_spin_o(spin_pop_o),
        .flipped_spin_valid_o(spin_pop_valid_o),
        .flip_ren_o(flip_ren_o),
        .flip_raddr_o(flip_raddr_o),
        .flip_rdata_i(flip_rdata_i),
        .icon_finish_o(icon_finish),
        .debug_flip_disable_i(debug_flip_disable_i)
    );

endmodule
