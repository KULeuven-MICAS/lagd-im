// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

// Module description:

module tcdm_interconnect_wrap #(
    parameter int unsigned NumIn = 4,
    parameter int unsigned NumOut = 4,
    parameter int unsigned AddrWidth = 32,
    parameter int unsigned DataWidth = 32,
    parameter int unsigned AddrMemWidth = 4,
    parameter int unsigned AccessLatency = 1,

    parameter type mem_req_t = logic,
    parameter type mem_rsp_t = logic
)(
    input logic clk_i,
    input logic rst_ni,

    input mem_req_t [NumIn-1:0] mem_req_i,
    output mem_rsp_t [NumIn-1:0] mem_rsp_o,

    output mem_req_t [NumOut-1:0] mem_req_o [NumIn-1:0],
    input mem_rsp_t [NumOut-1:0] mem_rsp_i [NumIn-1:0]
);

    tcdm_interconnect #(
        .NumIn(NumIn),
        .NumOut(NumOut),
        .AddrWidth(AddrWidth),
        .DataWidth(DataWidth),
        .AddrMemWidth(AddrMemWidth),
        .AccessLatency(AccessLatency),
        .Topology(tcdm_interconnect_pkg::LIC)
    ) i_tcdm_interconnect (
        .clk_i(clk_i),
        .rst_ni(rst_ni),

        .req_i(mem_req_i.q_valid),
        .add_i(mem_req_i.q.addr),
        .wen_i(mem_req_i.q.write),
        .wdata_i(mem_req_i.q.data),
        .be_i(mem_req_i.q.strb),
        .gnt_o(mem_req_o.q_ready),
        .vld_o(mem_rsp_o.p.valid),
        .rdata_o(mem_rsp_o.p.data),

        .req_o(mem_req_o.q_valid),
        .gnt_i(mem_req_i.q_ready),
        .add_o(mem_req_o.q.addr),
        .wen_o(mem_req_o.q.write),
        .wdata_o(mem_req_o.q.data),
        .be_o(mem_req_o.q.strb),
        .rdata_i(mem_rsp_i.p.data)
    );

endmodule : tcdm_interconnect_wrap