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
// - DATASPIN: number of spins, must be multiple of PARALLELISM
// - SCALING_BIT: number of bits of scaling factor for h
// - PARALLELISM: number of parallel energy calculation units
// - LOCAL_ENERGY_BIT: bit precision of partial energy value
// - ENERGY_TOTAL_BIT: bit precision of total energy value
// - LITTLE_ENDIAN: storage format of weight matrix and spin vector, 1 for little-endian, 0 for big-endian
// - PIPESINTF: number of pipeline stages for each input path interface
// - PIPESMID: number of pipeline stages at the middle adder tree interface
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
//
// Case tested:
// - BITJ=4, BITH=4, DATASPIN=256, SCALING_BIT=5, LOCAL_ENERGY_BIT=16, ENERGY_TOTAL_BIT=32, PIPESINTF=0/1/2
// -- All spins are 1, all weights are +1, hbias=+1, hscaling=1, 20 same cases
// -- All spins are 0, all weights are +1, hbias=+1, hscaling=1, 20 same cases
// -- All spins are 0, all weights are -1, hbias=-1, hscaling=1, 20 same cases
// -- All spins are 1, all weights are -1, hbias=-1, hscaling=1, 20 same cases
// -- All spins are 1, all weights are +7, hbias=+7, hscaling=16, 20 same cases
// -- All spins are 0, all weights are -7, hbias=-7, hscaling=16, 20 same cases
// -- All spins and weights are random, hbias and hscaling are random, 1,000,000 different cases

`include "common_cells/registers.svh"

`define True 1'b1
`define False 1'b0

module energy_monitor #(
    parameter int BITJ = 4,
    parameter int BITH = 4,
    parameter int DATASPIN = 256,
    parameter int SCALING_BIT = 4,
    parameter int PARALLELISM = 4,
    parameter int ENERGY_TOTAL_BIT = 32,
    parameter int LITTLE_ENDIAN = `True,
    parameter int PIPESINTF = 0,
    parameter int PIPESMID = 0,
    parameter int LOCAL_ENERGY_BIT = $clog2(DATASPIN) + BITH + SCALING_BIT - 1,
    parameter int DATAJ = DATASPIN * BITJ * PARALLELISM,
    parameter int DATAH = BITH * PARALLELISM,
    parameter int DATASCALING = SCALING_BIT * PARALLELISM,
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
    input logic [DATAH-1:0] hbias_i,
    input logic [DATASCALING-1:0] hscaling_i,
    output logic weight_ready_o,
    output logic [SPINIDX_BIT-1:0] counter_spin_o,

    output logic energy_valid_o,
    input logic energy_ready_i,
    output logic signed [ENERGY_TOTAL_BIT-1:0] energy_o
);
    // pipe all input signals
    logic config_valid_pipe;
    logic [SPINIDX_BIT-1:0] config_counter_pipe;
    logic config_ready_pipe;

    logic [DATASPIN-1:0] spin_pipe;
    logic spin_valid_pipe;
    logic spin_ready_pipe;

    logic [DATAJ-1:0] weight_pipe;
    logic signed [DATAH-1:0] hbias_pipe;
    logic unsigned [DATASCALING-1:0] hscaling_pipe;
    logic weight_valid_pipe;
    logic weight_ready_pipe;

    // internal signals
    logic [DATASPIN-1:0] spin_cached;
    logic [SPINIDX_BIT-1:0] counter_q;
    logic counter_ready;
    logic cmpt_done;
    logic [PARALLELISM-1:0] current_spin;
    logic [PARALLELISM-1:0] current_spin_raw;
    logic signed [LOCAL_ENERGY_BIT*PARALLELISM-1:0] local_energy;
    logic signed [LOCAL_ENERGY_BIT + $clog2(PARALLELISM) - 1:0] local_energy_parallel;

    // handshake signals
    logic spin_handshake;
    logic weight_handshake;
    logic energy_handshake;
    logic [PIPESMID:0] weight_handshake_accum;

    genvar i;

    assign counter_spin_o = counter_q;
    assign spin_handshake = spin_valid_pipe && spin_ready_pipe;
    assign weight_handshake = weight_valid_pipe && weight_ready_pipe;
    assign energy_handshake = energy_valid_o && energy_ready_i;
    assign weight_handshake_accum[0] = weight_handshake;
    generate
        for (i = 0; i < PIPESMID; i++) begin: gen_weight_handshake_accum
            `FFL(weight_handshake_accum[i+1], weight_handshake_accum[i], en_i, 1'b0, clk_i, rst_ni);
        end
    endgenerate

    // pipeline interfaces
    bp_pipe #(
        .DATAW(SPINIDX_BIT),
        .PIPES(PIPESINTF)
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
        .PIPES(PIPESINTF)
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
        .DATAW(DATAJ + DATAH + DATASCALING),
        .PIPES(PIPESINTF)
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
    logic_ctrl #(
        .PIPESMID(PIPESMID)
    ) u_logic_ctrl (
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
        .debug_en_i(1'b0) // disable debug_en_i
    );

    // Counter path
    step_counter #(
        .COUNTER_BITWIDTH(SPINIDX_BIT),
        .PARALLELISM(PARALLELISM)
    ) u_step_counter (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .en_i(en_i),
        .load_i(config_valid_pipe && config_ready_pipe),
        .d_i(config_counter_pipe),
        .recount_en_i(spin_handshake),
        .step_en_i(weight_handshake),
        .q_o(counter_q),
        .overflow_o(counter_ready)
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

    // N-to-PARALLELISM mux for a vector
    if (LITTLE_ENDIAN == `True) begin: little_endian_spin_vector
        assign current_spin_raw = en_i ? spin_cached[counter_q +: PARALLELISM] : '0;
    end else begin: big_endian_spin_vector
        assign current_spin_raw = en_i ? spin_cached[DATASPIN - 1 - counter_q -: PARALLELISM] : '0;
    end

    // map raw bits to current_spin
    generate
        for (i = 0; i < PARALLELISM; i = i + 1) begin: map_current_spin
            if (LITTLE_ENDIAN == `True) begin
                assign current_spin[i] = current_spin_raw[i];
            end else begin
                assign current_spin[i] = current_spin_raw[PARALLELISM - 1 - i];
            end
        end
    endgenerate

    // Energy calculation and accumulation
    generate
        for (i = 0; i < PARALLELISM; i = i + 1) begin: partial_energy_calc_inst
            partial_energy_calc #(
                .BITJ(BITJ),
                .BITH(BITH),
                .DATASPIN(DATASPIN),
                .SCALING_BIT(SCALING_BIT),
                .PIPES(PIPESMID)
            ) u_partial_energy_calc (
                .clk_i(clk_i),
                .rst_ni(rst_ni),
                .en_i(en_i),
                .data_valid_i(weight_handshake),
                .spin_vector_i(spin_cached),
                .current_spin_i(current_spin[i]),
                .weight_i(weight_pipe[i*BITJ*DATASPIN +: BITJ*DATASPIN]),
                .hbias_i(hbias_pipe[i*BITH +: BITH]),
                .hscaling_i(hscaling_pipe[i*SCALING_BIT +: SCALING_BIT]),
                .energy_o(local_energy[i*LOCAL_ENERGY_BIT +: LOCAL_ENERGY_BIT])
            );
        end
    endgenerate

    // Sum the parallel local energy
    always_comb begin
        local_energy_parallel = '0;
        for (int i = 0; i < PARALLELISM; i++) begin
            local_energy_parallel += $signed(local_energy[i*LOCAL_ENERGY_BIT +: LOCAL_ENERGY_BIT]);
        end
    end

    // Accumulator
    accumulator #(
        .IN_WIDTH(LOCAL_ENERGY_BIT + $clog2(PARALLELISM)),
        .ACCUM_WIDTH(ENERGY_TOTAL_BIT)
    ) u_accumulator (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .en_i(en_i),
        .clear_i(energy_handshake), // clear when the output energy is accepted
        .valid_i(weight_handshake_accum[PIPESMID]),
        .data_i(local_energy_parallel),
        .accum_o(energy_o),
        .overflow_o(),
        .valid_o(cmpt_done)
    );

endmodule
