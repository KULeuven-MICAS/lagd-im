// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Ising core wrapper

`include "lagd_define.svh"

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
    input lagd_axi_slv_req_t axi_s_req_i,
    output lagd_axi_slv_rsp_t axi_s_rsp_o,

    // Register slave interface
    input lagd_reg_req_t reg_s_req_i,
    output lagd_reg_rsp_t reg_s_rsp_o
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

    lagd_axi_xbar #(
        .AXI_ADDR_WIDTH       ($clog2(`IC_L1_MEM_LIMIT)),
        .AXI_DATA_WIDTH       (`LAGD_AXI_DATA_WIDTH    ),
        .AXI_ID_WIDTH         (`LAGD_AXI_ID_WIDTH      ),
        .AXI_USER_WIDTH       (0                       )
    ) i_l1_mem_axi_xbar (
        .clk_i                (clk_i                   ),
        .rst_ni               (rst_ni                  ),
        .axi_narrow_req_i     (axi_s_req_i             ),
        .axi_narrow_rsp_o     (axi_s_rsp_o             ),
        .axi_narrow_req_j_o   (axi_s_req_j             ),
        .axi_narrow_rsp_j_i   (axi_s_rsp_j             ),
        .axi_narrow_req_h_o   (axi_s_req_h             ),
        .axi_narrow_rsp_h_i   (axi_s_rsp_h             ),
        .axi_narrow_req_flip_o(axi_s_req_flip          ),
        .axi_narrow_rsp_flip_i(axi_s_rsp_flip          ),
    );

    memory_island_wrap #(
        .mem_cfg_t             (l1_mem_cfg_j           )
    ) i_l1_mem_j (
        .clk_i                  (clk_i                 ),
        .rst_ni                 (rst_ni                ),
        .axi_narrow_req_i       (axi_s_req_j           ),
        .axi_narrow_rsp_o       (axi_s_rsp_j           ),
        .axi_wide_req_i         (                      ),
        .axi_wide_rsp_o         (                      ),
        .mem_narrow_req_i       (                      ),
        .mem_narrow_rsp_o       (                      ),
        .mem_wide_req_i         (drt_s_req_j           ),
        .mem_wide_rsp_o         (drt_s_rsp_j           )
    );

    memory_island_wrap #(
    .mem_cfg_t                  (l1_mem_cfg_h          )
    ) i_l1_mem_h (
        .clk_i                  (clk_i                 ),
        .rst_ni                 (rst_ni                ),
        .axi_narrow_req_i       (axi_s_req_h           ),
        .axi_narrow_rsp_o       (axi_s_rsp_h           ),
        .axi_wide_req_i         (                      ),
        .axi_wide_rsp_o         (                      ),
        .mem_narrow_req_i       (                      ),
        .mem_narrow_rsp_o       (                      ),
        .mem_wide_req_i         (drt_s_req_h           ),
        .mem_wide_rsp_o         (drt_s_rsp_h           )
    );

    memory_island_wrap #(
    .mem_cfg_t                  (l1_mem_cfg_flip       )
    ) i_l1_mem_flip (
        .clk_i                  (clk_i                 ),
        .rst_ni                 (rst_ni                ),
        .axi_narrow_req_i       (axi_s_req_flip        ),
        .axi_narrow_rsp_o       (axi_s_rsp_flip        ),
        .axi_wide_req_i         (                      ),
        .axi_wide_rsp_o         (                      ),
        .mem_narrow_req_i       (                      ),
        .mem_narrow_rsp_o       (                      ),
        .mem_wide_req_i         (drt_s_req_flip        ),
        .mem_wide_rsp_o         (drt_s_rsp_flip        )
    );

    //////////////////////////////////////////////////////////
    //Register interface /////////////////////////////////////
    //////////////////////////////////////////////////////////
    // TODO: to be done; and more registers to be added
    reg_interface_wrap #(
        .reg_slv_req_t          (reg_slv_req_t         ),
        .reg_slv_rsp_t          (reg_slv_rsp_t         )
    ) i_reg_interface (
        .clk_i                  (clk_i                 ),
        .rst_ni                 (rst_ni                ),
        // Register slave interface
        .reg_s_req_i            (reg_s_req_i           ),
        .reg_s_rsp_o            (reg_s_rsp_o           ),
        // Internal register interface
        .mode_select_o          (mode_select           ),
        .spin_regfile_o         (spin_regfile          )
    );

    //////////////////////////////////////////////////////////
    // Analog Macro //////////////////////////////////////////
    //////////////////////////////////////////////////////////
    analog_macro_wrap i_analog_macro (
        .wen_i                  (analog_wen            ),
        .waddr_i                (analog_waddr          ),
        .wdata_i                (analog_wdata          ),
        .spin_wen_i             (analog_spin_wen       ),
        .wr_spin_i              (analog_wr_spin        ),
        .compute_en_i           (analog_compute_en     ),
        .rd_spin_vld_o          (analog_spin_vld       ),
        .rd_spin_rdy_i          (analog_spin_rdy       ),
        .rd_spin_o              (analog_spin           )
    );

    //////////////////////////////////////////////////////////
    //Digital weight loading macro ///////////////////////////
    //////////////////////////////////////////////////////////
    digital_weight_load_macro #(
        .num_spin               (logic_cfg.NumSpin     ),
        .bit_j                  (logic_cfg.BitJ        ),
        .bit_h                  (logic_cfg.BitH        )
    ) i_digital_weight_load_macro (
        .clk_i                  (clk_i                 ),
        .rst_ni                 (rst_ni                ),
        // J memory master interface
        .mem_wide_req_j_o       (drt_s_req_load_j      ),
        .mem_wide_rsp_j_i       (drt_s_rsp_load_j      ),
        // H memory master interface
        .mem_wide_req_h_o       (drt_s_req_load_h      ),
        .mem_wide_rsp_h_i       (drt_s_rsp_load_h      ),
        // Register interface
        .mode_select_i          (mode_select           ),
        // Analog macro interface
        .weight_load_en_o       (analog_wen            ),
        .weight_load_addr_o     (analog_waddr          ),
        .weight_load_data_o     (analog_wdata          )
    );

    //////////////////////////////////////////////////////////
    //Digital compute macro //////////////////////////////////
    //////////////////////////////////////////////////////////
    digital_compute_macro #(
        .num_spin               (logic_cfg.NumSpin     ),
        .bit_j                  (logic_cfg.BitJ        ),
        .bit_h                  (logic_cfg.BitH        ),
        .flip_icon_depth        (logic_cfg.FlipIconDepth)
    ) i_digital_compute_macro (
        .clk_i                  (clk_i                 ),
        .rst_ni                 (rst_ni                ),
        // J memory master interface
        .mem_wide_req_j_o       (drt_s_req_compute_j   ),
        .mem_wide_rsp_j_i       (drt_s_rsp_compute_j   ),
        // H memory master interface
        .mem_wide_req_h_o       (drt_s_req_compute_h   ),
        .mem_wide_rsp_h_i       (drt_s_rsp_compute_h   ),
        // Flip memory master interface
        .mem_wide_req_flip_o    (drt_s_req_flip        ),
        .mem_wide_rsp_flip_i    (drt_s_rsp_flip        ),
        // Register interface
        .mode_select_i          (mode_select           ),
        .spin_regfile_i         (spin_regfile          ),
        // Analog macro interface
        .spin_wen_o             (analog_spin_wen       ),
        .wr_spin_o              (analog_wr_spin        ),
        .compute_en_o           (analog_compute_en     ),
        .rd_spin_vld_i          (analog_spin_vld       ),
        .rd_spin_rdy_o          (analog_spin_rdy       ),
        .rd_spin_i              (analog_spin           )
    );

    always_comb begin
        case(mode_select)
            2'b00: begin: idle_mode
                drt_s_req_j         = '0;
                drt_s_req_h         = '0;
                drt_s_rsp_load_j    = '0;
                drt_s_rsp_load_h    = '0;
                drt_s_rsp_compute_j = '0;
                drt_s_rsp_compute_h = '0;
            end
            2'b01: begin: load_mode
                drt_s_req_j         = drt_s_req_load_j;
                drt_s_req_h         = drt_s_req_load_h;
                drt_s_rsp_load_j    = drt_s_rsp_j;
                drt_s_rsp_load_h    = drt_s_rsp_h;
                drt_s_rsp_compute_j = '0;
                drt_s_rsp_compute_h = '0;
            end
            2'b10: begin: compute_mode
                drt_s_req_j         = drt_s_req_compute_j;
                drt_s_req_h         = drt_s_req_compute_h;
                drt_s_rsp_load_j    = '0;
                drt_s_rsp_load_h    = '0;
                drt_s_rsp_compute_j = drt_s_rsp_j;
                drt_s_rsp_compute_h = drt_s_rsp_h;
            end
            2'b11: begin: debug_mode // same as compute mode
                drt_s_req_j         = drt_s_req_compute_j;
                drt_s_req_h         = drt_s_req_compute_h;
                drt_s_rsp_load_j    = '0;
                drt_s_rsp_load_h    = '0;
                drt_s_rsp_compute_j = drt_s_rsp_j;
                drt_s_rsp_compute_h = drt_s_rsp_h;
            end
            default: begin // same as idle mode
                drt_s_req_j         = '0;
                drt_s_req_h         = '0;
                drt_s_rsp_load_j    = '0;
                drt_s_rsp_load_h    = '0;
                drt_s_rsp_compute_j = '0;
                drt_s_rsp_compute_h = '0;
            end
        endcase
    end

endmodule
