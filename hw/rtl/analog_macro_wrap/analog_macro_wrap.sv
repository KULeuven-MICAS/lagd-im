// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Analog macro wrapper

`ifndef SYN
`define SYN 0
`endif

module analog_macro_wrap #(
    parameter integer NUM_SPIN = 256,
    parameter integer BITDATA = 4,
    parameter integer PARALLELISM = 4, // min: 1
    parameter integer COUNTER_BITWIDTH = 16,
    parameter integer SYNCHRONIZER_PIPEDEPTH = 3,
    parameter integer SPIN_WBL_OFFSET = 0, // offset of spin wbl in the wbl data from digital macro (must less than BITDATA)
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
    input  logic bypass_data_conversion_i,
    input  logic [NUM_SPIN-1:0] spin_wwl_strobe_i,
    input  logic [NUM_SPIN-1:0] spin_mode_i,
    input  logic [$clog2(SYNCHRONIZER_PIPEDEPTH)-1:0] synchronizer_pipe_num_i,
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
    output logic [NUM_SPIN*BITDATA-1:0] wblb_o,
    output logic [NUM_SPIN*BITDATA-1:0] wbl_floating_o,
    // spin interface: rx <-> digital
    input  logic spin_pop_valid_i,
    output logic spin_pop_ready_o,
    input  logic [NUM_SPIN-1:0] spin_pop_i,
    // spin interface: rx <-> analog macro
    output logic [NUM_SPIN-1:0] spin_wwl_o,
    output logic [NUM_SPIN-1:0] spin_feedback_o,
    // spin interface: tx <- analog macro
    input  logic [NUM_SPIN-1:0] spin_analog_i,
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
    logic [NUM_SPIN-1:0] analog_spin;
    logic [NUM_SPIN*BITDATA-1:0] wbl_spin_expanded;
    logic analog_macro_cmpt_finish;
    genvar i;

    assign spin_tx_handshake = spin_valid_o & spin_ready_i;
    assign wbl_o = dt_cfg_idle_o ? wbl_spin_expanded : wbl_dt;
    assign wblb_o = dt_cfg_idle_o ? '0 : ~wbl_o;
    assign wbl_floating_o = {NUM_SPIN*BITDATA{1'b0}};
    assign analog_spin = analog_macro_cmpt_finish ? spin_analog_i : {NUM_SPIN{1'b0}};

    generate
        for (i = 0; i < NUM_SPIN; i = i + 1) begin : expand_wbl_spin
            assign wbl_spin_expanded[i*BITDATA +: BITDATA] = wbl_spin[i] << SPIN_WBL_OFFSET;
        end
    endgenerate

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
        .bypass_data_conversion_i (bypass_data_conversion_i),
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
        .spin_feedback_o (spin_feedback_o),
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
        // spin interface: tx <- analog macro
        .spin_i (analog_spin),
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
