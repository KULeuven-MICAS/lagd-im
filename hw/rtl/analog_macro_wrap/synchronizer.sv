// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Analog synchronizer module, which samples spin data from analog macro to digital macro.

`ifndef SYN
`define SYN 0
`endif

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
    logic [SYNCHRONIZER_PIPEDEPTH:0] synchronization_en_reg;
    logic [SYNCHRONIZER_PIPEDEPTH:0] synchronizer_shift_cond;
    genvar i, j;

    // analog isolation cells (AND2 gates)
    generate
        if (WITH_ISOLATION_CELLS == 1) begin
            for (i = 0; i < DATAW; i = i + 1) begin: gen_isolation_and2_cells
                if (`SYN == 1) begin: synthesis
                    (* keep = "true", dont_touch = "true" *)
                    AN2OPTDHD16BWP240H8P57PDLVT u_and_inst (
                        .A1(synchronization_en_i),
                        .A2(data_in_i[i]),
                        .Z(data_to_be_synchronized[i])
                    );
                end
                else begin: function_simulation
                    assign data_to_be_synchronized[i] = data_in_i[i] & synchronization_en_i;
                end
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
            assign synchronizer_shift_cond[i] = en_i & (synchronization_en_reg[i]);
            if (`SYN == 1) begin: synthesis
                for (j = 0; j < DATAW; j = j + 1) begin
                    SDFSYNC1QD1BWP240H8P57PDLVT u_sdfsync_inst (
                        .CP(clk_i),
                        .D(data_shift_reg[i][j]),
                        .SE(~synchronizer_shift_cond[i]), // scan enable (D->Q if it is 0)
                        .SI(),
                        .Q(data_shift_reg[i+1][j])
                    );
                end
            end else begin: function_simulation
                `FFL(data_shift_reg[i+1], data_shift_reg[i], synchronizer_shift_cond[i], '0, clk_i, rst_ni)
            end
        end
    endgenerate

    always_comb begin
        if (synchronizer_pipe_num_i <= SYNCHRONIZER_PIPEDEPTH) begin
            data_out_valid_o = synchronization_en_reg[synchronizer_pipe_num_i];
            data_out_o = data_shift_reg[synchronizer_pipe_num_i];
        end else begin
            data_out_valid_o = synchronization_en_reg[0];
            data_out_o = data_shift_reg[0];
        end
    end

endmodule