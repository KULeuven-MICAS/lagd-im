// Copyright 2024 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author:
//  Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>
//
// Module description:
// Pipeline stage(s) with configurable number of registers and backpressure
//
// The module has a ready/valid interface, where the ready signal is used to indicate that the
// module is ready to accept new data, and the valid signal is used to indicate that the module
//
// Parameters:
// - DATAW: number of bits of the input data
// - PIPES: number of pipeline stages, 0 means pass-through

//`include "assertions.svh"
`include "registers.svh"

module bp_pipe #(
    parameter int DATAW = 8,
    parameter int PIPES = 0
) (
    input logic clk_i,
    input logic rst_ni,

    input logic [DATAW-1:0] data_i,
    output logic [DATAW-1:0] data_o,

    input logic valid_i,
    output logic valid_o,

    input logic ready_i,
    output logic ready_o
);

    generate
        if (PIPES == 0) begin : g_passthrough
            assign data_o = data_i;
            assign valid_o = valid_i;
            assign ready_o = ready_i;
        end else begin : g_pipe
            logic [PIPES:0][DATAW-1:0] pipe_data;
            logic [PIPES:0] pipe_valid;
            logic [PIPES:0] pipe_ready;
            logic [PIPES-1:0] pipe_load;

            assign pipe_data[0] = data_i;
            assign pipe_valid[0] = valid_i;
            assign pipe_ready[PIPES] = ready_i;

            for (genvar i = 0; i < PIPES; i++) begin : g_pipe_stage
                assign pipe_load[i] = (pipe_valid[i] && ~pipe_valid[i+1])    //pipe is free
                                    || (pipe_ready[i+1] && pipe_valid[i+1]); //pipe is sampled
                `FFL(pipe_data[i+1], pipe_data[i], pipe_load[i], '0, clk_i, rst_ni);
                `FFL(pipe_valid[i+1], pipe_valid[i], pipe_load[i], '0, clk_i, rst_ni);
                assign pipe_ready[i] = pipe_ready[i+1] || ~pipe_valid[i+1];
            end

            assign data_o = pipe_data[PIPES];
            assign ready_o = pipe_ready[0];
            assign valid_o = pipe_valid[PIPES];
        end
    endgenerate
endmodule
