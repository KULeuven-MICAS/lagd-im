// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

module axi_to_mem_adapter #(
    parameter type axi_req_t = logic,
    parameter type axi_rsp_t = logic,
    parameter type mem_req_t = logic,
    parameter type mem_rsp_t = logic,
    parameter int unsigned AddrWidth = 0,
    parameter int unsigned DataWidth = 0,
    parameter int unsigned IdWidth = 0,
    parameter int unsigned MemDataWidth = 0,
    parameter int unsigned BufDepth = 0,
    parameter bit ReadWrite = 1'b0
)(
    input logic clk_i,
    input logic rst_ni,

    input axi_req_t axi_req_i,
    output axi_rsp_t axi_rsp_o,

    input mem_rsp_t [ReadWrite:0] mem_rsp_i,
    output mem_req_t [ReadWrite:0] mem_req_o
);

    generate
        if (ReadWrite) begin : rw_adapter
            axi_to_mem_split #(
                .axi_req_t(axi_req_t),
                .axi_rsp_t(axi_rsp_t),
                .AddrWidth(AddrWidth),
                .IdWidth(IdWidth),
                .MemDataWidth(MemDataWidth),
                .BufDepth(BufDepth),
                .HideStrb(1'b0),
                .OutFifoDepth(1)
            ) i_narrow_conv (
                .clk_i(clk_i),
                .rst_ni(rst_ni),
                .test_i('0),
                .busy_o(),
                .axi_req_i(axi_req_i),
                .axi_resp_o(axi_rsp_o),
                .mem_req_o({mem_req_o[1].q_valid, mem_req_o[0].q_valid}),
                .mem_gnt_i({mem_rsp_i[1].q_ready, mem_rsp_i[0].q_ready}),
                .mem_addr_o({mem_req_o[1].q.addr, mem_req_o[0].q.addr}),
                .mem_wdata_o({mem_req_o[1].q.data, mem_req_o[0].q.data}),
                .mem_strb_o({mem_req_o[1].q.strb, mem_req_o[0].q.strb}),
                .mem_atop_o(),
                .mem_we_o({mem_req_o[1].q.write, mem_req_o[0].q.write}),
                .mem_rvalid_i({mem_rsp_i[1].p.valid, mem_rsp_i[0].p.valid}),
                .mem_rdata_i({mem_rsp_i[1].p.data, mem_rsp_i[0].p.data})
            );
        end else begin : ro_adapter
            axi_to_mem #(
                .axi_req_t(axi_req_t),
                .axi_rsp_t(axi_rsp_t),
                .AddrWidth(AddrWidth),
                .IdWidth(IdWidth),
                .MemDataWidth(MemDataWidth),
                .BufDepth(BufDepth),
                .NumBanks    (1),
                .HideStrb    (1'b0),
                .OutFifoDepth(1)
            ) i_narrow_conv (
                .clk_i(clk_i),
                .rst_ni(rst_ni),
                .test_i('0),
                .busy_o(),
                .axi_req_i(axi_req_i),
                .axi_resp_o(axi_rsp_o),
                .mem_req_o(mem_req_o[0].q_valid),
                .mem_gnt_i(mem_rsp_i[0].q_ready),
                .mem_addr_o(mem_req_o[0].q.addr),
                .mem_wdata_o(mem_req_o[0].q.data),
                .mem_strb_o(mem_req_o[0].q.strb),
                .mem_atop_o(),
                .mem_we_o(mem_req_o[0].q.write),
                .mem_rvalid_i(mem_rsp_i[0].p.valid),
                .mem_rdata_i(mem_rsp_i[0].p.data)
            );
        end
    endgenerate
endmodule
