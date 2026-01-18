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

    parameter type mem_req_t = logic,
    parameter type mem_rsp_t = logic
) (
    // Clock and reset
    input logic clk_i,
    input logic rst_ni,

    // Memory interface (to comparator)
    mem_req_t mem_req_o,
    mem_rsp_t mem_rsp_i,

    // Test control
    output logic test_complete_o
);

    initial begin
        test_complete_o = 1'b0;
        mem_req_o = '0;
        mem_req_o.q.write = Write;
        @(negedge rst_ni);
        // Simple sequential read/write transactions
        for (int unsigned i = 0; i < NumTransactions; i++) begin
            localparam longint unsigned Addr = TestRegionStart + (i * (DataWidth/8));
            localparam int unsigned RandomDelay = (RandMaster) ? $urandom_range(0, 5) : 0;
            mem_req_o.q.addr <= Addr;
            mem_req_o.q.data <= (DataRandom) ? $urandom() : Addr;
            mem_req_o.q_valid <= 1'b1;
            mem_req_o.q.strb <= '1; // All bytes valid
            mem_req_o.q.user <= '0;
            wait (mem_rsp_i.q_ready);
            wait (mem_rsp_i.p.valid);
            @(posedge clk_i);
            mem_req_o.q_valid <= 1'b0;
            repeat (RandomDelay) @(posedge clk_i);
        end
        test_complete_o = 1'b1;
    end