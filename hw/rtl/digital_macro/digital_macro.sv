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
    parameter integer BITJ = 4,
    parameter integer BITH = 4,
    parameter integer NUM_SPIN = 256,
    parameter integer SCALING_BIT = 4,
    parameter integer PARALLELISM = 4,
    parameter integer ENERGY_TOTAL_BIT = 32,
    parameter integer LITTLE_ENDIAN = `False,
    parameter integer PIPESINTF = 1,
    parameter integer PIPESMID = 1,
    // parameters: flip manager
    parameter integer SPIN_DEPTH = 2,
    parameter integer FLIP_ICON_DEPTH = 1024,
    // parameters: analog wrap
    parameter integer COUNTER_BITWIDTH = 16,
    parameter integer SYNCHRONIZER_PIPEDEPTH = 3,
    // derived parameters
    parameter integer SPIN_IDX_BIT = $clog2(NUM_SPIN),
    parameter integer FLIP_ICON_ADDR_DEPTH = $clog2(FLIP_ICON_DEPTH),
    parameter integer DATA_J_BIT = NUM_SPIN * BITJ * PARALLELISM,
    parameter integer DATA_H_BIT = BITH * NUM_SPIN
)(
    input  logic clk_i,
    input  logic rst_ni,
    input  logic en_i,
    // config interface: ctrl
    input  logic config_valid_em_i,
    input  logic config_valid_fm_i,
    input  logic config_valid_aw_i,
    // config interface: energy monitor
    input  logic [SPIN_IDX_BIT-1:0] config_counter_i,
    // config interface: flip manager
    input  logic [NUM_SPIN-1:0] config_spin_initial_i,
    input  logic config_spin_initial_skip_i,
    // config interface: analog wrap
    input  logic [COUNTER_BITWIDTH-1:0] cfg_trans_num_i,
    input  logic [COUNTER_BITWIDTH-1:0] cycle_per_dt_write_i,
    input  logic [COUNTER_BITWIDTH-1:0] cycle_per_spin_write_i,
    input  logic [COUNTER_BITWIDTH-1:0] cycle_per_spin_compute_i,
    input  logic [NUM_SPIN-1:0] spin_wwl_strobe_i,
    input  logic [NUM_SPIN-1:0] spin_mode_i,
    input  logic [$clog2(SYNCHRONIZER_PIPEDEPTH)-1:0] synchronizer_pipe_num_i,
    input  logic synchronizer_mode_i,
    // data loading interface
    input  logic dt_cfg_enable_i, // load enable
    output logic j_mem_ren_o,
    output logic [$clog2(NUM_SPIN / PARALLELISM)-1:0] j_raddr_o,
    input  logic [DATA_J_BIT-1:0] j_rdata_i,
    output logic h_ren_o,
    input  logic [DATA_H_BIT-1:0] h_rdata_i,
    output logic dt_cfg_idle_o,
    // runtime interface: flip manager
    input  logic flush_i,
    input  logic en_comparison_i,
    input  logic cmpt_en_i,
    output logic cmpt_idle_o,
    input  logic host_readout_i,
    output logic flip_ren_o,
    output logic [FLIP_ICON_ADDR_DEPTH+1-1:0] flip_raddr_o,
    input  logic [FLIP_ICON_ADDR_DEPTH+1-1:0] icon_last_raddr_plus_one_i,
    input  logic [NUM_SPIN-1:0] flip_rdata_i,
    input  logic flip_disable_i,
    // runtime interface: energy monitor
    input  logic weight_valid_i,
    output logic [$clog2(NUM_SPIN / PARALLELISM)-1:0] weight_raddr_o,
    input  logic [DATA_J_BIT-1:0] weight_i,
    input  logic [DATA_H_BIT-1:0] hbias_i,
    input  logic [SCALING_BIT-1:0] hscaling_i,
    output logic weight_ready_o,
    // runtime interface: analog wrap
    // analog interface: config
    output logic [NUM_SPIN-1:0] j_one_hot_wwl_o,
    output logic h_wwl_o,
    output logic [NUM_SPIN*BITJ-1:0] wbl_o,
    // analog interface: runtime
    output logic [NUM_SPIN-1:0] spin_wwl_o,
    output logic [NUM_SPIN-1:0] spin_compute_en_o,
    input  logic [NUM_SPIN-1:0] analog_spin_i
);
    // Internal signals
    logic analog_spin_valid;
    logic [NUM_SPIN-1:0] analog_spin;
    logic energy_monitor_spin_ready;
    logic energy_monitor_energy_valid;
    logic weight_valid_em;
    logic weight_ready_em;
    logic [ENERGY_TOTAL_BIT-1:0] energy_monitor_output;
    logic flip_manager_spin_ready;
    logic flip_manager_energy_ready;
    logic spin_new_valid;
    logic [NUM_SPIN-1:0] spin_new;
    logic analog_ready;
    logic [SPIN_IDX_BIT-1:0] counter_spin;
    logic [SCALING_BIT*PARALLELISM-1:0] hscaling_expanded;
    logic [BITH*PARALLELISM-1:0] hbias_sliced;

    assign hscaling_expanded = {PARALLELISM{hscaling_i}};
    assign hbias_sliced = hbias_i[counter_spin * BITH +: BITH * PARALLELISM];

    assign weight_ready_o = weight_ready_em;
    assign weight_valid_em = weight_valid_i;
    assign weight_raddr_o = counter_spin / PARALLELISM;

    energy_monitor #(
        .BITJ (BITJ),
        .BITH (BITH),
        .NUM_SPIN (NUM_SPIN),
        .SCALING_BIT (SCALING_BIT),
        .PARALLELISM (PARALLELISM),
        .ENERGY_TOTAL_BIT (ENERGY_TOTAL_BIT),
        .LITTLE_ENDIAN (LITTLE_ENDIAN),
        .PIPESINTF (PIPESINTF),
        .PIPESMID (PIPESMID)
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
        .NUM_SPIN (NUM_SPIN),
        .SPIN_DEPTH (SPIN_DEPTH),
        .ENERGY_TOTAL_BIT (ENERGY_TOTAL_BIT),
        .FLIP_ICON_DEPTH (FLIP_ICON_DEPTH)
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
        .NUM_SPIN (NUM_SPIN),
        .BITDATA (BITJ),
        .PARALLELISM (PARALLELISM),
        .COUNTER_BITWIDTH (COUNTER_BITWIDTH),
        .SYNCHRONIZER_PIPEDEPTH (SYNCHRONIZER_PIPEDEPTH)
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
        .dt_cfg_idle_o (dt_cfg_idle_o),
        .analog_rx_idle_o (),
        .analog_tx_idle_o ()
    );

endmodule
