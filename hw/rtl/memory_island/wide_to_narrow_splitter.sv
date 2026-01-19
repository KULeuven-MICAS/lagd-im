// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

// Module: wide_to_narrow_splitter

// Description:
//      Splits a single wide memory request into multiple narrow bank requests.
// Data Mapping:
//      A wide memory word (MemDataWidth bits) is split into NumBanks narrow words 
//      (BankDataWidth bits each):
//          - Bank 0 receives bits [BankDataWidth-1 : 0]
//          - Bank 1 receives bits [2*BankDataWidth-1 : BankDataWidth]
//          - ...
//          - Bank NumBanks-1 receives bits [MemDataWidth-1 : (NumBanks-1)*BankDataWidth]
// Address Mapping:
//      Each bank request receives a consecutive address offset to ensure the narrow 
//      words reconstruct the wide word correctly:
//          bank_addr[i] = mem_addr + i * (MemDataWidth / WordSize)
//      where:
//          - mem_addr is the base address from mem_req_i.q.addr
//          - BankAddrOffset = log2(MemDataWidth / WordSize) is the address increment per bank
//          - i ranges from 0 to NumBanks-1
//      Example: MemDataWidth=256 bits, BankDataWidth=64 bits, WordSize=8 (byte-addressable)
//          - NumBanks = 4
//          - BankAddrOffset = log2(256/8) = log2(32) = 5
//          - If mem_addr = 0x1000, bank addresses are:
//              Bank 0: 0x1000 + 0*32 = 0x1000
//              Bank 1: 0x1000 + 1*32 = 0x1020
//              Bank 2: 0x1000 + 2*32 = 0x1040
//              Bank 3: 0x1000 + 3*32 = 0x1060

// Parameters:
//      MemAddrWidth: Address width of wide memory interface (bits).
//      BankAddrWidth: Address width of narrow bank interfaces (bits).
//                     Must be >= MemAddrWidth to accommodate address offsets.
//      MemDataWidth: Data width of wide memory interface (bits).
//      BankDataWidth: Data width of narrow bank interfaces (bits).
//                     MemDataWidth must be an integer multiple of BankDataWidth.
//      WordSize: Addressable unit size (typically 8 for byte-addressable systems).
//      mem_req_t / mem_rsp_t: Wide memory request/response struct types 
//          (must have q_valid, q.{addr,data,strb,write,user}, p.{data,valid}, q_ready).
//      bank_req_t / bank_rsp_t: Narrow bank request/response struct types (same fields).

// Ports:
//      clk_i: Clock (not used; module is purely combinational, but kept for consistency).
//      rst_ni: Active-low reset (not used; module is purely combinational).
//      Wide Memory Interface:
//          mem_req_i: Wide memory request input (single wide word).
//          mem_rsp_o: Wide memory response output (aggregated from all banks).
//      Narrow Bank Interfaces (parallel, one per bank):
//          bank_req_o[NumBanks-1:0]: Narrow bank request outputs (one per bank).
//          bank_rsp_i[NumBanks-1:0]: Narrow bank response inputs (one per bank).

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
            assign bank_req_o[i].q.addr  = mem_req_i.q.addr;
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

    // -----------------
    // Logs
    // -----------------
    `ifdef TARGET_LOG_INSTS
    $info("Instantiated wide_to_narrow_splitter with parameters:");
    `ifndef TARGET_SYNOPSYS
    $info("Module: %m");
    $info("  mem_req_t: %s", $typename(mem_req_i));
    $info("  mem_rsp_t: %s", $typename(mem_rsp_o));
    $info("  bank_req_t: %s", $typename(bank_req_o[0]));
    $info("  bank_rsp_t: %s", $typename(bank_rsp_i[0]));
    `endif
    $info("  MemAddrWidth: %d", MemAddrWidth);
    $info("  BankAddrWidth: %d", BankAddrWidth);
    $info("  MemDataWidth: %d", MemDataWidth);
    $info("  BankDataWidth: %d", BankDataWidth);
    $info("  WordSize: %d", WordSize);
    `endif // TARGET_LOG_INSTS

endmodule