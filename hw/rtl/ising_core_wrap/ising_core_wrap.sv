// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Ising core wrapper

module ising_core_wrap #(
    parameter mem_cfg_t l1_mem_cfg_j = '0,
    parameter mem_cfg_t l1_mem_cfg_h = '0,
    parameter mem_cfg_t l1_mem_cfg_flip = '0,
    parameter ising_logic_cfg_t logic_cfg = '0,
    parameter type = axi_slv_req_t = logic,
    parameter type = axi_slv_rsp_t = logic,
    parameter type = reg_slv_req_t = logic,
    parameter type = reg_slv_rsp_t = logic
)(
    input logic clk_i,
    input logic rst_ni,

    // AXI slave interface
    input axi_slv_req_t axi_s_req_i,
    output axi_slv_rsp_t axi_s_rsp_o,

    // Register slave interface
    input reg_slv_req_t reg_s_req_i,
    output reg_slv_rsp_t reg_s_rsp_o
);

    // Internal signals
    logic [1:0] mode_select; // 00: idle; 01: weight loading; 10: computing; 11: debugging
    logic direct_req_t drt_s_req;
    logic direct_rsp_t drt_s_rsp;
    logic direct_req_t drt_s_req_load;
    logic direct_rsp_t drt_s_rsp_load;
    logic direct_req_t drt_s_req_compute;
    logic direct_rsp_t drt_s_rsp_compute;
    logic [logic_cfg.NumSpin-1:0] spin_regfile;

    //////////////////////////////////////////////////////////
    // L1 memory, with narrow and direct access //////////////
    //////////////////////////////////////////////////////////

    memory_axi_mux #(
        .AddrWidth          (l1_mem_cfg_j.AddrWidth),
        .NarrowDataWidth    (l1_mem_cfg_j.NarrowDataWidth),
        .AxiNarrowIdWidth   (l1_mem_cfg_j.AxiNarrowIdWidth),
        .WideDataWidth      (l1_mem_cfg_j.WideDataWidth),
        .NumWideBanks       (l1_mem_cfg_j.NumWideBanks),

        .axi_narrow_req_t   (axi_slv_req_t),
        .axi_narrow_rsp_t   (axi_slv_rsp_t),
        .NumNarrowReq       (l1_mem_cfg_j.NumNarrowReq),
        .NarrowRW           (l1_mem_cfg_j.NarrowRW),
        .WideRW             (l1_mem_cfg_j.WideRW)
    ) i_l1_mem_axi_mux (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),
        // AXI slave interface
        .axi_narrow_req_i(axi_s_req_i),
        .axi_narrow_rsp_o(axi_s_rsp_o),
        // AXI master interface
        .axi_narrow_req_j_o(axi_s_req_j),
        .axi_narrow_rsp_j_i(axi_s_rsp_j),
        .axi_narrow_req_h_o(axi_s_req_h),
        .axi_narrow_rsp_h_i(axi_s_rsp_h),
        .axi_narrow_req_flip_o(axi_s_req_flip),
        .axi_narrow_rsp_flip_i(axi_s_rsp_flip),
    );

    // TODO: parameters and interface are to be defined
    memory_island_wrap #(
        .AddrWidth          (l1_mem_cfg.AddrWidth),
        .NarrowDataWidth    (l1_mem_cfg.NarrowDataWidth),
        .AxiNarrowIdWidth   (l1_mem_cfg.AxiNarrowIdWidth),
        .WideDataWidth      (l1_mem_cfg.WideDataWidth),
        .NumWideBanks       (l1_mem_cfg.NumWideBanks),

        .axi_narrow_req_t   (axi_slv_req_t),
        .axi_narrow_rsp_t   (axi_slv_rsp_t),
        .NumNarrowReq       (l1_mem_cfg.NumNarrowReq),
        .NarrowRW           (l1_mem_cfg.NarrowRW),
        .WideRW             (l1_mem_cfg.WideRW),

        .SpillNarrowReqEntry    (l1_mem_cfg.SpillNarrowReqEntry),
        .SpillNarrowRspEntry    (l1_mem_cfg.SpillNarrowRspEntry),
        .SpillNarrowReqRouted   (l1_mem_cfg.SpillNarrowReqRouted),
        .SpillNarrowRspRouted   (l1_mem_cfg.SpillNarrowRspRouted),

        .SpillReqBank (l1_mem_cfg.SpillReqBank),
        .SpillRspBank (l1_mem_cfg.SpillRspBank),

        .WordsPerBank  (l1_mem_cfg.WordsPerBank)
    ) i_l1_mem_j (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),
        // AXI slave interface
        .axi_narrow_req_i(axi_s_req_j),
        .axi_narrow_rsp_o(axi_s_rsp_j),
        // Direct access slave interface
        .direct_req_i(drt_s_req_j),
        .direct_rsp_o(drt_s_rsp_j)
    );

    memory_island_wrap #(
    .AddrWidth          (l1_mem_cfg.AddrWidth),
    .NarrowDataWidth    (l1_mem_cfg.NarrowDataWidth),
    .AxiNarrowIdWidth   (l1_mem_cfg.AxiNarrowIdWidth),
    .WideDataWidth      (l1_mem_cfg.WideDataWidth),
    .NumWideBanks       (l1_mem_cfg.NumWideBanks),

    .axi_narrow_req_t   (axi_slv_req_t),
    .axi_narrow_rsp_t   (axi_slv_rsp_t),
    .NumNarrowReq       (l1_mem_cfg.NumNarrowReq),
    .NarrowRW           (l1_mem_cfg.NarrowRW),
    .WideRW             (l1_mem_cfg.WideRW),

    .SpillNarrowReqEntry    (l1_mem_cfg.SpillNarrowReqEntry),
    .SpillNarrowRspEntry    (l1_mem_cfg.SpillNarrowRspEntry),
    .SpillNarrowReqRouted   (l1_mem_cfg.SpillNarrowReqRouted),
    .SpillNarrowRspRouted   (l1_mem_cfg.SpillNarrowRspRouted),

    .SpillReqBank (l1_mem_cfg.SpillReqBank),
    .SpillRspBank (l1_mem_cfg.SpillRspBank),

    .WordsPerBank  (l1_mem_cfg.WordsPerBank)
    ) i_l1_mem_h (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),
        // AXI slave interface
        .axi_narrow_req_i(axi_s_req_h),
        .axi_narrow_rsp_o(axi_s_rsp_h),
        // Direct access slave interface
        .direct_req_i(drt_s_req_h),
        .direct_rsp_o(drt_s_rsp_h)
    );

    memory_island_wrap #(
    .AddrWidth          (l1_mem_cfg.AddrWidth),
    .NarrowDataWidth    (l1_mem_cfg.NarrowDataWidth),
    .AxiNarrowIdWidth   (l1_mem_cfg.AxiNarrowIdWidth),
    .WideDataWidth      (l1_mem_cfg.WideDataWidth),
    .NumWideBanks       (l1_mem_cfg.NumWideBanks),

    .axi_narrow_req_t   (axi_slv_req_t),
    .axi_narrow_rsp_t   (axi_slv_rsp_t),
    .NumNarrowReq       (l1_mem_cfg.NumNarrowReq),
    .NarrowRW           (l1_mem_cfg.NarrowRW),
    .WideRW             (l1_mem_cfg.WideRW),

    .SpillNarrowReqEntry    (l1_mem_cfg.SpillNarrowReqEntry),
    .SpillNarrowRspEntry    (l1_mem_cfg.SpillNarrowRspEntry),
    .SpillNarrowReqRouted   (l1_mem_cfg.SpillNarrowReqRouted),
    .SpillNarrowRspRouted   (l1_mem_cfg.SpillNarrowRspRouted),

    .SpillReqBank (l1_mem_cfg.SpillReqBank),
    .SpillRspBank (l1_mem_cfg.SpillRspBank),

    .WordsPerBank  (l1_mem_cfg.WordsPerBank)
    ) i_l1_mem_flip (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),
        // AXI slave interface
        .axi_narrow_req_i(axi_s_req_flip),
        .axi_narrow_rsp_o(axi_s_rsp_flip),
        // Direct access slave interface
        .direct_req_i(drt_s_req_flip),
        .direct_rsp_o(drt_s_rsp_flip)
    );

    //////////////////////////////////////////////////////////
    //Register interface /////////////////////////////////////
    //////////////////////////////////////////////////////////
    // TODO: parameters and interface are to be defined
    reg_interface_wrap #(
        .reg_slv_req_t    (reg_slv_req_t),
        .reg_slv_rsp_t    (reg_slv_rsp_t)
    ) i_reg_interface (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),
        // Register slave interface
        .reg_s_req_i    (reg_s_req_i),
        .reg_s_rsp_o    (reg_s_rsp_o),
        // Internal register interface
        .mode_select_o(mode_select),
        .spin_regfile_o(spin_regfile)
    );

    //////////////////////////////////////////////////////////
    // Analog Macro //////////////////////////////////////////
    //////////////////////////////////////////////////////////
    analog_macro_wrap i_analog_macro (
        .wen_i(analog_wen),
        .waddr_i(analog_waddr),
        .wdata_i(analog_wdata),
        .spin_wen_i(analog_spin_wen),
        .wr_spin_i(analog_wr_spin),
        .compute_en_i(analog_compute_en),
        .rd_spin_vld_o(analog_spin_vld),
        .rd_spin_rdy_i(analog_spin_rdy),
        .rd_spin_o(analog_spin)
    );

    //////////////////////////////////////////////////////////
    //Digital weight loading macro ///////////////////////////
    //////////////////////////////////////////////////////////
    digital_weight_load_macro #(
        .num_spin(logic_cfg.NumSpin),
        .bit_j(logic_cfg.BitJ),
        .bit_h(logic_cfg.BitH)
    ) i_digital_weight_load_macro (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        // L1 memory master interface
        .direct_req_o(drt_s_req_load),
        .direct_rsp_i(drt_s_rsp_load),
        // Register interface
        .mode_select_i(mode_select),
        // Analog macro interface
        .weight_load_en_o(analog_wen),
        .weight_load_addr_o(analog_waddr),
        .weight_load_data_o(analog_wdata)
    );

    //////////////////////////////////////////////////////////
    //Digital compute macro //////////////////////////////////
    //////////////////////////////////////////////////////////
    digital_compute_macro #(
        .num_spin(logic_cfg.NumSpin),
        .bit_j(logic_cfg.BitJ),
        .bit_h(logic_cfg.BitH),
        .flip_icon_depth(logic_cfg.FlipIconDepth)
    ) i_digital_compute_macro (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        // L1 memory master interface
        .direct_req_o(drt_s_req_compute),
        .direct_rsp_i(drt_s_rsp_compute),
        // Register interface
        .mode_select_i(mode_select),
        .spin_regfile_i(spin_regfile),
        // Analog macro interface
        .spin_wen_o(analog_spin_wen),
        .wr_spin_o(analog_wr_spin),
        .compute_en_o(analog_compute_en),
        .rd_spin_vld_i(analog_spin_vld),
        .rd_spin_rdy_o(analog_spin_rdy),
        .rd_spin_i(analog_spin)
    );

    always_comb begin
        case(mode_select)
            2'b00: begin
                drt_s_req = '0;
                drt_s_rsp_load = '0;
                drt_s_rsp_compute = '0;
            end
            2'b01: begin
                drt_s_req = drt_s_req_load;
                drt_s_rsp_load = drt_s_rsp;
                drt_s_rsp_compute = '0;
            end
            2'b10: begin
                drt_s_req = drt_s_req_compute;
                drt_s_rsp_load = '0;
                drt_s_rsp_compute = drt_s_rsp;
            end
            2'b11: begin
                drt_s_req = drt_s_req_compute;
                drt_s_rsp_load = '0;
                drt_s_rsp_compute = drt_s_rsp;
            end
            default: begin
                drt_s_req = '0;
                drt_s_rsp_load = '0;
                drt_s_rsp_compute = '0;
            end
        endcase
    end

endmodule
