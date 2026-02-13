// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// digital read address manager
// Generates read addresses sequentially

`include "common_cells/registers.svh"

module dgt_raddr_manager #(
    parameter int unsigned NUM_REQ = 256,
    parameter int unsigned PARALLELISM = 4,
    parameter int unsigned LSB_PRIORITY = 0, // same as LITTLE_ENDIAN
    parameter int unsigned PIPES_IN_ARBITER = 0,
    // Derived parameters
    parameter int unsigned ADDR_WIDTH = $clog2(NUM_REQ / PARALLELISM)
) (
    input  logic                  clk_i,
    input  logic                  rst_ni,
    input  logic                  en_i,
    input  logic                  flush_i,
    input  logic                  req_valid_i,
    input  logic [NUM_REQ-1   :0] req_i,
    input  logic [ADDR_WIDTH-1:0] addr_upper_bound_i,
    output logic                  idx_valid_o,
    input  logic                  idx_ready_i,
    output logic [ADDR_WIDTH-1:0] idx_o,
    output logic [NUM_REQ/PARALLELISM-1:0] grant_block_one_hot_o,
    output logic                  empty_o,
    output logic                  idx_last_one_o
);
    // Internal signals
    logic [NUM_REQ/PARALLELISM-1:0] req_q, req_n;
    logic               req_valid_reg;
    logic               req_valid_en_cond;
    logic [NUM_REQ/PARALLELISM-1:0] block_has_one;
    logic [ADDR_WIDTH-1+1:0] req_nz_count;
    logic [ADDR_WIDTH-1:0]  idx_counter;
    logic                 idx_counter_maxed;
    logic                 idx_counter_reset;
    logic                 empty_arbiter;
    logic [ADDR_WIDTH-1:0] idx_comb;
    genvar i;

    // control logic
    assign req_valid_en_cond  = en_i & req_valid_i;
    assign idx_counter_reset = flush_i | (idx_last_one_o & idx_valid_o & idx_ready_i);
    assign idx_last_one_o = empty_o ? 1'b0 :
            ((idx_counter == (req_nz_count-1)) || (idx_counter == addr_upper_bound_i));
    assign empty_o = req_valid_reg ? empty_arbiter : 1'b1;

    // data path
    generate
        for (i = 0; i < NUM_REQ / PARALLELISM; i++) begin : gen_block_has_one
            assign block_has_one[i] = |req_i[i*PARALLELISM +: PARALLELISM];
        end
    endgenerate
    assign req_n = req_valid_en_cond ? block_has_one : req_q & ~(grant_block_one_hot_o);
    assign idx_o = LSB_PRIORITY ? idx_comb :
                     (NUM_REQ/PARALLELISM - 1 - idx_comb);

    // sequential logic
    `FFLARNC(req_valid_reg, 1'b1, req_valid_en_cond, idx_counter_reset, 1'b0, clk_i, rst_ni)
    `FFLARNC(req_q, req_n, req_valid_en_cond | (req_valid_reg & idx_valid_o & idx_ready_i), flush_i, {NUM_REQ/PARALLELISM{1'b1}}, clk_i, rst_ni)

    // rely on popcount from pulp/common_cells
    popcount #(
        .INPUT_WIDTH      ( NUM_REQ / PARALLELISM )
    ) i_popcount (
        .data_i           ( block_has_one         ),
        .popcount_o       ( req_nz_count          )
    );

    step_counter #(
        .COUNTER_BITWIDTH( ADDR_WIDTH             ),
        .PARALLELISM     ( 1                      )
    ) i_idx_counter (
        .clk_i           ( clk_i                  ),
        .rst_ni          ( rst_ni                 ),
        .en_i            ( en_i                   ),
        .load_i          ( 1'b0                   ),
        .d_i             ( '0                     ),
        .recount_en_i    ( idx_counter_reset      ),
        .step_en_i       (idx_valid_o & idx_ready_i),
        .q_o             ( idx_counter            ),
        .maxed_o         ( idx_counter_maxed      ),
        .overflow_o      (                        )
    );

    customized_arbiter #(
        .NUM_REQ         ( NUM_REQ/PARALLELISM    ),
        .LSB_PRIORITY    ( LSB_PRIORITY           ),
        .PIPES           ( PIPES_IN_ARBITER       )
    ) i_prioarbiter (
        .clk_i           ( clk_i                  ),
        .rst_ni          ( rst_ni                 ),
        .en_i            ( en_i                   ),
        .flush_i         ( flush_i                ),
        .req_valid_i     ( req_valid_reg          ),
        .req_i           ( req_q                  ),
        .idx_valid_o     ( idx_valid_o            ),
        .grant_o         ( grant_block_one_hot_o  ),
        .idx_o           ( idx_comb               ),
        .empty_o         ( empty_arbiter          )
    );

endmodule