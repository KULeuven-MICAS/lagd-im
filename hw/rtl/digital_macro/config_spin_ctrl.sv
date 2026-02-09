// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Module description:
// Logic FSM for the energy monitor module.
//
// Parameters:
// - None

`include "common_cells/registers.svh"

module config_spin_ctrl #(
    parameter int NUM_SPIN = 256,
    parameter int SPIN_DEPTH = 2, // SPIN_DEPTH must be a power of 2
    parameter int LITTLE_ENDIAN = 1,
    // derived parameters
    parameter int COUNTER_BITWIDTH = $clog2(SPIN_DEPTH)
)(
    input  logic clk_i,
    input  logic rst_ni,
    input  logic en_i,
    input  logic flush_i,
    input  logic multi_cmpt_start_i, // continusly high when in multi-computation mode, otherwise 0
    // upstream interface
    input  logic config_start_i, // must be a 1-cycle pulse
    input  logic [NUM_SPIN*SPIN_DEPTH-1:0] config_spin_initial_i,
    input  logic [SPIN_DEPTH-1:0] config_spin_initial_skip_i,
    // downstream interface
    output logic fm_flush_o,
    output logic config_spin_valid_o,
    output logic [NUM_SPIN-1:0] config_spin_initial_o,
    output logic config_spin_initial_skip_o,
    output logic multi_cmpt_en_o,
    // status
    output logic config_spin_ctrl_idle_o
);
    logic [COUNTER_BITWIDTH-1:0] config_cnt_q;
    logic config_finish, config_finish_dly1;
    logic config_cnt_maxed;

    // control logic
    assign fm_flush_o = en_i && config_start_i;
    assign config_spin_valid_o = en_i && ~config_spin_ctrl_idle_o;
    assign multi_cmpt_en_o = en_i && multi_cmpt_start_i && config_finish && ~config_finish_dly1;

    // data path
    if (LITTLE_ENDIAN) begin
        assign config_spin_initial_o = config_spin_initial_i[config_cnt_q*NUM_SPIN +: NUM_SPIN];
        assign config_spin_initial_skip_o = config_spin_initial_skip_i[config_cnt_q];
    end else begin
        assign config_spin_initial_o = config_spin_initial_i[(SPIN_DEPTH - config_cnt_q - 1)*NUM_SPIN +: NUM_SPIN];
        assign config_spin_initial_skip_o = config_spin_initial_skip_i[SPIN_DEPTH - config_cnt_q - 1];
    end

    `FFLARNC(config_spin_ctrl_idle_o, 1'b0, config_start_i, config_cnt_maxed, 1'b1, clk_i, rst_ni)
    `FFL(config_finish_dly1, config_finish, en_i, 1'b0, clk_i, rst_ni)

    step_counter #(
        .COUNTER_BITWIDTH (COUNTER_BITWIDTH),
        .PARALLELISM (1)
    ) config_depth_counter (
        .clk_i        (clk_i                                       ),
        .rst_ni       (rst_ni                                      ),
        .en_i         (en_i                                        ),
        .load_i       (1'b0                                        ),
        .d_i          ({(COUNTER_BITWIDTH){1'b0}}                  ),
        .recount_en_i (config_start_i                              ),
        .step_en_i    (~config_spin_ctrl_idle_o                    ),
        .q_o          (config_cnt_q                                ),
        .maxed_o      (config_cnt_maxed                            ),
        .overflow_o   (config_finish                               )
    );

endmodule