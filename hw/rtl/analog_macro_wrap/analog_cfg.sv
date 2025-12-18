// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Analog cfg module

`include "common_cells/registers.svh"

module analog_cfg #(
    parameter integer num_spin = 256,
    parameter integer bit_data = 4,
    parameter integer parallelism = 1, // min: 1
    parameter integer counter_bitwidth = 16,
    parameter integer j_address_width = $clog2(num_spin / parallelism),
    parameter integer h_counter_addr = num_spin / parallelism
)(
    input logic clk_i,
    input logic rst_ni,
    input logic en_i,
    // config interface
    input  logic cfg_configure_enable_i,
    input  logic [counter_bitwidth-1:0] cycle_per_dt_write_i,
    input  logic [counter_bitwidth-1:0] cfg_trans_num_i,
    // data config interface <-> digital
    input  logic dt_cfg_enable_i,
    output logic j_mem_ren_o,
    output logic [j_address_width-1:0] j_raddr_o,
    input  logic [num_spin*bit_data*parallelism-1:0] j_rdata_i,
    output logic h_ren_o,
    input  logic [num_spin*bit_data-1:0] h_rdata_i,
    // data config interface -> analog macro
    output logic [num_spin-1:0] j_one_hot_wwl_o,
    output logic h_wwl_o,
    output logic [num_spin*bit_data-1:0] wbl_o,
    // status
    output logic dt_cfg_idle_o
);
    // Internal signals
    logic [counter_bitwidth-1:0] counter_delay_q, counter_addr_q;
    logic counter_overflow;
    logic dt_cfg_finish;
    logic cfg_busy;
    logic h_ren_n, j_mem_ren_n;
    logic [num_spin*bit_data-1:0] wbl_comb;
    logic [$clog2(parallelism)-1:0] j_mux_sel_nxt, j_mux_sel_q;
    logic cfg_busy_cond;
    logic cfg_idle_cond;
    logic h_wwl_en_cond, j_wwl_en_cond;
    logic h_wwl_idle_cond, j_wwl_idle_cond;
    logic [num_spin-1:0] j_one_hot_wwl_nxt;
    logic wbl_en_cond;
    logic j_mux_sel_cond;
    logic j_mux_sel_idle_cond;

    assign h_ren_o = cfg_busy & (counter_addr_q == h_counter_addr) & (counter_delay_q == 'd0);
    assign j_mem_ren_o = cfg_busy & (counter_addr_q != h_counter_addr) & (counter_delay_q == 'd0);
    assign j_raddr_o = counter_addr_q[j_address_width-1:0];
    assign wbl_comb = j_mem_ren_n ? j_rdata_i :
                      h_ren_n ? h_rdata_i : 'd0;
    assign j_mux_sel_nxt = (j_mux_sel_q == (parallelism-1)) ? 'd0 : j_mux_sel_q + 1'b1;
    assign dt_cfg_idle_o = !cfg_busy;
    assign cfg_busy_cond = en_i & dt_cfg_enable_i;
    assign cfg_idle_cond = !en_i | dt_cfg_finish;
    assign h_wwl_en_cond = en_i & h_ren_n;
    assign h_wwl_idle_cond = !en_i | (h_wwl_o & counter_overflow);
    assign j_one_hot_wwl_nxt = (1'b1 << (j_raddr_o * parallelism + j_mux_sel_q));
    assign j_wwl_en_cond = en_i & j_mem_ren_n;
    assign j_wwl_idle_cond = !en_i | (cfg_busy & counter_overflow);
    assign wbl_en_cond = en_i & (j_mem_ren_n | h_ren_n);
    assign j_mux_sel_cond = en_i & counter_overflow;
    assign j_mux_sel_idle_cond = !en_i | dt_cfg_enable_i;

    `FFLARNC(cfg_busy, 1'b1, cfg_busy_cond, cfg_idle_cond, 1'b0, clk_i, rst_ni)
    `FFL(h_ren_n, h_ren_o, en_i, 1'b0, clk_i, rst_ni)
    `FFL(j_mem_ren_n, j_mem_ren_o, en_i, 1'b0, clk_i, rst_ni)
    `FFLARNC(h_wwl_o, 1'b1, h_wwl_en_cond, h_wwl_idle_cond, 1'b0, clk_i, rst_ni) // last for cycle_per_dt_write_i cycles
    `FFLARNC(j_one_hot_wwl_o, j_one_hot_wwl_nxt, j_wwl_en_cond, j_wwl_idle_cond, 'd0, clk_i, rst_ni) // last for cycle_per_dt_write_i cycles
    `FFL(wbl_o, wbl_comb, wbl_en_cond, 'd0, clk_i, rst_ni) // last for cycle_per_dt_write_i cycles
    `FFLARNC(j_mux_sel_q, j_mux_sel_nxt, j_mux_sel_cond, j_mux_sel_idle_cond, 'd0, clk_i, rst_ni)

    step_counter #(
        .COUNTER_BITWIDTH (counter_bitwidth),
        .PARALLELISM (1)
    ) u_step_counter_dt_write (
        .clk_i (clk_i),
        .rst_ni (rst_ni),
        .en_i (en_i),
        .load_i (cfg_configure_enable_i),
        .d_i (cycle_per_dt_write_i),
        .recount_en_i (dt_cfg_enable_i | counter_overflow),
        .step_en_i (en_i),
        .q_o (counter_delay_q),
        .overflow_o (counter_overflow)
    );

    step_counter #(
        .COUNTER_BITWIDTH (counter_bitwidth),
        .PARALLELISM (1)
    ) u_step_counter_dt_finish (
        .clk_i (clk_i),
        .rst_ni (rst_ni),
        .en_i (en_i),
        .load_i (cfg_configure_enable_i),
        .d_i (cfg_trans_num_i),
        .recount_en_i (dt_cfg_enable_i),
        .step_en_i (en_i & counter_overflow & ((j_mux_sel_q == (parallelism-1)) | (counter_addr_q == h_counter_addr))),
        .q_o (counter_addr_q),
        .overflow_o (dt_cfg_finish)
    );

endmodule
