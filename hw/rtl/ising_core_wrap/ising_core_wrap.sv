// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Ising core wrapper

module ising_core_wrap #(
    parameter mem_cfg_t l1_mem_cfg = '0,
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

    //////////////////////////////////////////////////////////
    // L1 memory, with narrow and direct access //////////////
    //////////////////////////////////////////////////////////
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
    ) i_l1_mem (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),
        // AXI slave interface
        .axi_narrow_req_i(axi_s_req_i),
        .axi_narrow_rsp_o(axi_s_rsp_o),
        // Direct access slave interface
        .direct_req_i(drt_s_req),
        .direct_rsp_o(drt_s_rsp)
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
        .mode_select_o(mode_select)
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
        // TODO: to be defined
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










// Registers (to instantiate with DFFs)
logic [32-1:0] analog_cfg_hreg;
logic [32-1:0] analog_cfg_lreg;
logic analog_cfg_start;
logic [1:0] tx_mode;
logic [32-1:0] tx_timer;
logic [32-1:0] rx_timer;
logic tx_busy;
logic rx_busy;
logic analog_cfg_busy;
logic wmem_analog_intf_busy;
logic spin_pop_valid_host;

// Internal wire signals
logic [DATA_BIT*BITJ-1:0] analog_cfg_data;
logic analog_cfg_done;
logic analog_wen;
logic [ANALOG_DEPTH-1:0] analog_waddr;
logic [DATA_BIT*BITJ-1:0] analog_wdata;
logic wmem_ren;
logic [$clog2(ANALOG_DEPTH)-1:0] wmem_raddr;
logic [DATA_BIT*BITJ-1:0] wmem_rdata;
logic tx_timer_reset;
logic [DATASPIN-1:0] analog_spin;
logic tx_data_valid;
logic [DATASPIN-1:0] tx_data;
logic wmem_wen;
logic [$clog2(ANALOG_DEPTH)-1:0] wmem_waddr;
logic [DATASPIN*BITJ-1:0] wmem_wdata;
logic analog_spin_wen;
logic [DATASPIN-1:0] analog_wr_spin;
logic analog_compute_en;
logic fmem_ren;
logic [$clog2(FLIP_ICON_DEPTH)-1:0] fmem_raddr;
logic [DATASPIN-1:0] fmem_rdata;
logic spin_pop_valid_gated;

////////////////////////////////////////////////
// Logic instances
// wmem to analog config bridge
analog_cfg u_analog_cfg (
    .ANALOG_DEPTH(ANALOG_DEPTH),
    .DATA_BIT(DATASPIN*BITJ)
)(
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .counter_high_reg_i(analog_cfg_hreg),
    .counter_low_reg_i(analog_cfg_lreg),
    .analog_cfg_start_i(analog_cfg_start),
    .analog_cfg_data_i(analog_cfg_data),
    .analog_cfg_done_o(analog_cfg_done),
    .analog_wen_o(analog_wen),
    .analog_waddr_o(analog_waddr), // one hot address
    .analog_wdata_o(analog_wdata),
    .analog_cfg_busy_o(analog_cfg_busy)
);

wmem_analog_intf u_wmem_analog_intf (
    .DATAJ(DATASPIN*BITJ)
)(
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .analog_cfg_start_i(analog_cfg_start),
    .wmem_ren_o(wmem_ren),
    .wmem_raddr_o(wmem_raddr),
    .wmem_rdata_i(wmem_rdata),
    .analog_cfg_data_o(analog_cfg_data),
    .wmem_analog_intf_busy_o(wmem_analog_intf_busy)
);

// analog TX interface
analog_tx u_analog_tx (
    .DATASPIN(DATASPIN)
)(
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .tx_mode_i(tx_mode), // 2'b00: direct connect; 2'b01/10/11: one/two/three-cycle synchronized;
    .tx_timer_i(tx_timer), // 32b timer for synchronization
    .tx_timer_reset_i(tx_timer_reset),
    .analog_data_i(analog_spin),
    .tx_data_valid_o(tx_data_valid),
    .tx_data_o(tx_data),
    .tx_busy_o(tx_busy)
);
assign tx_timer_reset = analog_compute_en;

// analog RX interface
analog_rx u_analog_rx (
    .DATASPIN(DATASPIN)
)(
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .rx_timer_i(rx_timer), // 32b timer for synchronization
    .rx_valid_i(spin_pop_valid_gated),
    .rx_data_i(spin_pop_o),
    .rx_ready_o(spin_pop_ready),
    .analog_spin_wen_o(analog_spin_wen),
    .analog_wr_spin_o(analog_wr_spin),
    .analog_compute_en_o(analog_compute_en),
    .rx_busy_o(rx_busy)
);

////////////// TO DO: instantiate em and fm //////////////
// Add a spin pop host gating signal
assign spin_pop_valid_gated = spin_pop_valid_host & spin_pop_valid;


////////////////////////////////////////////////
// Memory instances

wmem #(
    .DATA_WIDTH(DATASPIN*BITJ),
    .ADDR_WIDTH($clog2(ANALOG_DEPTH)),
    .DEPTH(ANALOG_DEPTH)
) u_wmem (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .wen_i(wmem_wen),
    .waddr_i(wmem_waddr),
    .wdata_i(wmem_wdata),
    .ren_i(wmem_ren),
    .raddr_i(wmem_raddr),
    .rdata_o(wmem_rdata)
);

fmem #(
    .DATA_WIDTH(DATASPIN),
    .ADDR_WIDTH($clog2(FLIP_ICON_DEPTH)),
    .DEPTH(FLIP_ICON_DEPTH)
) u_fmem (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .wen_i(flip_ren_o),
    .waddr_i(flip_raddr_o),
    .wdata_i(flip_rdata_i),
    .ren_i(fmem_ren),
    .raddr_i(fmem_raddr),
    .rdata_o(fmem_rdata)
);

////////////////////////////////////////////////
// Analog macro instance



endmodule
