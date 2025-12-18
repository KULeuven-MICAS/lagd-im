// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Digital compute macro

`include "../include/lagd_define.svh"
`include "common_cells/registers.svh"

`define True 1'b1
`define False 1'b0

module digital_macro #(
    // parameters: energy monitor
    parameter integer bit_j = 4,
    parameter integer bit_h = 4,
    parameter integer num_spin = 256,
    parameter integer scaling_bit = 4,
    parameter integer parallelism = 4,
    parameter integer energy_total_bit = 32,
    parameter integer little_endian = `False,
    parameter integer pipesintf = 1,
    parameter integer pipesmid = 1,
    // parameters: flip manager
    parameter integer spin_depth = 2,
    parameter integer flip_icon_depth = 1024,
    // parameters: analog wrap
    parameter integer counter_bitwidth = 16,
    parameter integer synchronizer_pipe_depth = 3,
    // derived parameters
    parameter integer spin_idx_bit = $clog2(num_spin),
    parameter integer flip_icon_addr_depth = $clog2(flip_icon_depth),
    parameter integer data_j_bit = num_spin * bit_j * parallelism,
    parameter integer data_h_bit = bit_h * num_spin
)(
    input  logic clk_i,
    input  logic rst_ni,
    input  logic en_i,
    // config interface: ctrl
    input  logic config_valid_em_i,
    input  logic config_valid_fm_i,
    input  logic config_valid_aw_i,
    // config interface: energy monitor
    input  logic [spin_idx_bit-1:0] config_counter_i,
    // config interface: flip manager
    input  logic [num_spin-1:0] config_spin_initial_i,
    input  logic config_spin_initial_skip_i,
    // config interface: analog wrap
    input  logic [counter_bitwidth-1:0] cfg_trans_num_i,
    input  logic [counter_bitwidth-1:0] cycle_per_dt_write_i,
    input  logic [counter_bitwidth-1:0] cycle_per_spin_write_i,
    input  logic [counter_bitwidth-1:0] cycle_per_spin_compute_i,
    input  logic [num_spin-1:0] spin_wwl_strobe_i,
    input  logic [num_spin-1:0] spin_mode_i,
    input  logic [$clog2(synchronizer_pipe_depth)-1:0] synchronizer_pipe_num_i,
    input  logic synchronizer_mode_i,
    // data loading interface
    input  logic dt_cfg_enable_i, // load enable
    output logic j_mem_ren_o,
    output logic [$clog2(num_spin / parallelism)-1:0] j_raddr_o,
    input  logic [data_j_bit-1:0] j_rdata_i,
    output logic h_ren_o,
    input  logic [data_h_bit-1:0] h_rdata_i,
    // runtime interface: flip manager
    input  logic flush_i,
    input  logic en_comparison_i,
    input  logic cmpt_en_i,
    output logic cmpt_idle_o,
    input  logic host_readout_i,
    output logic flip_ren_o,
    output logic [flip_icon_addr_depth+1-1:0] flip_raddr_o,
    input  logic [flip_icon_addr_depth+1-1:0] icon_last_raddr_plus_one_i,
    input  logic [num_spin-1:0] flip_rdata_i,
    input  logic flip_disable_i,
    // runtime interface: energy monitor
    output logic weight_ren_o,
    output logic [$clog2(num_spin / parallelism)-1:0] weight_raddr_o,
    input  logic [data_j_bit-1:0] weight_i,
    input  logic [data_h_bit-1:0] hbias_i,
    input  logic [scaling_bit-1:0] hscaling_i,
    // runtime interface: analog wrap
    // analog interface: config
    output logic [num_spin-1:0] j_one_hot_wwl_o,
    output logic h_wwl_o,
    output logic [num_spin*bit_j-1:0] wbl_o,
    // analog interface: runtime
    output logic [num_spin-1:0] spin_wwl_o,
    output logic [num_spin-1:0] spin_compute_en_o,
    input  logic [num_spin-1:0] analog_spin_i
);
    // Internal signals
    logic analog_spin_valid;
    logic [num_spin-1:0] analog_spin;
    logic energy_monitor_spin_ready;
    logic energy_monitor_energy_valid;
    logic weight_valid_em;
    logic weight_ready_em;
    logic [energy_total_bit-1:0] energy_monitor_output;
    logic flip_manager_spin_ready;
    logic flip_manager_energy_ready;
    logic spin_new_valid;
    logic [num_spin-1:0] spin_new;
    logic analog_ready;
    logic [spin_idx_bit-1:0] counter_spin;
    logic [scaling_bit*parallelism-1:0] hscaling_expanded;
    logic [bit_h*parallelism-1:0] hbias_sliced;

    assign hscaling_expanded = {parallelism{hscaling_i}};
    assign hbias_sliced = hbias_i[counter_spin * bit_h +: bit_h * parallelism];

    assign weight_ren_o = en_i & (cmpt_en_i | weight_ready_em);
    assign weight_raddr_o = counter_spin / parallelism;
    `FFL(weight_valid_em, weight_ren_o, en_i, 1'b0, clk_i, rst_ni)

    energy_monitor #(
        .BITJ (bit_j),
        .BITH (bit_h),
        .DATASPIN (num_spin),
        .SCALING_BIT (scaling_bit),
        .PARALLELISM (parallelism),
        .ENERGY_TOTAL_BIT (energy_total_bit),
        .LITTLE_ENDIAN (little_endian),
        .PIPESINTF (pipesintf),
        .PIPESMID (pipesmid)
    ) u_energy_monitor (
        .clk_i (clk_i),
        .rst_ni (rst_ni),
        .en_i (en_i),
        .config_valid_i (config_valid_em_i),
        .config_counter_i (config_counter_i),
        .config_ready_o (),
        .spin_valid_i (analog_spin_valid & flip_manager_spin_ready),
        .spin_i (analog_spin),
        .spin_ready_o (energy_monitor_spin_ready),
        .weight_valid_i (weight_valid_em),
        .weight_i (weight_i),
        .hbias_i (hbias_sliced),
        .hscaling_i (hscaling_expanded),
        .weight_ready_o (weight_ready_em),
        .counter_spin_o (counter_spin),
        .energy_valid_o (energy_monitor_energy_valid),
        .energy_ready_i (flip_manager_energy_ready),
        .energy_o (energy_monitor_output)
    );

    flip_manager #(
        .DATASPIN (num_spin),
        .SPIN_DEPTH (spin_depth),
        .ENERGY_TOTAL_BIT (energy_total_bit),
        .FLIP_ICON_DEPTH (flip_icon_depth)
    ) u_flip_manager (
        .clk_i (clk_i),
        .rst_ni (rst_ni),
        .en_i (en_i),
        .flush_i (flush_i),
        .en_comparison_i (en_comparison_i),
        .cmpt_en_i (cmpt_en_i),
        .cmpt_idle_o (cmpt_idle_o),
        .host_readout_i (host_readout_i),
        .spin_configure_valid_i (config_valid_fm_i),
        .spin_configure_i (config_spin_initial_i),
        .spin_configure_push_none_i (config_spin_initial_skip_i),
        .spin_configure_ready_o (),
        .spin_pop_valid_o (spin_new_valid),
        .spin_pop_o (spin_new),
        .spin_pop_ready_i (analog_ready),
        .spin_valid_i (analog_spin_valid & energy_monitor_spin_ready),
        .spin_i (analog_spin),
        .spin_ready_o (flip_manager_spin_ready),
        .energy_valid_i (energy_monitor_energy_valid),
        .energy_ready_o (flip_manager_energy_ready),
        .energy_i (energy_monitor_output),
        .flip_ren_o (flip_ren_o),
        .flip_raddr_o (flip_raddr_o),
        .icon_last_raddr_plus_one_i (icon_last_raddr_plus_one_i),
        .flip_rdata_i (flip_rdata_i),
        .flip_disable_i (flip_disable_i)
    );

    analog_macro_wrap #(
        .num_spin (num_spin),
        .bit_data (bit_j),
        .parallelism (parallelism),
        .counter_bitwidth (counter_bitwidth),
        .synchronizer_pipe_depth (synchronizer_pipe_depth)
    ) u_analog_wrap (
        .clk_i (clk_i),
        .rst_ni (rst_ni),
        .en_i (en_i),
        .analog_wrap_configure_enable_i (config_valid_aw_i),
        .cfg_trans_num_i (cfg_trans_num_i),
        .cycle_per_dt_write_i (cycle_per_dt_write_i),
        .cycle_per_spin_write_i (cycle_per_spin_write_i),
        .cycle_per_spin_compute_i (cycle_per_spin_compute_i),
        .spin_wwl_strobe_i (spin_wwl_strobe_i),
        .spin_mode_i (spin_mode_i),
        .synchronizer_pipe_num_i (synchronizer_pipe_num_i),
        .synchronizer_mode_i (synchronizer_mode_i),
        .dt_cfg_enable_i (dt_cfg_enable_i),
        .j_mem_ren_o (j_mem_ren_o),
        .j_raddr_o (j_raddr_o),
        .j_rdata_i (j_rdata_i),
        .h_ren_o (h_ren_o),
        .h_rdata_i (h_rdata_i),
        .j_one_hot_wwl_o (j_one_hot_wwl_o),
        .h_wwl_o (h_wwl_o),
        .wbl_o (wbl_o),
        .spin_pop_valid_i (spin_new_valid),
        .spin_pop_ready_o (analog_ready),
        .spin_pop_i (spin_new),
        .spin_wwl_o (spin_wwl_o),
        .spin_compute_en_o (spin_compute_en_o),
        .spin_i (analog_spin_i),
        .spin_valid_o (analog_spin_valid),
        .spin_ready_i (energy_monitor_spin_ready & flip_manager_spin_ready),
        .spin_o (analog_spin),
        .dt_cfg_idle_o (),
        .analog_rx_idle_o (),
        .analog_tx_idle_o ()
    );

endmodule
