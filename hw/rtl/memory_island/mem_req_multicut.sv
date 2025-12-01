// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

// Module: mem_req_multicut

// Description:
//      Inserts a configurable number of spill register stages into the request path 
//      of a memory interface.

// Parameters:
//      AddrWidth: Address width of memory interface.
//      DataWidth: Data width of memory interface.
//      NumCuts: Number of pipeline stages (spill registers) to insert (0 = bypass).
//      mem_req_t: Memory request typedef (must provide q_valid, q.write, q.strb, q.addr, q.data).

// Ports:
//      clk_i: Clock.
//      rst_ni: Active-low reset.
//      req_i: Memory request input (from upstream requestor).
//      req_o: Memory request output (to downstream memory controller).
//      ready_i: Ready signal from downstream (backpressure).
//      ready_o: Ready signal to upstream (indicates this stage can accept new request).

module mem_req_multicut #(
    /// Address Width
    parameter int unsigned AddrWidth = 0,
    /// Data Width
    parameter int unsigned DataWidth = 0,
    /// Number of cuts
    parameter int unsigned NumCuts = 0,
    
    parameter type mem_req_t = logic,
    // Derived, DO NOT OVERRIDE
    parameter int unsigned StrbWidth = DataWidth / 8
) (
    input logic clk_i,
    input logic rst_ni,

    input mem_req_t req_i,
    output mem_req_t req_o,

    input logic ready_i,
    output logic ready_o
);

    localparam int unsigned AggDataWidth = 1 + StrbWidth + AddrWidth + DataWidth;
    if (NumCuts == 0) begin : gen_passthrough
        assign req_o = req_i;
    end else begin : gen_cuts
        logic [NumCuts:0][AggDataWidth-1:0] data_agg;
        logic [NumCuts:0] valid, ready;

        assign data_agg[0] = {req_i.q.write, req_i.q.strb, req_i.q.addr, req_i.q.data};
        assign valid[0] = req_i.q_valid;
        assign ready_o = ready[0];
        assign ready[NumCuts] = ready_i;
        assign req_o.q_valid = valid[NumCuts];
        assign {req_o.q.write, req_o.q.strb, req_o.q.addr, req_o.q.data} = data_agg[NumCuts];

        for (genvar i = 0; i < NumCuts; i++) begin : gen_cut
          spill_register #(
            .T(logic [AggDataWidth-1:0]),
            .Bypass(1'b0)
          ) i_cut (
            .clk_i(clk_i),
            .rst_ni(rst_ni),
            .valid_i(valid[i]),
            .ready_o(ready[i]),
            .data_i(data_agg[i]),
            .valid_o(valid[i+1]),
            .ready_i(ready[i+1]),
            .data_o(data_agg[i+1])
          );
        end
    end
endmodule