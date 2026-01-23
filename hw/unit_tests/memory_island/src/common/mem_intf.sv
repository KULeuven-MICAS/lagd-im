// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

interface mem_bus_dv_if #(
    parameter int unsigned AddrWidth = 48,
    parameter int unsigned DataWidth = 64,
    parameter int unsigned UserWidth = 8,
    parameter int unsigned StrbWidth = DataWidth/8
) (
    input logic clk_i
);
    // Memory request channel
    typedef struct packed {
        logic [AddrWidth-1:0] addr;
        logic [DataWidth-1:0] data;
        logic [StrbWidth-1:0] strb;
        logic [UserWidth-1:0] user;
        logic write; // 1 for write, 0 for read
    } mem_req_t;

    // Memory response channel
    typedef struct packed {
        logic [DataWidth-1:0] data;
        logic valid;
    } mem_rsp_t;

    // Request signals
    mem_req_t q;
    logic q_valid;
    logic q_ready;

    // Response signals
    mem_rsp_t p;
    modport Master (
        output q,
        output q_valid,
        input  q_ready,
        input  p
    );
endinterface : mem_bus_dv_if