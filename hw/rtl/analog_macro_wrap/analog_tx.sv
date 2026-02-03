// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Analog TX module, which transmits spin data from analog macro to digital macro.

`include "common_cells/registers.svh"

module analog_tx #(
    parameter integer NUM_SPIN = 256,
    parameter integer SYNCHRONIZER_PIPEDEPTH = 3
)(
    input logic clk_i,
    input logic rst_ni,
    input logic en_i,
    // config interface
    input  logic tx_configure_enable_i,
    input  logic [$clog2(SYNCHRONIZER_PIPEDEPTH)-1:0] synchronizer_pipe_num_i,
    output logic [$clog2(SYNCHRONIZER_PIPEDEPTH)-1:0] synchronizer_pipe_num_reg_o,
    // spin interface: tx <- analog macro
    input  logic [NUM_SPIN-1:0] spin_i,
    // spin interface: rx -> tx
    input  logic analog_macro_cmpt_finish_i, // one-cycle pulse signal
    // spin interface: tx <-> digital
    output logic spin_valid_o,
    input  logic spin_ready_i,
    output logic [NUM_SPIN-1:0] spin_o,
    // status
    output logic analog_tx_idle_o
);
    // Internal signals
    logic [$clog2(SYNCHRONIZER_PIPEDEPTH)-1:0] synchronizer_pipe_num_reg;
    logic spin_handshake;
    logic synchronizer_pipe_num_set_cond;
    logic spin_valid_cond, spin_valid_reset_cond;
    logic spin_valid_reg;
    logic [NUM_SPIN-1:0] spin_out_reg, spin_out_comb;

    assign analog_tx_idle_o = !spin_valid_o;
    assign spin_handshake = spin_valid_o & spin_ready_i;
    assign spin_valid_o = spin_valid_reg;
    assign spin_o = spin_out_reg;
    assign synchronizer_pipe_num_reg_o = synchronizer_pipe_num_reg;

    lagd_synchronizer #(
        .DATAW(NUM_SPIN),
        .SYNCHRONIZER_PIPEDEPTH(SYNCHRONIZER_PIPEDEPTH),
        .WITH_ISOLATION_CELLS(1)
    ) u_synchronizer_spin (
        .clk_i                  (clk_i                                     ),
        .rst_ni                 (rst_ni                                    ),
        .en_i                   (en_i                                      ),
        .data_in_i              (spin_i                                    ),
        .synchronizer_pipe_num_i(synchronizer_pipe_num_reg                 ),
        .synchronization_en_i   (analog_macro_cmpt_finish_i                ),
        .data_out_valid_o       (spin_valid_cond                           ),
        .data_out_o             (spin_out_comb                             )
    );

    assign synchronizer_pipe_num_set_cond = en_i & tx_configure_enable_i;
    assign spin_valid_reset_cond = (!en_i | spin_handshake) & (~spin_valid_cond);

    `FFL(synchronizer_pipe_num_reg, synchronizer_pipe_num_i, synchronizer_pipe_num_set_cond, {($clog2(SYNCHRONIZER_PIPEDEPTH)){1'b1}}, clk_i, rst_ni)
    `FFLARNC(spin_valid_reg, 1'b1, spin_valid_cond, spin_valid_reset_cond, 1'b0, clk_i, rst_ni)
    `FFL(spin_out_reg, spin_out_comb, spin_valid_cond, {(NUM_SPIN){1'b0}}, clk_i, rst_ni)

endmodule
