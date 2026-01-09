// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

// AXI stimulus generation: Clock/reset and random master

`timescale 1ns/1ps

module axi_rand_generator #(
    parameter int unsigned AddrWidth = 48,
    parameter int unsigned DataWidth = 64,
    parameter int unsigned IdWidth   = 6,
    parameter int unsigned UserWidth = 2
) (
    // Clock and reset
    input logic clk_i,
    input logic rst_ni,

    // AXI master interface (to comparator)
    AXI_BUS_DV.Master axi_bus,

    // Test control
    output logic test_complete_o
);

    `include "tb_config.svh"

    // ========================================================================
    // RANDOM AXI MASTER
    // ========================================================================

    typedef axi_test::axi_rand_master #(
        .AW(AddrWidth),
        .DW(DataWidth),
        .IW(IdWidth),
        .UW(UserWidth),
        // Timing
        .TA(TA),
        .TT(TT),
        // Transaction limits
        .MAX_READ_TXNS(MAX_TXN_IN_FLIGHT),
        .MAX_WRITE_TXNS(MAX_TXN_IN_FLIGHT),
        // Burst configuration
        .SIZE_ALIGN(0),
        .AXI_MAX_BURST_LEN(0),
        .TRAFFIC_SHAPING(0),
        // Transaction types
        .AXI_EXCLS(1'b0),
        .AXI_ATOPS(1'b0),
        .AXI_BURST_FIXED(1'b0),
        .AXI_BURST_INCR(1'b1),
        .AXI_BURST_WRAP(1'b0),
        .UNIQUE_IDS(1'b0)
    ) axi_rand_master_t;

    axi_rand_master_t rand_master;

    // ========================================================================
    // STIMULUS GENERATION
    // ========================================================================

    initial begin
        // Initialize random master
        rand_master = new(axi_bus);

        // Define legal test region
        rand_master.add_memory_region(
            TEST_REGION_START,
            TEST_REGION_END,
            axi_pkg::DEVICE_NONBUFFERABLE
        );

        // Reset phase
        rand_master.reset();
        @(posedge rst_ni);

        // Run transactions
        rand_master.run(NUM_READ_TRANSACTIONS, NUM_WRITE_TRANSACTIONS);

        // Wait for all responses
        repeat(100) @(posedge clk_i);

        test_complete_o = 1'b1;
    end

endmodule
