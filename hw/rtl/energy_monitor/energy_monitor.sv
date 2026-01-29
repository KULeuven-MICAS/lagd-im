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
// - SPIN_DEPTH: depth of spin fifo
// - NUM_SPIN: number of spins, must be multiple of PARALLELISM
// - SCALING_BIT: number of bits of scaling factor for h
// - PARALLELISM: number of parallel energy calculation units
// - LOCAL_ENERGY_BIT: bit precision of partial energy value
// - ENERGY_TOTAL_BIT: bit precision of total energy value
// - LITTLE_ENDIAN: storage format of weight matrix and spin vector, 1 for little-endian, 0 for big-endian
// - PIPESINTF: number of pipeline stages for each input path interface
// - PIPESMID: number of pipeline stages at the middle adder tree interface
// - ENABLE_EXTERNAL_FINISH_SIGNAL: enable external finish signal for energy computation
// - H_IS_NEGATIVE: whether h bias is negative
//
// Port definitions:
// - clk_i: input clock signal
// - rst_ni: asynchornous reset, active low
// - en_i: module enable signal
// - flush_i: flush signal
// - en_external_counter_i: enable external counter signal
// - config_valid_i: input config valid signal
// - config_counter_i: configuration counter
// - config_ready_o: output config ready signal
// - spin_valid_i: input spin valid signal
// - spin_i: input spin data
// - spin_ready_o: output spin ready signal
// - weight_valid_i: input weight valid signal
// - weight_valid_parallel_i: input weight valid signal for each parallel unit
// - external_counter_q_i: external counter value
// - external_finish_i: external finish signal
// - double_weight_contri_i: double weight contribution signal
// - weight_i: input weight data
// - hbias_i: h bias
// - hscaling_i: h scaling factor
// - energy_baseline_in_i: input baseline energy value
// - weight_ready_o: output weight ready signal
// - energy_valid_o: output energy valid signal
// - energy_ready_i: input energy ready signal
// - energy_baseline_out_o: output baseline energy value
// - energy_o: output energy value
// - spin_o: output spin data
// - busy_o: module busy signal
// - baseline_done_o: baseline energy computation done signal
//
// Case tested:
// - BITJ=4, BITH=4, NUM_SPIN=256, SCALING_BIT=5, LOCAL_ENERGY_BIT=16, ENERGY_TOTAL_BIT=32, PIPESINTF=0/1/2
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
    parameter int SPIN_DEPTH = 2,
    parameter int NUM_SPIN = 256,
    parameter int SCALING_BIT = 4,
    parameter int PARALLELISM = 4,
    parameter int ENERGY_TOTAL_BIT = 32,
    parameter int LITTLE_ENDIAN = `True,
    parameter int PIPESINTF = 0,
    parameter int PIPESMID = 0,
    parameter bit ENABLE_EXTERNAL_FINISH_SIGNAL = `False,
    parameter bit H_IS_NEGATIVE = `True,
    // Derived parameters
    parameter int LOCAL_ENERGY_BIT = $clog2(NUM_SPIN) + BITH + SCALING_BIT - 1 + 1,
    parameter int DATAJ = NUM_SPIN * BITJ * PARALLELISM,
    parameter int DATAH = BITH * PARALLELISM,
    parameter int DATASCALING = SCALING_BIT * PARALLELISM,
    parameter int SPINIDX_BIT = $clog2(NUM_SPIN)
)(
    input logic clk_i,
    input logic rst_ni,
    input logic en_i,
    input logic flush_i,
    input logic en_external_counter_i,

    input logic config_valid_i,
    input logic [SPINIDX_BIT-1:0] config_counter_i,
    output logic config_ready_o,

    input logic spin_valid_i,
    input logic [NUM_SPIN-1:0] spin_i,
    output logic spin_ready_o,

    input logic weight_valid_i,
    input logic [PARALLELISM-1:0] weight_valid_parallel_i,
    input logic [SPINIDX_BIT-1:0] external_counter_q_i,
    input logic external_finish_i,
    input logic double_weight_contri_i,
    input logic [DATAJ-1:0] weight_i,
    input logic [DATAH-1:0] hbias_i,
    input logic [DATASCALING-1:0] hscaling_i,
    input logic signed [ENERGY_TOTAL_BIT-1:0] energy_baseline_in_i,
    output logic weight_ready_o,
    output logic [SPINIDX_BIT-1:0] counter_spin_o,

    output logic energy_valid_o,
    input logic energy_ready_i,
    output logic signed [ENERGY_TOTAL_BIT-1:0] energy_baseline_out_o,
    output logic signed [ENERGY_TOTAL_BIT-1:0] energy_o,
    output logic [NUM_SPIN-1:0] spin_o,

    output logic busy_o,
    output logic baseline_done_o
);
    // pipe all input signals
    logic config_valid_pipe;
    logic [SPINIDX_BIT-1:0] config_counter_pipe;
    logic config_ready_pipe;

    logic [NUM_SPIN-1:0] spin_pipe;
    logic spin_valid_pipe;
    logic spin_ready_pipe;

    logic [PARALLELISM-1:0] weight_valid_parallel_pipe;
    logic [DATAJ-1:0] weight_pipe;
    logic signed [DATAH-1:0] hbias_pipe;
    logic unsigned [DATASCALING-1:0] hscaling_pipe;
    logic weight_valid_pipe;
    logic weight_ready_pipe;
    logic external_finish_pipe;
    logic [SPINIDX_BIT-1:0] external_counter_q_pipe;
    logic signed [ENERGY_TOTAL_BIT-1:0] energy_baseline_in_pipe;

    // internal signals
    logic [NUM_SPIN-1:0] spin_cached;
    logic [SPINIDX_BIT-1:0] counter_q, counter_q_int;
    logic counter_ready, counter_ready_ext, counter_ready_int;
    logic cmpt_done;
    logic [PARALLELISM-1:0] current_spin;
    logic [PARALLELISM-1:0] current_spin_raw;
    logic signed [LOCAL_ENERGY_BIT*PARALLELISM-1:0] local_energy;
    logic signed [LOCAL_ENERGY_BIT + $clog2(PARALLELISM) - 1 + 1:0] local_energy_parallel;
    logic signed [ENERGY_TOTAL_BIT-1+1:0] energy_doubled;
    logic signed [ENERGY_TOTAL_BIT-1:0] energy_positive, energy_signed;
    logic signed [ENERGY_TOTAL_BIT-1:0] energy_out_comb, energy_out_reg;
    logic double_weight_contri_pipe;
    logic energy_fifo_fst_sweep_finish;
    logic energy_valid_dly1;
    logic busy_comb;

    // handshake signals
    logic spin_handshake;
    logic weight_handshake;
    logic energy_handshake;
    logic [PIPESMID:0] weight_handshake_accum;
    logic [PIPESMID:0] [PARALLELISM-1:0] weight_valid_parallel_pipe_accum;

    genvar i;

    assign spin_o = spin_cached;
    assign counter_spin_o = counter_q;
    assign spin_handshake = spin_valid_pipe && spin_ready_pipe;
    assign weight_handshake = weight_valid_pipe && weight_ready_pipe;
    assign energy_handshake = energy_valid_o && energy_ready_i;
    assign weight_handshake_accum[0] = weight_handshake;
    assign weight_valid_parallel_pipe_accum[0] = weight_valid_parallel_pipe;
    assign energy_positive = energy_doubled / 2; // divide by 2 to compensate double counting
    assign baseline_done_o = energy_fifo_fst_sweep_finish;

    assign energy_out_comb = en_external_counter_i & energy_fifo_fst_sweep_finish ? energy_signed * 2 + energy_baseline_out_o : energy_signed;
    assign energy_o = energy_valid_o ? energy_out_comb : energy_out_reg;

    `FFLARNC(energy_valid_dly1, energy_valid_o, en_i, flush_i, 1'b0, clk_i, rst_ni);
    `FFLARNC(energy_out_reg, energy_out_comb, en_i & (energy_valid_o & (~energy_valid_dly1)), flush_i, 1'b0, clk_i, rst_ni);

    generate
        if (H_IS_NEGATIVE == `True) begin
            assign energy_signed = -energy_positive;
        end else begin
            assign energy_signed = energy_positive;
        end
    endgenerate

    generate
        for (i = 0; i < PIPESMID; i++) begin: gen_weight_handshake_accum
            `FFL(weight_handshake_accum[i+1], weight_handshake_accum[i], en_i, 1'b0, clk_i, rst_ni);
            `FFL(weight_valid_parallel_pipe_accum[i+1], weight_valid_parallel_pipe_accum[i], en_i, 1'b0, clk_i, rst_ni);
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
        .DATAW(NUM_SPIN),
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
        .DATAW(DATAJ + DATAH + DATASCALING + PARALLELISM + 1 + SPINIDX_BIT + 1 + ENERGY_TOTAL_BIT),
        .PIPES(PIPESINTF)
    ) u_pipe_weight (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .data_i({weight_i, hbias_i, hscaling_i, weight_valid_parallel_i, external_finish_i, external_counter_q_i, double_weight_contri_i, energy_baseline_in_i}),
        .data_o({weight_pipe, hbias_pipe, hscaling_pipe, weight_valid_parallel_pipe, external_finish_pipe, external_counter_q_pipe, double_weight_contri_pipe, energy_baseline_in_pipe}),
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
        .flush_i(flush_i),
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
        .debug_en_i(1'b0), // disable debug_en_i
        .busy_o(busy_comb)
    );

    // Counter path
    generate
        if (ENABLE_EXTERNAL_FINISH_SIGNAL == `True) begin: external_counter_ctrl_state_machine
            logic busy_en_cond;
            logic spin_upstream_handshake;
            logic energy_downstream_handshake;
            logic [1:0] work_in_progress_reg, work_in_progress_comb; // at most 2 works in progress

            assign spin_upstream_handshake = spin_valid_i & spin_ready_o;
            assign energy_downstream_handshake = energy_valid_o & energy_ready_i;
            assign busy_en_cond = en_i & ((spin_valid_i & spin_ready_o) | (energy_valid_o & energy_ready_i));
            assign busy_o = work_in_progress_reg != 2'd0;

            assign counter_ready = en_external_counter_i ? counter_ready_ext : counter_ready_int;
            assign counter_q = en_external_counter_i ? external_counter_q_pipe : counter_q_int;

            always_comb begin
                case ({spin_upstream_handshake, energy_downstream_handshake})
                    2'b11: work_in_progress_comb = work_in_progress_reg; // one in, one out
                    2'b10: work_in_progress_comb = work_in_progress_reg + 2'd1; // one in
                    2'b01: work_in_progress_comb = work_in_progress_reg - 2'd1; // one out
                    default: work_in_progress_comb = work_in_progress_reg; // (00) no change
                endcase
            end

            `FFL(energy_baseline_out_o, energy_baseline_in_pipe, en_i & en_external_counter_i & external_finish_pipe, '0, clk_i, rst_ni);
            `FFLARNC(work_in_progress_reg, work_in_progress_comb, busy_en_cond, flush_i, '0, clk_i, rst_ni);

            // delayed counters for external finish signal
            step_counter #(
                .COUNTER_BITWIDTH(PIPESINTF),
                .PARALLELISM(1)
            ) u_external_counter (
                .clk_i(clk_i),
                .rst_ni(rst_ni),
                .en_i(en_i),
                .load_i(1'b0),
                .d_i(1'b1),
                .recount_en_i(flush_i | spin_handshake),
                .step_en_i(external_finish_pipe),
                .q_o(),
                .maxed_o(counter_ready_ext),
                .overflow_o()
            );

            // first sweep counter for energy fifo
            if (SPIN_DEPTH > 1) begin
                step_counter #(
                    .COUNTER_BITWIDTH($clog2(SPIN_DEPTH)),
                    .PARALLELISM(1)
                ) u_energy_fifo_sweep_counter (
                    .clk_i(clk_i),
                    .rst_ni(rst_ni),
                    .en_i(en_i),
                    .load_i(1'b0),
                    .d_i(1'b0),
                    .recount_en_i(flush_i),
                    .step_en_i(energy_handshake),
                    .q_o(),
                    .maxed_o(),
                    .overflow_o(energy_fifo_fst_sweep_finish)
                );
            end else begin
                `FFLARNC(energy_fifo_fst_sweep_finish, 1'b1, energy_handshake, flush_i, 1'b0, clk_i, rst_ni);
            end
        end else begin: internal_counter_ctrl_state_machine
            assign counter_ready = counter_ready_int;
            assign counter_q = counter_q_int;
            assign energy_baseline_out_o = 'd0;
            assign busy_o = busy_comb;
            assign energy_fifo_fst_sweep_finish = 1'b0;
        end
    endgenerate

    step_counter #(
        .COUNTER_BITWIDTH(SPINIDX_BIT),
        .PARALLELISM(PARALLELISM)
    ) u_step_counter (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .en_i(en_i),
        .load_i(config_valid_pipe && config_ready_pipe),
        .d_i(config_counter_pipe),
        .recount_en_i(flush_i | spin_handshake),
        .step_en_i(weight_handshake),
        .q_o(counter_q_int),
        .maxed_o(),
        .overflow_o(counter_ready_int)
    );

    // Spin path
    vector_caching #(
        .DATAWIDTH(NUM_SPIN)
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
        assign current_spin_raw = en_i ? spin_cached[NUM_SPIN - 1 - counter_q -: PARALLELISM] : '0;
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
            if (LITTLE_ENDIAN == `True) begin: select_hbias_in_little_endian
                partial_energy_calc #(
                    .BITJ(BITJ),
                    .BITH(BITH),
                    .NUM_SPIN(NUM_SPIN),
                    .SCALING_BIT(SCALING_BIT),
                    .PIPES(PIPESMID)
                ) u_partial_energy_calc (
                    .clk_i(clk_i),
                    .rst_ni(rst_ni),
                    .en_i(en_i),
                    .data_valid_i(weight_handshake),
                    .spin_vector_i(spin_cached),
                    .current_spin_i(current_spin[i]),
                    .weight_i(weight_pipe[i*BITJ*NUM_SPIN +: BITJ*NUM_SPIN]),
                    .hbias_i(hbias_pipe[i*BITH +: BITH]),
                    .hscaling_i(hscaling_pipe[i*SCALING_BIT +: SCALING_BIT]),
                    .double_weight_contri_i(double_weight_contri_pipe),
                    .energy_o(local_energy[i*LOCAL_ENERGY_BIT +: LOCAL_ENERGY_BIT])
                );
            end else begin: select_hbias_in_big_endian
                partial_energy_calc #(
                    .BITJ(BITJ),
                    .BITH(BITH),
                    .NUM_SPIN(NUM_SPIN),
                    .SCALING_BIT(SCALING_BIT),
                    .PIPES(PIPESMID)
                ) u_partial_energy_calc (
                    .clk_i(clk_i),
                    .rst_ni(rst_ni),
                    .en_i(en_i),
                    .data_valid_i(weight_handshake),
                    .spin_vector_i(spin_cached),
                    .current_spin_i(current_spin[i]),
                    .weight_i(weight_pipe[i*BITJ*NUM_SPIN +: BITJ*NUM_SPIN]),
                    .hbias_i(hbias_pipe[(PARALLELISM - 1 - i)*BITH +: BITH]),
                    .hscaling_i(hscaling_pipe[(PARALLELISM - 1 - i)*SCALING_BIT +: SCALING_BIT]),
                    .double_weight_contri_i(double_weight_contri_pipe),
                    .energy_o(local_energy[i*LOCAL_ENERGY_BIT +: LOCAL_ENERGY_BIT])
                );
            end
        end
    endgenerate

    // Sum the parallel local energy
    always_comb begin
        local_energy_parallel = '0;
        for (int i = 0; i < PARALLELISM; i++) begin
            if (LITTLE_ENDIAN == `True) begin
                if (~en_external_counter_i | weight_valid_parallel_pipe_accum[PIPESMID][i]) begin
                    local_energy_parallel += $signed(local_energy[i*LOCAL_ENERGY_BIT +: LOCAL_ENERGY_BIT]);
                end
            end else begin
                if (~en_external_counter_i | weight_valid_parallel_pipe_accum[PIPESMID][PARALLELISM - 1 - i]) begin
                    local_energy_parallel += $signed(local_energy[i*LOCAL_ENERGY_BIT +: LOCAL_ENERGY_BIT]);
                end
            end
        end
    end

    // Accumulator
    accumulator #(
        .IN_WIDTH(LOCAL_ENERGY_BIT + $clog2(PARALLELISM)+1),
        .ACCUM_WIDTH(ENERGY_TOTAL_BIT+1)
    ) u_accumulator (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .en_i(en_i),
        .clear_i(flush_i | energy_handshake), // clear when the output energy is accepted
        .valid_i(weight_handshake_accum[PIPESMID]),
        .data_i(local_energy_parallel),
        .accum_o(energy_doubled),
        .overflow_o(),
        .valid_o(cmpt_done)
    );

endmodule
