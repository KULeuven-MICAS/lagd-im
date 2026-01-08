// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

`timescale 1ns/1ps

module mem_req_dummy_generator #(
    parameter int unsigned AddrWidth = 48,
    parameter int unsigned DataWidth = 64,
    parameter type mem_req_t = logic
) (
    input logic clk_i,
    input logic rst_ni,

    output mem_req_t req_o,
    input logic read_ready_i,
    output logic test_complete_o
);
    `include "tb_config.svh"
    
    initial begin
        req_o = '0;
        test_complete_o = 1'b0;
        wait (!rst_ni);
        @(posedge clk_i);
        req_o.q_valid <= 1'b1;
        req_o.q.addr  <= {AddrWidth{1'b0}};
        req_o.q.data  <= {DataWidth{1'b1}};
        req_o.q.strb  <= {DataWidth/8{1'b1}};
        req_o.q.write <= 1'b1;
        @(posedge clk_i);
        wait (read_ready_i);
        req_o.q_valid <= 1'b0;
        @(posedge clk_i);
        req_o.q_valid <= 1'b1;
        req_o.q.addr  <= {AddrWidth{1'b1}};
        req_o.q.data  <= {DataWidth{1'b0}};
        req_o.q.strb  <= {DataWidth/8{1'b1}};
        req_o.q.write <= 1'b0;
        @(posedge clk_i);
        wait (read_ready_i);
        req_o.q_valid <= 1'b0;

        repeat (10) @(posedge clk_i);
        test_complete_o = 1'b1;
    end
endmodule

module mem_rsp_dummy_generator #(
    parameter int unsigned DataWidth = 64,
    parameter type mem_rsp_t = logic
) (
    input logic clk_i,
    input logic rst_ni,

    output mem_rsp_t rsp_o,
    output logic test_complete_o
);
    `include "tb_config.svh"

    initial begin
        rsp_o = '0;
        test_complete_o = 1'b0;
        wait (!rst_ni);
        rsp_o.p.valid <= 1'b1;
        rsp_o.p.data  <= {DataWidth{1'b1}};
        @(posedge clk_i);
        wait (rsp_o.q_ready);
        rsp_o.p.valid <= 1'b0;
        @(posedge clk_i);
        rsp_o.p.valid <= 1'b1;
        rsp_o.p.data  <= {DataWidth{1'b0}};
        @(posedge clk_i);
        wait (rsp_o.q_ready);
        rsp_o.p.valid <= 1'b0;

        repeat (10) @(posedge clk_i);
        test_complete_o = 1'b1;
    end
endmodule

module mem_dummy_generator #(
    parameter int unsigned AddrWidth = 48,
    parameter int unsigned DataWidth = 64,
    parameter type mem_req_t = logic,
    parameter type mem_rsp_t = logic
) (
    input logic clk_i,
    input logic rst_ni,

    output mem_req_t req_o,
    input logic read_ready_i,
    output mem_rsp_t rsp_o,
    output logic test_complete_o
);
    `include "tb_config.svh"

    logic req_test_complete;
    logic rsp_test_complete;

    mem_req_dummy_generator #(
        .AddrWidth(AddrWidth),
        .DataWidth(DataWidth),
        .mem_req_t(mem_req_t)
    ) req_gen (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .req_o(req_o),
        .read_ready_i(read_ready_i),
        .test_complete_o(req_test_complete)
    );

    mem_rsp_dummy_generator #(
        .DataWidth(DataWidth),
        .mem_rsp_t(mem_rsp_t)
    ) rsp_gen (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .rsp_o(rsp_o),
        .test_complete_o(rsp_test_complete)
    );

    assign test_complete_o = req_test_complete & rsp_test_complete;
endmodule