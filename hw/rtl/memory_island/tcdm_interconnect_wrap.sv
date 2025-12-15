// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

// Module: tcdm_interconnect_wrap

// Description:
//      Wrapper for the tcdm_interconnect module that bridges between struct-based memory 
//      protocol interfaces (mem_req_t/mem_rsp_t) and the signal-based interface expected 
//      by the underlying TCDM (Tightly Coupled Data Memory) interconnect. 

// Parameters:
//      NumIn: Number of input requestor ports.
//      NumOut: Number of output memory bank ports.
//      AddrWidth: Address width for input requests (bits used for routing and bank addressing).
//      DataWidth: Data width for read/write transactions (must match memory word size).
//      FullAddrWidth: Full address width .
//      AddrMemWidth: Address width presented to output .
//      BeWidth: Byte enable width, typically DataWidth/8 (one bit per byte).
//      RespLat: Fixed response latency in cycles (interconnect + memory access).
//      mem_req_t: Memory request struct type (must have q_valid, q.{addr,write,data,strb}).
//      mem_rsp_t: Memory response struct type (must have q_ready, p.{valid,data}).

// Ports:
//      clk_i: Clock.
//      rst_ni: Active-low reset.
//      Input Ports (from requestors, e.g., CPU cores):
//          mem_req_i[NumIn-1:0]: Memory request struct array.
//          mem_rsp_o[NumIn-1:0]: Memory response struct array.
//      Output Ports (to memory banks):
//          mem_req_o[NumOut-1:0]: Memory request struct array.
//          mem_rsp_i[NumOut-1:0]: Memory response struct array.

module tcdm_interconnect_wrap #(
    parameter int unsigned NumIn = 4,
    parameter int unsigned NumOut = 4,
    parameter int unsigned AddrWidth = 32,
    parameter int unsigned DataWidth = 32,
    parameter int unsigned FullAddrWidth = 32,
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
    logic [NumIn-1:0] mem_rsp_o_q_ready;
    logic [NumIn-1:0][AddrWidth-1:0] mem_req_i_q_addr;
    logic [NumIn-1:0] mem_req_i_q_write;
    logic [NumIn-1:0][DataWidth-1:0] mem_req_i_q_data;
    logic [NumIn-1:0][(DataWidth/8)-1:0] mem_req_i_q_strb;
    logic [NumIn-1:0] mem_rsp_o_p_valid;
    logic [NumIn-1:0][DataWidth-1:0] mem_rsp_o_p_data;

    for(genvar i = 0; i < NumIn; i++) begin
        assign mem_req_i_q_valid[i] = mem_req_i[i].q_valid;
        assign mem_req_i_q_addr[i]  = mem_req_i[i].q.addr[AddrWidth-1:0];
        assign mem_req_i_q_write[i] = mem_req_i[i].q.write;
        assign mem_req_i_q_data[i]  = mem_req_i[i].q.data;
        assign mem_req_i_q_strb[i]  = mem_req_i[i].q.strb;

        assign mem_rsp_o[i].p.valid = mem_rsp_o_p_valid[i];
        assign mem_rsp_o[i].p.data  = mem_rsp_o_p_data[i];
        assign mem_rsp_o[i].q_ready = mem_rsp_o_q_ready[i];
    end

    logic [NumOut-1:0] mem_req_o_q_valid;
    logic [NumOut-1:0] mem_rsp_i_q_ready;
    logic [NumOut-1:0][AddrMemWidth-1:0] mem_req_o_q_addr;
    logic [NumOut-1:0] mem_req_o_q_write;
    logic [NumOut-1:0][DataWidth-1:0] mem_req_o_q_data;
    logic [NumOut-1:0][(DataWidth/8)-1:0] mem_req_o_q_strb;
    logic [NumOut-1:0][DataWidth-1:0] mem_rsp_i_p_data;
    logic [NumOut-1:0] mem_rsp_i_p_valid;

    for(genvar j = 0; j < NumOut; j++) begin
        assign mem_req_o[j].q_valid = mem_req_o_q_valid[j];
        assign mem_req_o[j].q.addr = {{(FullAddrWidth-AddrMemWidth){1'b0}} ,mem_req_o_q_addr[j]};
        assign mem_req_o[j].q.write = mem_req_o_q_write[j];
        assign mem_req_o[j].q.data = mem_req_o_q_data[j];
        assign mem_req_o[j].q.strb = mem_req_o_q_strb[j];

        assign mem_rsp_i_p_data[j] = mem_rsp_i[j].p.data;
        assign mem_rsp_i_p_valid[j] = mem_rsp_i[j].p.valid;
        assign mem_rsp_i_q_ready[j] = mem_rsp_i[j].q_ready;
    end
    generate
        if (NumOut == 1) begin
            if (NumIn == 1) begin
                // Direct connection for 1x1 interconnect
                assign mem_req_o_q_valid[0] = mem_req_i_q_valid[0];
                assign mem_req_o_q_addr[0]  = mem_req_i_q_addr[0][AddrMemWidth-1:0];
                assign mem_req_o_q_write[0] = mem_req_i_q_write[0];
                assign mem_req_o_q_data[0]  = mem_req_i_q_data[0];
                assign mem_req_o_q_strb[0]  = mem_req_i_q_strb[0];

                assign mem_rsp_o_p_valid[0] = mem_rsp_i_p_valid[0];
                assign mem_rsp_o_p_data[0]  = mem_rsp_i_p_data[0];
                assign mem_rsp_o_q_ready[0] = mem_rsp_i_q_ready[0];
            end else begin
                $error("tcdm_interconnect_wrap: NumIn=1 with NumOut>1 is not supported.");
            end
        end else begin
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
                .gnt_o(mem_rsp_o_q_ready),
                .vld_o(mem_rsp_o_p_valid),
                .rdata_o(mem_rsp_o_p_data),

                .req_o(mem_req_o_q_valid),
                .gnt_i(mem_rsp_i_q_ready),
                .add_o(mem_req_o_q_addr),
                .wen_o(mem_req_o_q_write),
                .wdata_o(mem_req_o_q_data),
                .be_o(mem_req_o_q_strb),
                .rdata_i(mem_rsp_i_p_data)
            );
        end
    endgenerate

endmodule : tcdm_interconnect_wrap