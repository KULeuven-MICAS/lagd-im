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
            logic [1:0] mem_req_valid;
            logic [1:0] mem_rsp_ready;
            logic [1:0][AddrWidth-1:0] mem_req_addr;
            logic [1:0][MemDataWidth-1:0] mem_req_wdata;
            logic [1:0][(MemDataWidth/8)-1:0] mem_req_strb;
            logic [1:0] mem_req_we;
            logic [1:0] mem_rsp_rvalid;
            logic [1:0][MemDataWidth-1:0] mem_rsp_rdata;

            for(genvar i = 0; i < 2; i++) begin: mem_signals
                assign mem_req_o[i].q_valid = mem_req_valid[i];
                assign mem_req_o[i].q.addr = mem_req_addr[i];
                assign mem_req_o[i].q.data = mem_req_wdata[i];
                assign mem_req_o[i].q.strb = mem_req_strb[i];
                assign mem_req_o[i].q.write = mem_req_we[i];

                assign mem_rsp_ready[i] = mem_rsp_i[i].q_ready;
                assign mem_rsp_rvalid[i] =  mem_rsp_i[i].p.valid;
                assign mem_rsp_rdata[i] =  mem_rsp_i[i].p.data;
            end

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
                .mem_req_o(mem_req_valid),
                .mem_gnt_i(mem_rsp_ready),
                .mem_addr_o(mem_req_addr),
                .mem_wdata_o(mem_req_wdata),
                .mem_strb_o(mem_req_strb),
                .mem_atop_o(),
                .mem_we_o(mem_req_we),
                .mem_rvalid_i(mem_rsp_rvalid),
                .mem_rdata_i(mem_rsp_rdata)
            );
        end else begin : ro_adapter
            localparam int AxiToMemAdapter_AddrWidth = $bits(mem_req_o[0].q.addr);
            $info("AxiToMemAdapter_AddrWidth: %d; AddrWidth: %d", AxiToMemAdapter_AddrWidth, AddrWidth);
            axi_to_mem #(
                .axi_req_t(axi_req_t),
                .axi_resp_t(axi_rsp_t),
                .AddrWidth(AddrWidth),
                .IdWidth(IdWidth),
                .DataWidth(MemDataWidth),
                .BufDepth(BufDepth),
                .NumBanks    (1),
                .HideStrb    (1'b0),
                .OutFifoDepth(1)
            ) i_narrow_conv (
                .clk_i(clk_i),
                .rst_ni(rst_ni),
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
