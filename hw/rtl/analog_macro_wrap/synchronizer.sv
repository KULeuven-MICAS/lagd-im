// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Analog synchronizer module, which samples spin data from analog macro to digital macro.

`include "common_cells/registers.svh"

module synchronizer #(
    parameter integer DATAW = 256,
    parameter integer SYNCHRONIZER_PIPEDEPTH = 3,
    parameter integer WITH_ISOLATION_CELLS = 1
) (
    input  logic clk_i,
    input  logic rst_ni,
    input  logic en_i,
    input  logic [DATAW-1:0] data_in_i,
    input  logic [$clog2(SYNCHRONIZER_PIPEDEPTH)-1:0] synchronizer_pipe_num_i,
    input  logic synchronization_en_i,
    output logic data_out_valid_o,
    output logic [DATAW-1:0] data_out_o
);
    // Internal signals
    logic [DATAW-1:0] data_to_be_synchronized;
    logic [SYNCHRONIZER_PIPEDEPTH:0][DATAW-1:0] data_shift_reg;
    logic [SYNCHRONIZER_PIPEDEPTH-1:0][DATAW-1:0] sel_data;
    logic [SYNCHRONIZER_PIPEDEPTH:0] synchronization_en_reg;
    logic [SYNCHRONIZER_PIPEDEPTH-1:0] sync_en_reg_shifted;
    logic max_sel;

    genvar i;

    // analog isolation cells (AND2 gates)
    generate
        if (WITH_ISOLATION_CELLS == 1) begin
            for (i = 0; i < DATAW; i = i + 1) begin: gen_isolation_and2_cells
                assign data_to_be_synchronized[i] = data_in_i[i] & synchronization_en_i;
            end
        end else begin
            assign data_to_be_synchronized = data_in_i;
        end
    endgenerate

    assign synchronization_en_reg[0] = synchronization_en_i;
    assign data_shift_reg[0] = data_to_be_synchronized;

    // Shift register for synchronizing data
    generate
        for (i = 0; i < SYNCHRONIZER_PIPEDEPTH; i = i + 1) begin : gen_data_shift_reg
            `FFL(synchronization_en_reg[i+1], synchronization_en_reg[i], en_i, '0, clk_i, rst_ni)
            assign sync_en_reg_shifted[i] = synchronization_en_reg[i+1];
            `FFL(data_shift_reg[i+1], data_shift_reg[i], 1'b1, '0, clk_i, rst_ni)
            assign sel_data[i] = data_shift_reg[i+1];
        end
    endgenerate

    assign max_sel = (synchronizer_pipe_num_i < SYNCHRONIZER_PIPEDEPTH);
    assign data_out_valid_o = max_sel ? sync_en_reg_shifted[synchronizer_pipe_num_i] : sync_en_reg_shifted[SYNCHRONIZER_PIPEDEPTH-1];
    assign data_out_o = max_sel ? sel_data[synchronizer_pipe_num_i] : sel_data[SYNCHRONIZER_PIPEDEPTH-1];

endmodule