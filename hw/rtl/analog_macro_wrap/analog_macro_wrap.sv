// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Analog macro wrapper

module analog_macro_wrap #(
    parameter integer num_spin = 256,
    parameter integer bit_data = 4,
    parameter integer parallelism = 1, // min: 1
    parameter integer counter_bitwidth = 16,
    parameter integer synchronizer_pipe_depth = 3,
    parameter integer j_address_width = $clog2(num_spin / parallelism)
)(
    input logic clk_i,
    input logic rst_ni,
    input logic en_i,
    // config interface
    input  logic analog_wrap_configure_enable_i,
    input  logic [counter_bitwidth-1:0] cfg_trans_num_i,
    input  logic [counter_bitwidth-1:0] cycle_per_dt_write_i,
    input  logic [counter_bitwidth-1:0] cycle_per_spin_write_i,
    input  logic [counter_bitwidth-1:0] cycle_per_spin_compute_i,
    input  logic [num_spin-1:0] spin_wwl_strobe_i,
    input  logic [num_spin-1:0] spin_mode_i,
    input  logic [$clog2(synchronizer_pipe_depth)-1:0] synchronizer_pipe_num_i,
    input  logic synchronizer_mode_i,
    // data config interface <-> digital
    input  logic dt_cfg_enable_i,
    output logic j_mem_ren_o,
    output logic [j_address_width-1:0] j_raddr_o,
    input  logic [num_spin*bit_data*parallelism-1:0] j_rdata_i,
    output logic h_ren_o,
    input  logic [num_spin*bit_data-1:0] h_rdata_i,
    output logic sfc_ren_o,
    input  logic [num_spin*bit_data-1:0] sfc_rdata_i,
    // data config interface <-> analog macro
    output logic [num_spin-1:0] j_one_hot_wwl_o,
    output logic h_wwl_o,
    output logic sfc_wwl_o,
    output logic [num_spin*bit_data-1:0] wbl_o,
    // spin interface: rx <-> digital
    input  logic spin_pop_valid_i,
    output logic spin_pop_ready_o,
    input  logic [num_spin-1:0] spin_pop_i,
    // spin interface: tx <-> analog macro
    output logic [num_spin-1:0] spin_wwl_o,
    output logic [num_spin-1:0] spin_compute_en_o,
    // spin interface: rx <-> analog macro
    input  logic [num_spin-1:0] spin_i,
    // spin interface: tx <-> digital
    output logic spin_valid_o,
    input  logic spin_ready_i,
    output logic [num_spin-1:0] spin_o,
    // status
    output logic dt_cfg_idle_o,
    output logic analog_rx_idle_o,
    output logic analog_tx_idle_o
);

    // Internal signals
    logic spin_tx_handshake;
    logic [num_spin*bit_data-1:0] wbl_dt;
    logic [num_spin-1:0] wbl_spin;
    logic analog_macro_cmpt_finish;

    assign spin_tx_handshake = spin_valid_o & spin_ready_i;
    assign wbl_o = dt_cfg_idle_o ? {{(num_spin*bit_data-num_spin){1'b0}}, wbl_spin} : wbl_dt;

    analog_cfg #(
        .num_spin (num_spin),
        .bit_data (bit_data),
        .counter_bitwidth (counter_bitwidth),
        .parallelism (parallelism)
    ) u_analog_cfg (
        .clk_i (clk_i),
        .rst_ni (rst_ni),
        .en_i (en_i),
        // config interface
        .cfg_configure_enable_i (analog_wrap_configure_enable_i),
        .cycle_per_dt_write_i (cycle_per_dt_write_i),
        .cfg_trans_num_i (cfg_trans_num_i),
        // data config interface <-> digital
        .dt_cfg_enable_i (dt_cfg_enable_i),
        .j_mem_ren_o (j_mem_ren_o),
        .j_raddr_o (j_raddr_o),
        .j_rdata_i (j_rdata_i),
        .h_ren_o (h_ren_o),
        .h_rdata_i (h_rdata_i),
        .sfc_ren_o (sfc_ren_o),
        .sfc_rdata_i (sfc_rdata_i),
        // data config interface -> analog macro
        .j_one_hot_wwl_o (j_one_hot_wwl_o),
        .h_wwl_o (h_wwl_o),
        .sfc_wwl_o (sfc_wwl_o),
        .wbl_o (wbl_dt),
        // status
        .dt_cfg_idle_o (dt_cfg_idle_o)
    );

    analog_rx #(
        .num_spin (num_spin),
        .counter_bitwidth (counter_bitwidth)
    ) u_analog_rx (
        .clk_i (clk_i),
        .rst_ni (rst_ni),
        .en_i (en_i),
        // config interface
        .rx_configure_enable_i (analog_wrap_configure_enable_i),
        .cycle_per_spin_write_i (cycle_per_spin_write_i),
        .spin_wwl_strobe_i (spin_wwl_strobe_i),
        .spin_mode_i (spin_mode_i),
        .cycle_per_spin_compute_i (cycle_per_spin_compute_i),
        // spin interface: rx <-> digital
        .spin_pop_valid_i (spin_pop_valid_i),
        .spin_pop_ready_o (spin_pop_ready_o),
        .spin_pop_i (spin_pop_i),
        .analog_macro_idle_i (spin_tx_handshake),
        // spin interface: rx -> analog macro
        .spin_wwl_o (spin_wwl_o),
        .spin_compute_en_o (spin_compute_en_o),
        .wbl_o(wbl_spin),
        // status
        .analog_rx_idle_o (analog_rx_idle_o),
        .analog_macro_cmpt_finish_o (analog_macro_cmpt_finish)
    );

    analog_tx #(
        .num_spin (num_spin),
        .counter_bitwidth (counter_bitwidth),
        .synchronizer_pipe_depth (synchronizer_pipe_depth)
    ) u_analog_tx (
        .clk_i (clk_i),
        .rst_ni (rst_ni),
        .en_i (en_i),
        // config interface
        .tx_configure_enable_i (analog_wrap_configure_enable_i),
        .synchronizer_pipe_num_i (synchronizer_pipe_num_i),
        .synchronizer_mode_i (synchronizer_mode_i),
        // spin interface: tx <- analog macro
        .spin_i (spin_i),
        // spin interface: rx -> tx
        .analog_macro_cmpt_finish_i (analog_macro_cmpt_finish),
        // spin interface: tx <-> digital
        .spin_valid_o (spin_valid_o),
        .spin_ready_i (spin_ready_i),
        .spin_o (spin_o),
        // status
        .analog_tx_idle_o (analog_tx_idle_o)
    );

endmodule
