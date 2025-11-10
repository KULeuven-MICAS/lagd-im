// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

// Module description:

module wide_to_narrow_splitter #(
    parameter int unsigned MemAddrWidth = 32,
    parameter int unsigned BankAddrWidth = 32,
    parameter int unsigned MemDataWidth = 64,
    parameter int unsigned BankDataWidth = 32,
    parameter int unsigned WordSize = 8,

    parameter type mem_req_t = logic,
    parameter type mem_rsp_t = logic,
    parameter type bank_req_t = logic,
    parameter type bank_rsp_t = logic,

    parameter int unsigned NumBanks = MemDataWidth / BankDataWidth,
    parameter int unsigned BankAddrOffset = $clog2(MemDataWidth/WordSize)
) (
    input logic clk_i,
    input logic rst_ni,

    input mem_req_t mem_req_i,
    output mem_rsp_t mem_rsp_o,

    output bank_req_t [NumBanks-1:0] bank_req_o,
    input bank_rsp_t [NumBanks-1:0] bank_rsp_i
);

    // Split mem_req into bank_req
    genvar i;
    generate
        for (i = 0; i < NumBanks; i++) begin : gen_split_req
            assign bank_req_o[i].q_valid = mem_req_i.q_valid;
            assign bank_req_o[i].q.addr  = mem_req_i.q.addr[
                MemAddrWidth - BankAddrWidth - 1 : BankAddrOffset];
            assign bank_req_o[i].q.data  = mem_req_i.q.data[
                (i+1)*BankDataWidth-1 -: BankDataWidth];
            assign bank_req_o[i].q.strb  = mem_req_i.q.strb[
                (i+1)*BankDataWidth/WordSize-1 -: BankDataWidth/WordSize];
            assign bank_req_o[i].q.write = mem_req_i.q.write;
            assign bank_req_o[i].q.user  = mem_req_i.q.user;
        end
    endgenerate

    logic [NumBanks-1:0] rsp_valids;
    logic [NumBanks-1:0] rsp_readys;
    generate
        for (i = 0; i < NumBanks; i++) begin : gen_merge_rsp
            assign mem_rsp_o.p.data[
                (i+1)*BankDataWidth-1 -: BankDataWidth] = bank_rsp_i[i].p.data;
            assign rsp_valids[i] = bank_rsp_i[i].p.valid;
            assign rsp_readys[i] = bank_rsp_i[i].q_ready;
        end
    endgenerate
    assign mem_rsp_o.p.valid = &rsp_valids;
    assign mem_rsp_o.q_ready = &rsp_readys;

endmodule