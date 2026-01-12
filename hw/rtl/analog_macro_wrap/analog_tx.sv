// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Analog TX module, which transmits spin data from analog macro to digital macro.

`ifndef SYN
`define SYN 0
`endif

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
    // spin interface: tx <- analog macro
    input  logic [NUM_SPIN-1:0] spin_i,
    // spin interface: rx -> tx
    input  logic analog_macro_cmpt_finish_i,
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
    logic analog_macro_cmpt_finish_pulse;
    logic [NUM_SPIN-1:0] spin_to_be_synchronized;
    logic [SYNCHRONIZER_PIPEDEPTH:0][NUM_SPIN-1:0] spin_shift_reg;
    logic [SYNCHRONIZER_PIPEDEPTH:0] analog_macro_cmpt_finish_pulse_reg, synchronizer_shift_cond;
    logic synchronizer_pip_num_reset_cond;
    logic synchronizer_mode_reset_cond;
    logic spin_valid_cond, spin_valid_reset_cond;
    genvar i;

    assign analog_tx_idle_o = !spin_valid_o;
    assign spin_handshake = spin_valid_o & spin_ready_i;
    assign analog_macro_cmpt_finish_pulse = analog_macro_cmpt_finish_i; // one-cycle pulse signal
    assign spin_shift_reg[0] = spin_to_be_synchronized;
    assign analog_macro_cmpt_finish_pulse_reg[0] = analog_macro_cmpt_finish_pulse;

    generate
        for (i = 0; i < NUM_SPIN; i = i + 1) begin: gen_isolation_and2_cells
            if (`SYN == 1) begin: synthesis
                AN2OPTDHD16BWP240H8P57PDLVT u_and_inst (
                    .A1(analog_macro_cmpt_finish_pulse),
                    .A2(spin_i[i]),
                    .Z(spin_to_be_synchronized[i])
                );
            end
            else begin: function_simulation
                assign spin_to_be_synchronized[i] = spin_i[i] & analog_macro_cmpt_finish_pulse;
            end
        end
    endgenerate

    always_comb begin
        if (synchronizer_pipe_num_reg <= SYNCHRONIZER_PIPEDEPTH)
            spin_o = spin_shift_reg[synchronizer_pipe_num_reg];
        else
            spin_o = spin_shift_reg[0];
    end

    // Shift register for synchronizing spins from analog macro
    generate
        for (i = 0; i < SYNCHRONIZER_PIPEDEPTH; i = i + 1) begin : gen_spin_shift_reg
            `FFL(analog_macro_cmpt_finish_pulse_reg[i+1], analog_macro_cmpt_finish_pulse_reg[i], en_i, '0, clk_i, rst_ni)
            assign synchronizer_shift_cond[i] = en_i & (analog_macro_cmpt_finish_pulse_reg[i]);
            `FFL(spin_shift_reg[i+1], spin_shift_reg[i], synchronizer_shift_cond[i], '0, clk_i, rst_ni)
        end
    endgenerate

    assign synchronizer_pip_num_reset_cond = en_i & tx_configure_enable_i;
    assign synchronizer_mode_reset_cond = en_i & tx_configure_enable_i;
    assign spin_valid_cond = en_i & analog_macro_cmpt_finish_pulse_reg[synchronizer_pipe_num_reg-1'b1];
    assign spin_valid_reset_cond = !en_i | spin_handshake;

    `FFL(synchronizer_pipe_num_reg, synchronizer_pipe_num_i, synchronizer_pip_num_reset_cond, {($clog2(SYNCHRONIZER_PIPEDEPTH)){1'b1}}, clk_i, rst_ni)
    `FFLARNC(spin_valid_o, 1'b1, spin_valid_cond, spin_valid_reset_cond, 1'b0, clk_i, rst_ni)

endmodule
