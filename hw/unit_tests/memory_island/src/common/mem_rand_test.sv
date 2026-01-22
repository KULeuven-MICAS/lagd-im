// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

// AXI stimulus generation: Clock/reset and random master

`timescale 1ns/1ps

module mem_rand_test #(
    parameter int unsigned AddrWidth = 48,
    parameter int unsigned DataWidth = 64,
    parameter int unsigned UserWidth = 2,
    parameter longint unsigned TestRegionStart = 0,
    parameter longint unsigned TestRegionEnd = 200,
    parameter int unsigned NumTransactions = 100,
    parameter int unsigned RandInterval = 0,
    parameter int unsigned RandBurst = 0
) (
    // Clock and reset
    input logic clk_i,
    input logic rst_ni,

    // AXI master interface (to comparator)
    mem_bus_dv_if.Master mem_bus,

    // Test control
    input logic test_start_i,
    output logic test_complete_o
);

    `include "tb_config.svh"

    // ========================================================================
    // RANDOM AXI MASTER
    // ========================================================================

    typedef mem_test::mem_rand_master #(
        .AddrWidth(AddrWidth),
        .DataWidth(DataWidth),
        .UserWidth(UserWidth),
        .ApplicationTime(TA),
        .TestTime(TT)
    ) mem_rand_master_t;

    mem_rand_master_t rand_master;

    // ========================================================================
    // STIMULUS GENERATION
    // ========================================================================

    initial begin
        // Initialize random master
        test_complete_o = 1'b0;
        rand_master = new(mem_bus);

        // Define legal test region
        rand_master.add_memory_region(
            TestRegionStart,
            TestRegionEnd
        );

        // Reset phase
        rand_master.reset();
        @(posedge rst_ni);
        wait (test_start_i);
        // Run transactions
        rand_master.run('0, NumTransactions, RandInterval, RandBurst);

        // Wait for all responses
        @(posedge clk_i);

        test_complete_o = 1'b1;
    end

endmodule