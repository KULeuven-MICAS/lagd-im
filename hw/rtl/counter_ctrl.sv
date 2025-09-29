// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Module description:
// Counter for the energy monitor module.
//
// Parameters:
// - COUNTER_BITWIDTH: bit width of the counter
// - PIPES: number of pipeline stages

`include "./lib/registers.svh"

module counter_ctrl #(
    parameter int COUNTER_BITWIDTH = $clog2(256),
    parameter int PIPES = 1
)(
    input logic clk_i,
    input logic rst_ni,
    input logic en_i,
    input logic config_valid_i,
    input logic [COUNTER_BITWIDTH-1:0] config_counter_i,
    input logic config_ready_i,

    input logic recount_en_i,
    input logic step_en_i,
    output logic [COUNTER_BITWIDTH-1:0] q_o,
    output logic counter_ready_o,
    output logic counter_overflow_o
);

    step_counter #(
        .COUNTER_BITWIDTH(COUNTER_BITWIDTH)
    ) u_step_counter (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .en_i(en_i),
        .load_i(config_valid_i && config_ready_i),
        .d_i(config_counter_i),
        .recount_en_i(spin_ready_o && spin_valid_i),
        .step_en_i(weight_ready_o && weight_valid_i),
        .q_o(q_o),
        .overflow_o(counter_overflow_o),
        .finish_o(counter_ready_o)
    );

endmodule