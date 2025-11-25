// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

// Module description:

// TODO: get the addr and data widths from the mem_req_t and mem_rsp_t types

module tcdm_interconnect_wrap #(
    parameter int unsigned NumIn = 4,
    parameter int unsigned NumOut = 4,
    parameter int unsigned AddrWidth = 32,
    parameter int unsigned DataWidth = 32,
    parameter int unsigned AddrMemWidth = 4,
    parameter int unsigned BeWidth = 4,
    parameter int unsigned RespLat = 1,

    parameter type mem_req_t = logic,
    parameter type mem_rsp_t = logic
)(
    input logic clk_i,
    input logic rst_ni,

    input mem_req_t [NumIn-1:0] mem_req_i,
    output mem_rsp_t [NumIn-1:0] mem_rsp_o,

    output mem_req_t [NumOut-1:0] mem_req_o,
    input mem_rsp_t [NumOut-1:0] mem_rsp_i
);

    logic [NumIn-1:0] mem_req_i_q_valid;
    logic [NumIn-1:0] mem_req_o_q_ready;
    logic [NumIn-1:0][AddrWidth-1:0] mem_req_i_q_addr;
    logic [NumIn-1:0] mem_req_i_q_write;
    logic [NumIn-1:0][DataWidth-1:0] mem_req_i_q_data;
    logic [NumIn-1:0][(DataWidth/8)-1:0] mem_req_i_q_strb;
    logic [NumIn-1:0] mem_rsp_o_p_valid;
    logic [NumIn-1:0][DataWidth-1:0] mem_rsp_o_p_data;

    for(genvar i = 0; i < NumIn; i++) begin
        assign mem_req_i_q_valid[i] = mem_req_i[i].q_valid;
        assign mem_req_i_q_addr[i]  = mem_req_i[i].q.addr;
        assign mem_req_i_q_write[i] = mem_req_i[i].q.write;
        assign mem_req_i_q_data[i]  = mem_req_i[i].q.data;
        assign mem_req_i_q_strb[i]  = mem_req_i[i].q.strb;

        assign mem_rsp_o[i].p.valid = mem_rsp_o_p_valid[i];
        assign mem_rsp_o[i].p.data  = mem_rsp_o_p_data[i];
        assign mem_rsp_o[i].q_ready = mem_req_o_q_ready[i];
    end

    logic [NumOut-1:0] mem_req_o_q_valid;
    logic [NumOut-1:0] mem_req_i_q_ready;
    logic [NumOut-1:0][AddrWidth-1:0] mem_req_o_q_addr;
    logic [NumOut-1:0] mem_req_o_q_write;
    logic [NumOut-1:0][DataWidth-1:0] mem_req_o_q_data;
    logic [NumOut-1:0][(DataWidth/8)-1:0] mem_req_o_q_strb;
    logic [NumOut-1:0][DataWidth-1:0] mem_rsp_i_p_data;
    logic [NumOut-1:0] mem_rsp_i_p_valid;

    for(genvar j = 0; j < NumOut; j++) begin
        assign mem_req_o[j].q_valid =  mem_req_o_q_valid[j];
        assign mem_req_o[j].q.addr  =  mem_req_o_q_addr[j];
        assign mem_req_o[j].q.write =  mem_req_o_q_write[j];
        assign mem_req_o[j].q.data  =  mem_req_o_q_data[j];
        assign mem_req_o[j].q.strb  =  mem_req_o_q_strb[j];

        assign mem_rsp_i_p_data[j]  =  mem_rsp_i[j].p.data;
        assign mem_rsp_i_p_valid[j] =  mem_rsp_i[j].p.valid;
        assign mem_req_i_q_ready[j] =  mem_req_i[j].q_ready;
    end


    tcdm_interconnect #(
        .NumIn(NumIn),
        .NumOut(NumOut),
        .AddrWidth(AddrWidth),
        .DataWidth(DataWidth),
        .BeWidth(BeWidth),
        .AddrMemWidth(AddrMemWidth),
        .RespLat(RespLat),
        .Topology(tcdm_interconnect_pkg::LIC)
    ) i_tcdm_interconnect (
        .clk_i(clk_i),
        .rst_ni(rst_ni),

        .req_i(mem_req_i_q_valid),
        .add_i(mem_req_i_q_addr),
        .wen_i(mem_req_i_q_write),
        .wdata_i(mem_req_i_q_data),
        .be_i(mem_req_i_q_strb),
        .gnt_o(mem_req_o_q_ready),
        .vld_o(mem_rsp_o_p_valid),
        .rdata_o(mem_rsp_o_p_data),

        .req_o(mem_req_o_q_valid),
        .gnt_i(mem_req_i_q_ready),
        .add_o(mem_req_o_q_addr),
        .wen_o(mem_req_o_q_write),
        .wdata_o(mem_req_o_q_data),
        .be_o(mem_req_o_q_strb),
        .rdata_i(mem_rsp_i_p_data)
    );

endmodule : tcdm_interconnect_wrap