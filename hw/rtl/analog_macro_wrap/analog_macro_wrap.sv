// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Analog macro wrapper

module analog_macro_wrap #(
    parameter integer NUM_SPIN = 256,
    parameter integer BITDATA = 4,
    parameter integer PARALLELISM = 1, // min: 1
    parameter integer COUNTER_BITWIDTH = 16,
    parameter integer SYNCHRONIZER_PIPEDEPTH = 3,
    parameter integer J_ADDRESS_WIDTH = $clog2(NUM_SPIN / PARALLELISM)
)(
    input logic clk_i,
    input logic rst_ni,
    input logic en_i,
    // config interface
    input  logic analog_wrap_configure_enable_i,
    input  logic [COUNTER_BITWIDTH-1:0] cfg_trans_num_i,
    input  logic [COUNTER_BITWIDTH-1:0] cycle_per_wwl_high_i,
    input  logic [COUNTER_BITWIDTH-1:0] cycle_per_wwl_low_i,
    input  logic [COUNTER_BITWIDTH-1:0] cycle_per_spin_write_i,
    input  logic [COUNTER_BITWIDTH-1:0] cycle_per_spin_compute_i,
    input  logic [NUM_SPIN-1:0] spin_wwl_strobe_i,
    input  logic [NUM_SPIN-1:0] spin_mode_i,
    input  logic [$clog2(SYNCHRONIZER_PIPEDEPTH)-1:0] synchronizer_pipe_num_i,
    input  logic synchronizer_mode_i,
    // data config interface <-> digital
    input  logic dt_cfg_enable_i,
    output logic j_mem_ren_o,
    output logic [J_ADDRESS_WIDTH-1:0] j_raddr_o,
    input  logic [NUM_SPIN*BITDATA*PARALLELISM-1:0] j_rdata_i,
    output logic h_ren_o,
    input  logic [NUM_SPIN*BITDATA-1:0] h_rdata_i,
    // data config interface <-> analog macro
    output logic [NUM_SPIN-1:0] j_one_hot_wwl_o,
    output logic h_wwl_o,
    output logic [NUM_SPIN*BITDATA-1:0] wbl_o,
    // spin interface: rx <-> digital
    input  logic spin_pop_valid_i,
    output logic spin_pop_ready_o,
    input  logic [NUM_SPIN-1:0] spin_pop_i,
    // spin interface: tx <-> analog macro
    output logic [NUM_SPIN-1:0] spin_wwl_o,
    output logic [NUM_SPIN-1:0] spin_compute_en_o,
    // spin interface: rx <-> analog macro
    input  logic [NUM_SPIN-1:0] spin_i,
    // spin interface: tx <-> digital
    output logic spin_valid_o,
    input  logic spin_ready_i,
    output logic [NUM_SPIN-1:0] spin_o,
    // status
    output logic dt_cfg_idle_o,
    output logic analog_rx_idle_o,
    output logic analog_tx_idle_o
);

    // Internal signals
    logic spin_tx_handshake;
    logic [NUM_SPIN*BITDATA-1:0] wbl_dt;
    logic [NUM_SPIN-1:0] wbl_spin;
    logic analog_macro_cmpt_finish;

    assign spin_tx_handshake = spin_valid_o & spin_ready_i;
    assign wbl_o = dt_cfg_idle_o ? {{(NUM_SPIN*BITDATA-NUM_SPIN){1'b0}}, wbl_spin} : wbl_dt;

    analog_cfg #(
        .NUM_SPIN (NUM_SPIN),
        .BITDATA (BITDATA),
        .COUNTER_BITWIDTH (COUNTER_BITWIDTH),
        .PARALLELISM (PARALLELISM)
    ) u_analog_cfg (
        .clk_i (clk_i),
        .rst_ni (rst_ni),
        .en_i (en_i),
        // config interface
        .cfg_configure_enable_i (analog_wrap_configure_enable_i),
        .cycle_per_wwl_high_i (cycle_per_wwl_high_i),
        .cycle_per_wwl_low_i (cycle_per_wwl_low_i),
        .cfg_trans_num_i (cfg_trans_num_i),
        // data config interface <-> digital
        .dt_cfg_enable_i (dt_cfg_enable_i),
        .j_mem_ren_o (j_mem_ren_o),
        .j_raddr_o (j_raddr_o),
        .j_rdata_i (j_rdata_i),
        .h_ren_o (h_ren_o),
        .h_rdata_i (h_rdata_i),
        // data config interface -> analog macro
        .j_one_hot_wwl_o (j_one_hot_wwl_o),
        .h_wwl_o (h_wwl_o),
        .wbl_o (wbl_dt),
        // status
        .dt_cfg_idle_o (dt_cfg_idle_o)
    );

    analog_rx #(
        .NUM_SPIN (NUM_SPIN),
        .COUNTER_BITWIDTH (COUNTER_BITWIDTH)
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
        .NUM_SPIN (NUM_SPIN),
        .SYNCHRONIZER_PIPEDEPTH (SYNCHRONIZER_PIPEDEPTH)
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
