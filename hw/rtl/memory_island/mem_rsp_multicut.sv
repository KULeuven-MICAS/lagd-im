// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

// Module: mem_rsp_multicut

// Description:
//      Inserts a configurable number of spill register stages into the response path 
//      of a memory interface.

// Parameters:
//      DataWidth: Data width of memory interface.
//      NumCuts: Number of pipeline stages (spill registers) to insert (0 = bypass).
//      mem_rsp_t: Memory response typedef (must provide p.valid and p.data).

// Ports:
//      clk_i: Clock.
//      rst_ni: Active-low reset.
//      rsp_i: Memory response input (from downstream memory controller).
//      rsp_o: Memory response output (to upstream requestor).
//      ready_i: Ready signal from upstream (backpressure, indicates consumer can accept data).
//      ready_o: Ready signal to downstream (indicates this stage can accept new response).

module mem_rsp_multicut #(
    /// Data Width
    parameter int unsigned DataWidth = 0,
    /// Number of cuts
    parameter int unsigned NumCuts = 0,
    parameter type mem_rsp_t = logic
) (
    input logic clk_i,
    input logic rst_ni,

    input mem_rsp_t rsp_i,
    output mem_rsp_t rsp_o,

    input logic ready_i,
    output logic ready_o
);

    if (NumCuts == 0) begin : gen_passthrough
        assign rsp_o.p = rsp_i.p;
    end else begin : gen_cuts
        logic [NumCuts:0][DataWidth-1:0] data;
        logic [NumCuts:0] valid, ready;

        assign data[0] = rsp_i.p.data;
        assign valid[0] = rsp_i.p.valid;
        assign ready_o = ready[0];
        assign ready[NumCuts] = ready_i;
        assign rsp_o.p.valid = valid[NumCuts];
        assign rsp_o.p.data = data[NumCuts];

        for (genvar i = 0; i < NumCuts; i++) begin : gen_cut
            spill_register #(
                .T(logic [DataWidth-1:0]),
                .Bypass(1'b0)
            ) i_cut (
                .clk_i(clk_i),
                .rst_ni(rst_ni),
                .valid_i(valid[i]),
                .ready_o(ready[i]),
                .data_i (data[i]),
                .valid_o(valid[i+1]),
                .ready_i(ready[i+1]),
                .data_o (data[i+1])
            );
        end
    end
endmodule
