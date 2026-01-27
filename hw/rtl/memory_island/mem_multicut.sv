// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

// Module: mem_multicut

// Description: 
//      Inserts configurable pipeline stages (cuts) into both request and response 
//      paths of a memory interface.

// Parameters:
//      AddrWidth: Address width of memory interface.
//      DataWidth: Data width of memory interface.
//      NumCutsReq: Number of pipeline stages to insert in request path (0 = bypass).
//      NumCutsRsp: Number of pipeline stages to insert in response path (0 = bypass).
//      mem_req_t: Memory request typedef (must provide q_valid, q.addr, q.data, q.strb, q.write).
//      mem_rsp_t: Memory response typedef (must provide q_ready, p.valid, p.data).

// Ports:
//      clk_i: Clock.
//      rst_ni: Active-low reset.
//      req_i / req_o: Memory request input/output (pipelined by NumCutsReq stages).
//      rsp_i / rsp_o: Memory response input/output (pipelined by NumCutsRsp stages).
//      read_ready_i / read_ready_o: Backpressure signaling for read responses 
//                                    (flows backward through response pipeline).

module mem_multicut #(
    /// Address Width
    parameter int unsigned AddrWidth = 0,
    /// Data Width
    parameter int unsigned DataWidth = 0,
    /// Number of cuts request
    parameter int unsigned NumCutsReq = 0,
    /// Number of cuts response
    parameter int unsigned NumCutsRsp = 0,
    
    parameter type mem_req_t = logic,
    parameter type mem_rsp_t = logic,
    // Derived, DO NOT OVERRIDE
    parameter int unsigned StrbWidth = DataWidth / 8
) (
    input logic clk_i,
    input logic rst_ni,

    input mem_req_t req_i,
    output mem_req_t req_o,

    input mem_rsp_t rsp_i,
    output mem_rsp_t rsp_o,

    input logic read_ready_i,
    output logic read_ready_o
);

    mem_req_multicut #(
        .AddrWidth(AddrWidth),
        .DataWidth(DataWidth),
        .NumCuts(NumCutsReq),
        .mem_req_t(mem_req_t)
    ) u_req_multicut (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .req_i(req_i),
        .req_o(req_o),
        .ready_i(rsp_i.q_ready),
        .ready_o(rsp_o.q_ready)
    );

    mem_rsp_t rsp_o_tmp;
    assign rsp_o.p = rsp_o_tmp.p;
    mem_rsp_multicut #(
        .DataWidth(DataWidth),
        .NumCuts(NumCutsRsp),
        .mem_rsp_t(mem_rsp_t)
    ) u_rsp_multicut (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .rsp_i(rsp_i),
        .rsp_o(rsp_o_tmp),
        .ready_i(read_ready_i),
        .ready_o(read_ready_o)
    );

    `ifdef TARGET_LOG_INSTS
    $info("Instantiated mem_multicut with parameters:");
    `ifndef TARGET_SYNOPSYS
    $info("Module: %m");
    $info("  mem_req_t: %s", $typename(req_i));
    $info("  mem_rsp_t: %s", $typename(rsp_i));
    `endif
    $info("  AddrWidth: %d", AddrWidth);
    $info("  DataWidth: %d", DataWidth);
    $info("  NumCutsReq: %d", NumCutsReq);
    $info("  NumCutsRsp: %d", NumCutsRsp);
    `endif // TARGET_LOG_INSTS
endmodule