// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Cycising top module
//
// Brief:
//   Top-level integration of the analog spin macro, energy monitor and flip manager.
//   Coordinates data/control handshakes, host configuration, debug signals and
//   interfaces to weight and flip-icon memories.
//
// Parameters:
//   DATASPIN           - number of spins in a vector
//   BITJ, BITH         - bit widths for weight/threshold related values
//   SCALING_BIT        - width for scaling factor used in energy calc
//   LOCAL_ENERGY_BIT   - local energy accumulator width
//   ENERGY_TOTAL_BIT   - global energy accumulator width
//   SPIN_FIFO_DEPTH    - depth of internal spin FIFOs
//   FLIP_ICON_DEPTH    - size of flip-icon memory
//   PIPES              - pipeline stages in submodules
//
// Ports:
//   clk_i, rst_ni, en_i, flush_i
//       - global clock, active-low reset, module enable and flush
//   config_em_valid_i, config_em_counter_i, config_em_ready_o
//       - configuration interface to energy monitor
//   spin_fifo_configure_valid_i, spin_fifo_configure_i,
//   spin_fifo_configure_push_none_i, spin_fifo_configure_ready_o
//       - host configuration interface to flip manager
//   debug_en_i, em_accum_overflow_o
//       - debug enable and energy-monitor overflow indication
//   cmpt_en_i, cmpt_idle_o, host_readout_i, flip_disable_i, spin_pop_ready_host_i
//       - host control/status and readout handshake
//   spin_pop_valid_o, spin_pop_o
//       - shared host/analog spin output interface
//   spin_analog_valid_i, spin_analog_i, spin_analog_ready_o
//       - interface from analog macro providing spins
//   weight_valid_i, weight_i, hbias_i, hscaling_i, weight_ready_o
//       - interface to weight memory and bias/scaling inputs
//   flip_ren_o, flip_raddr_o, flip_rdata_i
//       - read interface to flip-icon memory


module cycising #(
    parameter int DATASPIN = 256,
    parameter int BITJ = 4,
    parameter int BITH = 4,
    parameter int SCALING_BIT = 5,
    parameter int LOCAL_ENERGY_BIT = 16,
    parameter int ENERGY_TOTAL_BIT = 32,
    parameter int SPIN_FIFO_DEPTH = 2,
    parameter int FLIP_ICON_DEPTH = 1024,
    parameter int PIPES = 1
)(
    input logic clk_i,
    input logic rst_ni,
    input logic en_i,
    input logic flush_i,

    // host config interface -> energy monitor
    input logic config_em_valid_i,
    input logic [SPINIDX_BIT-1:0] config_em_counter_i,
    output logic config_em_ready_o,

    // host config interface -> flip manager
    input logic spin_fifo_configure_valid_i,
    input logic [DATASPIN-1:0] spin_fifo_configure_i,
    input logic spin_fifo_configure_push_none_i,
    output logic spin_fifo_configure_ready_o,

    // host debug interface
    input logic debug_en_i,
    output logic em_accum_overflow_o,

    // other host interface
    input logic cmpt_en_i,
    output logic cmpt_idle_o,
    input logic host_readout_i,
    input logic flip_disable_i,
    input logic spin_pop_ready_host_i,

    // shared interface between host and analog macro
    output logic spin_pop_valid_o,
    output logic [DATASPIN-1:0] spin_pop_o,

    // interface to analog macro
    input logic spin_analog_valid_i,
    input logic [DATASPIN-1:0] spin_analog_i,
    output logic spin_analog_ready_o,

    // interface to weight memory
    input logic weight_valid_i,
    input logic [DATASPIN*BITJ-1:0] weight_i,
    input logic signed [BITH-1:0] hbias_i,
    input logic unsigned [SCALING_BIT-1:0] hscaling_i,
    output logic weight_ready_o,

    // interface to flip icon memory
    output logic flip_ren_o,
    output logic [$clog2(FLIP_ICON_DEPTH)-1:0] flip_raddr_o,
    input logic [DATASPIN-1:0] flip_rdata_i
);

    // Internal signals
    logic energy_fifo_ready;
    logic energy_fifo_valid;
    logic spin_pop_ready;
    logic spin_em_ready;
    logic spin_fm_ready;


    assign spin_pop_ready = spin_pop_ready_host_i ? spin_pop_ready_host_i : spin_analog_ready_o;
    assign spin_analog_ready_o = spin_em_ready & spin_fm_ready;

    // Instantiate energy monitor
    energy_monitor #(
        .BITJ(BITJ),
        .BITH(BITH),
        .DATASPIN(DATASPIN),
        .SCALING_BIT(SCALING_BIT),
        .LOCAL_ENERGY_BIT(LOCAL_ENERGY_BIT),
        .ENERGY_TOTAL_BIT(ENERGY_TOTAL_BIT),
        .PIPES(PIPES)
    ) u_energy_monitor (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .en_i(en_i),
        // .flush_i(flush_i),

        .config_valid_i(config_em_valid_i),
        .config_counter_i(config_em_counter_i),
        .config_ready_o(config_em_ready_o),

        .spin_valid_i(spin_analog_valid_i & spin_fm_ready),
        .spin_i(spin_analog_i),
        .spin_ready_o(spin_em_ready),

        .weight_valid_i(weight_valid_i),
        .weight_i(weight_i),
        .hbias_i(hbias_i),
        .hscaling_i(hscaling_i),
        .weight_ready_o(weight_ready_o),

        .energy_valid_o(energy_fifo_valid),
        .energy_ready_i(energy_fifo_ready),
        .energy_o(energy_fifo_data),

        .debug_en_i(debug_en_i),
        .accum_overflow_o(em_accum_overflow_o)
    );

    // Instantiate flip manager
    flip_manager #(
        .DATASPIN(DATASPIN),
        .SPIN_DEPTH(SPIN_FIFO_DEPTH),
        .ENERGY_TOTAL_BIT(ENERGY_TOTAL_BIT),
        .FLIP_ICON_DEPTH(FLIP_ICON_DEPTH),
        .PIPES(PIPES)
    ) u_flip_manager (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .en_i(en_i),
        .flush_i(flush_i),
        .cmpt_en_i(cmpt_en_i),
        .cmpt_idle_o(cmpt_idle_o),
        .host_readout_i(host_readout_i),
        .flip_disable_i(flip_disable_i),
        .spin_configure_valid_i(spin_fifo_configure_valid_i),
        .spin_configure_i(spin_fifo_configure_i),
        .spin_configure_push_none_i(spin_fifo_configure_push_none_i),
        .spin_configure_ready_o(spin_fifo_configure_ready_o),
        .spin_pop_valid_o(spin_pop_valid_o),
        .spin_pop_o(spin_pop_o),
        .spin_pop_ready_i(spin_pop_ready),
        .spin_valid_i(spin_valid_i & spin_em_ready),
        .spin_i(spin_i),
        .spin_ready_o(spin_fm_ready),
        .energy_valid_i(energy_fifo_valid),
        .energy_ready_o(energy_fifo_ready),
        .energy_i(energy_fifo_data),
        .flip_ren_o(flip_ren_o),
        .flip_raddr_o(flip_raddr_o),
        .flip_rdata_i(flip_rdata_i),
        .debug_cmpt_stop_i(debug_en_i)
    );

endmodule