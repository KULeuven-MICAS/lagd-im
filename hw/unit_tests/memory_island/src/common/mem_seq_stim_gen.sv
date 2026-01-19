// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

// Memory interface sequential stimulus generation

`timescale 1ns/1ps

module mem_seq_stim_gen #(
    parameter int unsigned AddrWidth = 48,
    parameter int unsigned DataWidth = 64,
    parameter int unsigned Write = 1,
    parameter int unsigned DataRandom = 0,
    parameter int unsigned RandMaster = 0,
    parameter int unsigned NumTransactions = 100,
    parameter longint unsigned TestRegionStart = 0,
    parameter longint unsigned TestRegionEnd = 200,
    parameter time TA = 1ns,

    parameter type mem_req_t = logic,
    parameter type mem_rsp_t = logic
) (
    // Clock and reset
    input logic clk_i,
    input logic rst_ni,

    // Memory interface (to comparator)
    output mem_req_t mem_req_o,
    input mem_rsp_t mem_rsp_i,
    input logic [AddrWidth-1:0] start_address_i,

    // Test control
    input logic test_start_i,
    output logic test_complete_o
);

    initial begin
        test_complete_o = 1'b0;
        mem_req_o = '0;
        mem_req_o.q.write = Write;
        @(negedge rst_ni);
        wait (test_start_i);
        // Simple sequential read/write transactions
        @(posedge clk_i);
        for (int unsigned i = 0; i < NumTransactions; i++) begin
            automatic longint unsigned Addr = start_address_i + (i * (DataWidth/8));
            automatic int unsigned RandomDelay = (RandMaster) ? $urandom_range(0, 5) : 0;
            mem_req_o.q.addr <= #TA Addr;
            mem_req_o.q.data <= #TA (DataRandom) ? $urandom() : Addr;
            mem_req_o.q_valid <= #TA 1'b1;
            mem_req_o.q.strb <= #TA '1; // All bytes valid
            mem_req_o.q.user <= #TA '0;
            wait (mem_rsp_i.q_ready);
            @(posedge clk_i);
            mem_req_o.q_valid <= #TA 1'b0;
            wait (mem_rsp_i.p.valid);
            repeat (RandomDelay) @(posedge clk_i);
        end
        test_complete_o = 1'b1;
    end
endmodule