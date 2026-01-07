// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Analog cfg module

`include "common_cells/registers.svh"

module analog_cfg #(
    parameter integer NUM_SPIN = 256,
    parameter integer BITDATA = 4,
    parameter integer PARALLELISM = 1, // min: 1
    parameter integer COUNTER_BITWIDTH = 16,
    parameter integer J_ADDRESS_WIDTH = $clog2(NUM_SPIN / PARALLELISM),
    parameter integer HADDR = NUM_SPIN / PARALLELISM
)(
    input logic clk_i,
    input logic rst_ni,
    input logic en_i,
    // config interface
    input  logic cfg_configure_enable_i,
    input  logic [COUNTER_BITWIDTH-1:0] cycle_per_wwl_high_i,
    input  logic [COUNTER_BITWIDTH-1:0] cycle_per_wwl_low_i,
    input  logic [COUNTER_BITWIDTH-1:0] cfg_trans_num_i,
    // data config interface <-> digital
    input  logic dt_cfg_enable_i,
    output logic j_mem_ren_o,
    output logic [J_ADDRESS_WIDTH-1:0] j_raddr_o,
    input  logic [NUM_SPIN*BITDATA*PARALLELISM-1:0] j_rdata_i,
    output logic h_ren_o,
    input  logic [NUM_SPIN*BITDATA-1:0] h_rdata_i,
    // data config interface -> analog macro
    output logic [NUM_SPIN-1:0] j_one_hot_wwl_o,
    output logic h_wwl_o,
    output logic [NUM_SPIN*BITDATA-1:0] wbl_o,
    // status
    output logic dt_cfg_idle_o
);
    // Internal signals
    logic [COUNTER_BITWIDTH-1:0] wwl_high_counter_q, wwl_low_counter_q, counter_addr_q;
    logic wwl_high_counter_overflow, wwl_low_counter_overflow;
    logic dt_cfg_finish;
    logic cfg_busy;
    logic wwl_high_counter_en, wwl_low_counter_en;
    logic wwl_high_counter_en_cond, wwl_low_counter_en_cond;
    logic wwl_high_counter_maxed, wwl_low_counter_maxed;
    logic h_ren_n, j_mem_ren_n;
    logic [NUM_SPIN*BITDATA-1:0] wbl_comb, j_rdata_wbl;
    logic [$clog2(PARALLELISM)-1:0] j_mux_sel_nxt, j_mux_sel_q;
    logic [$clog2(PARALLELISM)-1:0] j_mux_sel_nxt_delayed, j_mux_sel_q_delayed;
    logic cfg_busy_cond;
    logic cfg_idle_cond;
    logic h_wwl_en_cond, j_wwl_en_cond;
    logic h_wwl_idle_cond, j_wwl_idle_cond;
    logic [NUM_SPIN-1:0] j_one_hot_wwl_nxt;
    logic wbl_en_cond;
    logic j_mux_sel_cond, j_mux_sel_delayed_cond;
    logic j_mux_sel_idle_cond;
    logic dt_cfg_enable_dly1;
    logic j_mem_ren_p;

    assign h_ren_o = cfg_busy & (counter_addr_q == HADDR) & (~dt_cfg_finish) & wwl_low_counter_maxed;
    assign j_mem_ren_p = dt_cfg_enable_dly1 | 
        (cfg_busy & (counter_addr_q != HADDR) & (wwl_low_counter_maxed) & (j_mux_sel_q == 0));
    assign j_raddr_o = counter_addr_q[J_ADDRESS_WIDTH-1:0];
    assign wbl_comb = h_ren_n ? h_rdata_i : 
                      j_mem_ren_n ? j_rdata_i[NUM_SPIN*BITDATA-1 : 0] : j_rdata_wbl;
    assign j_mux_sel_nxt = (j_mux_sel_q == (PARALLELISM-1)) ? 'd0 : j_mux_sel_q + 1'b1;
    assign j_mux_sel_nxt_delayed = (j_mux_sel_q_delayed == (PARALLELISM-1)) ? 'd0 : j_mux_sel_q_delayed + 1'b1;
    assign dt_cfg_idle_o = !cfg_busy;
    assign cfg_busy_cond = en_i & dt_cfg_enable_i;
    assign cfg_idle_cond = !en_i | (dt_cfg_finish & wwl_low_counter_maxed);
    assign h_wwl_en_cond = en_i & h_ren_n;
    assign h_wwl_idle_cond = !en_i | (h_wwl_o & wwl_high_counter_maxed);
    assign j_one_hot_wwl_nxt = wwl_high_counter_en ? 'd0 : 
                    (counter_addr_q == 'd0 & j_mux_sel_q == 'd0) ? 'd1 : 1 << (counter_addr_q * PARALLELISM + j_mux_sel_q);
    assign j_wwl_en_cond = en_i & (j_mem_ren_n |
        (wwl_high_counter_maxed & (counter_addr_q != HADDR))
        | (wwl_low_counter_maxed & (j_mux_sel_q != 'd0)));
    assign j_wwl_idle_cond = cfg_idle_cond;
    assign wbl_en_cond = en_i & (!dt_cfg_finish) & (j_mem_ren_n | h_ren_n | ((~j_mem_ren_o) & (~h_ren_o) & wwl_low_counter_maxed));
    assign j_mux_sel_cond = en_i & wwl_high_counter_maxed & (counter_addr_q != HADDR);
    assign j_mux_sel_delayed_cond = en_i & wwl_low_counter_maxed;
    assign j_mux_sel_idle_cond = !en_i | dt_cfg_enable_i;
    assign wwl_high_counter_en_cond = en_i & (j_mem_ren_n | h_ren_n | (wwl_low_counter_maxed & (j_mux_sel_q != 'd0)));
    assign wwl_low_counter_en_cond = en_i & wwl_high_counter_maxed;

    assign j_mem_ren_o = j_mem_ren_p;
    `FFLARNC(cfg_busy, 1'b1, cfg_busy_cond, cfg_idle_cond, 1'b0, clk_i, rst_ni)
    `FFL(h_ren_n, h_ren_o, en_i, 1'b0, clk_i, rst_ni)
    `FFL(j_mem_ren_n, j_mem_ren_o, en_i, 1'b0, clk_i, rst_ni)
    `FFLARNC(h_wwl_o, 1'b1, h_wwl_en_cond, h_wwl_idle_cond, 1'b0, clk_i, rst_ni) // last for cycle_per_dt_write_i cycles
    `FFLARNC(j_one_hot_wwl_o, j_one_hot_wwl_nxt, j_wwl_en_cond, j_wwl_idle_cond, 'd0, clk_i, rst_ni) // last for cycle_per_dt_write_i cycles
    `FFL(wbl_o, wbl_comb, wbl_en_cond, 'd0, clk_i, rst_ni) // last for cycle_per_dt_write_i cycles
    `FFLARNC(j_mux_sel_q, j_mux_sel_nxt, j_mux_sel_cond, j_mux_sel_idle_cond, 'd0, clk_i, rst_ni)
    `FFLARNC(j_mux_sel_q_delayed, j_mux_sel_nxt_delayed, j_mux_sel_delayed_cond, j_mux_sel_idle_cond, 'd0, clk_i, rst_ni)
    `FFL(dt_cfg_enable_dly1, dt_cfg_enable_i, en_i, 1'b0, clk_i, rst_ni)
    `FFLARNC(wwl_high_counter_en, 1'b1, wwl_high_counter_en_cond, wwl_high_counter_maxed, 1'b0, clk_i, rst_ni)
    `FFLARNC(wwl_low_counter_en, 1'b1, wwl_low_counter_en_cond, wwl_low_counter_maxed, 1'b0, clk_i, rst_ni)

    always_comb begin
        j_rdata_wbl = '0;
        for (int i = 0; i < PARALLELISM; i++) begin
            if (j_mux_sel_q_delayed == i) begin
                // Select slice (i+1) % PARALLELISM
                if (i == PARALLELISM-1) begin
                    j_rdata_wbl = j_rdata_i[NUM_SPIN*BITDATA-1 -: NUM_SPIN*BITDATA];
                end else begin
                    j_rdata_wbl = j_rdata_i[(i+2)*NUM_SPIN*BITDATA-1 -: NUM_SPIN*BITDATA];
                end
            end
        end
    end

    step_counter #(
        .COUNTER_BITWIDTH (COUNTER_BITWIDTH),
        .PARALLELISM (1)
    ) i_wwl_high_counter (
        .clk_i (clk_i),
        .rst_ni (rst_ni),
        .en_i (en_i),
        .load_i (cfg_configure_enable_i),
        .d_i (cycle_per_wwl_high_i),
        .recount_en_i (dt_cfg_enable_i | wwl_high_counter_overflow),
        .step_en_i (wwl_high_counter_en),
        .q_o (wwl_high_counter_q),
        .maxed_o (wwl_high_counter_maxed),
        .overflow_o (wwl_high_counter_overflow)
    );

    step_counter #(
        .COUNTER_BITWIDTH (COUNTER_BITWIDTH),
        .PARALLELISM (1)
    ) i_wwl_low_counter (
        .clk_i (clk_i),
        .rst_ni (rst_ni),
        .en_i (en_i),
        .load_i (cfg_configure_enable_i),
        .d_i (cycle_per_wwl_low_i),
        .recount_en_i (dt_cfg_enable_i | wwl_low_counter_overflow),
        .step_en_i (wwl_low_counter_en),
        .q_o (wwl_low_counter_q),
        .maxed_o (wwl_low_counter_maxed),
        .overflow_o (wwl_low_counter_overflow)
    );

    step_counter #(
        .COUNTER_BITWIDTH (COUNTER_BITWIDTH),
        .PARALLELISM (1)
    ) i_mem_addr_counter (
        .clk_i (clk_i),
        .rst_ni (rst_ni),
        .en_i (en_i),
        .load_i (cfg_configure_enable_i),
        .d_i (cfg_trans_num_i),
        .recount_en_i (dt_cfg_enable_i),
        .step_en_i (en_i & wwl_high_counter_maxed & ((j_mux_sel_q == (PARALLELISM-1)) | (counter_addr_q == HADDR))),
        .q_o (counter_addr_q),
        .maxed_o (),
        .overflow_o (dt_cfg_finish)
    );

endmodule
