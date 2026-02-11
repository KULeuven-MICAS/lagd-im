// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// flip filter module

`include "common_cells/registers.svh"

module flip_filter #(
    parameter int unsigned NUM_SPIN = 256,
    parameter int unsigned ENERGY_TOTAL_BIT = 32,
    parameter int unsigned PARALLELISM = 4,
    parameter int unsigned SPIN_DEPTH = 2,
    parameter int LITTLE_ENDIAN = 0,
    parameter int unsigned PIPESINTF = 0,
    parameter int unsigned PIPES_IN_ARBITER = 0,
    // Derived parameters
    parameter int unsigned NUM_BLOCK = NUM_SPIN / PARALLELISM,
    parameter int unsigned ADDR_WIDTH = $clog2(NUM_BLOCK)
) (
    input  logic                        clk_i,
    input  logic                        rst_ni,
    input  logic                        en_i,
    input  logic                        enable_flip_detection_i,
    input  logic                        flush_i,
    // configuration inputs
    input  logic [ADDR_WIDTH-1      :0] raddr_upper_bound_i,

    // baseline energy and spin inputs
    input  wire [SPIN_DEPTH-1:0] [ENERGY_TOTAL_BIT-1:0] energy_baseline_i,
    input  wire [SPIN_DEPTH-1:0] [NUM_SPIN-1        :0] spin_baseline_i,
    output logic                        curr_baseline_valid_o,

    // spin upstream inputs
    input  logic                        spin_upstream_valid_i,
    output logic                        spin_upstream_ready_o,
    input  logic [NUM_SPIN-1        :0] spin_upstream_i,

    // spin downstream outputs
    output logic                        spin_downstream_valid_o,
    input  logic                        spin_downstream_ready_i,
    output logic [NUM_SPIN-1        :0] spin_downstream_o,

    // memory outputs
    output logic                        raddr_valid_o,
    input  logic                        raddr_ready_i,
    output logic [ADDR_WIDTH-1      :0] raddr_o,
    output logic [PARALLELISM-1     :0] block_bits_flipped_o,
    output logic                        raddr_last_one_o,

    // ouputs to the top module
    output logic [ENERGY_TOTAL_BIT-1:0] energy_baseline_o,
    output logic [NUM_SPIN-1        :0] spin_baseline_o,
    output logic [NUM_SPIN-1        :0] bits_unflipped_o,
    output logic                        empty_o
);
    // Internal signals
    logic [NUM_SPIN-1:0] spin_upstream_pipe;
    logic spin_upstream_valid_pipe;
    logic spin_upstream_ready_pipe;
    logic curr_baseline_valid, curr_baseline_valid_reg;
    logic [NUM_SPIN-1:0] spin_baseline_selected;
    logic [ENERGY_TOTAL_BIT-1:0] energy_baseline_selected;
    logic [$clog2(SPIN_DEPTH)-1:0] baseline_idx;
    logic baseline_idx_maxed;
    logic [NUM_SPIN-1:0] bits_flipped_comb, bits_flipped_comb_muxed, bits_flipped_reg, bits_flipped_merged;
    logic busy_en_cond, busy_reset_cond;
    logic raddr_last_one_gen;
    logic busy_reg;
    logic valid_gen;
    logic [ADDR_WIDTH-1:0] raddr_gen;
    logic spin_upstream_handshake_pipe;
    logic spin_downstream_handshake;
    logic [NUM_SPIN/PARALLELISM-1:0] grant_block_one_hot_gen;
    logic baseline_valid_cnt_maxed;
    logic [SPIN_DEPTH-1:0] [ENERGY_TOTAL_BIT-1:0] energy_baseline_pipe;
    logic [SPIN_DEPTH-1:0] [NUM_SPIN-1        :0] spin_baseline_pipe;
    logic raddr_last_one_handshake;

    // pipeline interfaces
    bp_pipe #(
        .DATAW(NUM_SPIN + (ENERGY_TOTAL_BIT + NUM_SPIN) * SPIN_DEPTH),
        .PIPES(PIPESINTF)
    ) u_pipe_ups (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .flush_i(flush_i),
        .data_i({spin_upstream_i, energy_baseline_i, spin_baseline_i}),
        .data_o({spin_upstream_pipe, energy_baseline_pipe, spin_baseline_pipe}),
        .valid_i(spin_upstream_valid_i),
        .valid_o(spin_upstream_valid_pipe),
        .ready_i(spin_upstream_ready_pipe),
        .ready_o(spin_upstream_ready_o)
    );

    // Control flow
    assign spin_upstream_handshake_pipe = spin_upstream_valid_pipe & spin_upstream_ready_pipe;
    assign spin_downstream_handshake = spin_downstream_valid_o & spin_downstream_ready_i;

    assign spin_upstream_ready_pipe = !busy_reg & spin_downstream_ready_i;
    assign spin_downstream_valid_o = ~empty_o & spin_upstream_handshake_pipe;
    assign empty_o = ~(|bits_flipped_merged);

    assign curr_baseline_valid = curr_baseline_valid_reg;
    assign curr_baseline_valid_o = curr_baseline_valid;

    assign busy_en_cond = en_i & spin_upstream_handshake_pipe & ~empty_o;
    assign busy_reset_cond = flush_i | raddr_last_one_handshake;

    assign raddr_valid_o = busy_reg;
    assign raddr_last_one_o = empty_o ? 1'b1 : raddr_last_one_gen;
    assign raddr_last_one_handshake = empty_o ? 1'b1 : (raddr_last_one_gen & raddr_valid_o & raddr_ready_i);

    // Data path
    assign spin_downstream_o = spin_upstream_pipe;
    assign raddr_o = raddr_gen;
    assign bits_flipped_merged = spin_upstream_handshake_pipe ? bits_flipped_comb : bits_flipped_reg;
    assign bits_flipped_comb = (curr_baseline_valid & spin_upstream_handshake_pipe & enable_flip_detection_i) ? (spin_baseline_selected ^ spin_upstream_pipe) : {NUM_SPIN{1'b1}};
    assign bits_flipped_comb_muxed = empty_o ? {NUM_SPIN{1'b1}} : bits_flipped_comb;
    assign bits_unflipped_o = curr_baseline_valid ? ~bits_flipped_merged : {NUM_SPIN{1'b1}};
    assign energy_baseline_o = energy_baseline_selected;
    assign spin_baseline_o = spin_baseline_selected;

    always_comb begin
        energy_baseline_selected = 'd0;
        spin_baseline_selected = 'd0;
        for (int i = 0; i < SPIN_DEPTH; i = i + 1) begin
            if (baseline_idx == i) begin
                energy_baseline_selected = energy_baseline_pipe[i];
                spin_baseline_selected = spin_baseline_pipe[i];
            end
        end
    end

    always_comb begin
        block_bits_flipped_o = {PARALLELISM{1'b1}};
        if (curr_baseline_valid) begin
            for (int i = 0; i < NUM_SPIN/PARALLELISM; i = i + 1) begin
                if (grant_block_one_hot_gen[i]) begin
                    block_bits_flipped_o = bits_flipped_merged[i*PARALLELISM +: PARALLELISM];
                end
            end
        end
    end

    // Sequential logic
    `FFLARNC(busy_reg, 1'b1, busy_en_cond, busy_reset_cond, 1'b0, clk_i, rst_ni);
    `FFLARNC(curr_baseline_valid_reg, 1'b1, (baseline_valid_cnt_maxed & raddr_last_one_handshake), flush_i, 1'b0, clk_i, rst_ni);
    `FFLARNC(bits_flipped_reg, bits_flipped_comb_muxed, spin_upstream_handshake_pipe, flush_i, {NUM_SPIN{1'b1}}, clk_i, rst_ni);

    // counter for monitoring when baseline data is ready
    if (SPIN_DEPTH > 1) begin
        step_counter #(
            .COUNTER_BITWIDTH($clog2(SPIN_DEPTH)),
            .PARALLELISM(1)
        ) u_baseline_valid_counter (
            .clk_i(clk_i),
            .rst_ni(rst_ni),
            .en_i(en_i),
            .load_i(1'b0),
            .d_i(1'b0),
            .recount_en_i(flush_i),
            .step_en_i(raddr_last_one_handshake),
            .q_o(),
            .maxed_o(baseline_valid_cnt_maxed),
            .overflow_o()
        );
    end else begin
        assign baseline_valid_cnt_maxed = 1'b1;
    end

    // counter for selecting which baseline data to use
    if (SPIN_DEPTH > 1) begin
        step_counter #(
            .COUNTER_BITWIDTH($clog2(SPIN_DEPTH)),
            .PARALLELISM(1)
        ) u_baseline_counter (
            .clk_i(clk_i),
            .rst_ni(rst_ni),
            .en_i(en_i),
            .load_i(1'b0),
            .d_i(1'b0),
            .recount_en_i(flush_i | (raddr_last_one_handshake & baseline_idx_maxed)),
            .step_en_i(raddr_last_one_handshake),
            .q_o(baseline_idx),
            .maxed_o(baseline_idx_maxed),
            .overflow_o()
        );
    end else begin
        assign baseline_idx = 1'b0;
    end

    // read address generator
    dgt_raddr_manager #(
        .NUM_REQ         ( NUM_SPIN               ),
        .PARALLELISM     ( PARALLELISM            ),
        .LSB_PRIORITY    ( LITTLE_ENDIAN          ),
        .PIPES_IN_ARBITER( PIPES_IN_ARBITER       )
    ) u_raddr_gen (
        .clk_i                  ( clk_i                         ),
        .rst_ni                 ( rst_ni                        ),
        .en_i                   ( en_i                          ),
        .flush_i                ( flush_i                       ),
        .req_valid_i            ( spin_upstream_handshake_pipe  ),
        .req_i                  ( bits_flipped_merged           ),
        .addr_upper_bound_i     ( raddr_upper_bound_i           ),
        .idx_valid_o            ( valid_gen                     ),
        .idx_ready_i            ( raddr_ready_i                 ),
        .idx_o                  ( raddr_gen                     ),
        .grant_block_one_hot_o  ( grant_block_one_hot_gen       ),
        .empty_o                (                               ),
        .idx_last_one_o         ( raddr_last_one_gen            )
    );

endmodule
