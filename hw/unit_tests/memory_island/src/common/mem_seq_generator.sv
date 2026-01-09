// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

`timescale 1ns/1ps

module mem_seq_generator #(
    parameter int unsigned AddrWidth = 48,
    parameter int unsigned DataWidth = 64,
    parameter int unsigned BeWidth = DataWidth/8,
    parameter int unsigned TestRegionStart = 0,
    parameter int unsigned TestRegionEnd   = 1024,
    parameter int unsigned NumTransactions = 16,
    parameter type mem_req_t = logic,

    parameter int unsigned AddrStep = $floor((TestRegionEnd - TestRegionStart) / NumTransactions)
) (
    input logic clk_i,
    input logic rst_ni,

    output mem_req_t req_o,
    input logic read_ready_i,
    input logic start_test_i,
    output logic test_complete_o
);

    `include "tb_config.svh"

    initial begin
        req_o = '0;
        req_o.q.addr  <= TestRegionStart;
        test_complete_o = 1'b0;
        wait (!rst_ni && start_test_i);
        @(posedge clk_i);
        while (req_o.q.addr < TestRegionEnd) begin
            req_o.q_valid <= 1'b1;
            req_o.q.addr  <= req_o.q.addr + AddrStep;
            req_o.q.data  <= {$urandom_range(0, 2**DataWidth-1)};
            req_o.q.strb  <= {BeWidth{1'b1}};
            req_o.q.write <= $urandom_range(0,1);
            @(posedge clk_i);
            wait (read_ready_i);
            req_o.q_valid <= 1'b0;
            @(posedge clk_i);
        end
        test_complete_o = 1'b1;
    end

endmodule