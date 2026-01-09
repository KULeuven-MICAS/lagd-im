// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

// Golden model and comparison logic: Reference memory + DUT comparator

module tb_golden_model #(
    parameter type axi_req_t = logic,
    parameter type axi_rsp_t = logic,
    parameter type axi_aw_chan_t = logic,
    parameter type axi_w_chan_t = logic,
    parameter type axi_b_chan_t = logic,
    parameter type axi_ar_chan_t = logic,
    parameter type axi_r_chan_t = logic,
    parameter int unsigned AddrWidth = 48,
    parameter int unsigned DataWidth = 64,
    parameter int unsigned IdWidth   = 6,
    parameter int unsigned UserWidth = 2,
    parameter bit ReadWrite = 1'b0
) (
    input  logic                    clk_i,
    input  logic                    rst_ni,

    // Master (from stimulus)
    input  axi_req_t       axi_mst_req_i,
    output axi_rsp_t       axi_mst_rsp_o,

    // DUT (test target)
    output axi_req_t       axi_dut_req_o,
    input  axi_rsp_t       axi_dut_rsp_i,

    // Comparison result
    output logic                    mismatch_o
);

    `include "tb_config.svh"

    // ========================================================================
    // REFERENCE MEMORY MODEL
    // ========================================================================

    axi_req_t ref_req;
    axi_rsp_t ref_rsp;

    axi_sim_mem #(
        .AddrWidth(AddrWidth),
        .DataWidth(DataWidth),
        .IdWidth(IdWidth),
        .UserWidth(UserWidth),
        .NumPorts(1 + ReadWrite),
        .axi_req_t(axi_req_t),
        .axi_rsp_t(axi_rsp_t),
        .WarnUninitialized(1'b0),
        .UninitializedData("zeros"),
        .ClearErrOnAccess(1'b0),
        .ApplDelay(TA),
        .AcqDelay(TT)
    ) i_sim_mem (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .axi_req_i(ref_req),
        .axi_rsp_o(ref_rsp),
        // Monitor outputs (unused)
        .mon_w_valid_o(),
        .mon_w_addr_o(),
        .mon_w_data_o(),
        .mon_w_id_o(),
        .mon_w_user_o(),
        .mon_w_beat_count_o(),
        .mon_w_last_o(),
        .mon_r_valid_o(),
        .mon_r_addr_o(),
        .mon_r_data_o(),
        .mon_r_id_o(),
        .mon_r_user_o(),
        .mon_r_beat_count_o(),
        .mon_r_last_o()
    );

    // ========================================================================
    // COMPARATOR: DUT vs REFERENCE
    // ========================================================================

    axi_slave_compare #(
        .AxiIdWidth(IdWidth),
        .FifoDepth(32),
        .UseSize(1'b1),
        .DataWidth(DataWidth),
        .axi_aw_chan_t(axi_aw_chan_t),
        .axi_w_chan_t(axi_w_chan_t),
        .axi_b_chan_t(axi_b_chan_t),
        .axi_ar_chan_t(axi_ar_chan_t),
        .axi_r_chan_t(axi_r_chan_t),
        .axi_req_t(axi_req_t),
        .axi_rsp_t(axi_rsp_t)
    ) i_compare (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .testmode_i('0),
        // Master (stimulus)
        .axi_mst_req_i(axi_mst_req_i),
        .axi_mst_rsp_o(axi_mst_rsp_o),
        // Reference (golden model)
        .axi_ref_req_o(ref_req),
        .axi_ref_rsp_i(ref_rsp),
        // DUT (test target)
        .axi_test_req_o(axi_dut_req_o),
        .axi_test_rsp_i(axi_dut_rsp_i),
        // Results
        .aw_mismatch_o(),
        .w_mismatch_o(),
        .b_mismatch_o(),
        .ar_mismatch_o(),
        .r_mismatch_o(),
        .mismatch_o(mismatch_o),
        .busy_o()
    );

endmodule
