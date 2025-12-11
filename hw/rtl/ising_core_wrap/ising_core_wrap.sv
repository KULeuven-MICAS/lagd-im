// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Ising core wrapper

`include "lagd_define.svh"
`include "lagd_config.svh"
`include "lagd_typedef.svh"

module ising_core_wrap import axi_pkg::*; import memory_island_pkg::*; import ising_logic_pkg::*; import lagd_pkg::*; #(
    parameter mem_cfg_t l1_mem_cfg_j = '0,
    parameter mem_cfg_t l1_mem_cfg_flip = '0,
    parameter ising_logic_cfg_t logic_cfg = '0,
    parameter type axi_slv_req_t = logic,
    parameter type axi_slv_rsp_t = logic,
    parameter type axi_narrow_req_t = logic,
    parameter type axi_narrow_rsp_t = logic,
    parameter type axi_wide_req_t = logic,
    parameter type axi_wide_rsp_t = logic,
    parameter type mem_narrow_req_t = logic,
    parameter type mem_narrow_rsp_t = logic,
    parameter type mem_wide_req_t = logic,
    parameter type mem_wide_rsp_t = logic,
    parameter type axi_slv_aw_chan_t = logic,
    parameter type axi_slv_w_chan_t = logic,
    parameter type axi_slv_b_chan_t = logic,
    parameter type axi_slv_ar_chan_t = logic,
    parameter type axi_slv_r_chan_t = logic,
    parameter type reg_req_t = logic,
    parameter type reg_rsp_t = logic
)(
    input logic clk_i,
    input logic rst_ni,

    // AXI slave interface
    input axi_slv_req_t [0:0] axi_s_req_i,
    output axi_slv_rsp_t [0:0] axi_s_rsp_o,

    // Register slave interface
    input reg_req_t reg_s_req_i,
    output reg_rsp_t reg_s_rsp_o
);
    // Internal signals
    logic mode_select; // 0: weight loading. 1: computing. (to be connected to reg interface)
    axi_narrow_req_t axi_s_req_j, axi_s_req_flip;
    axi_narrow_rsp_t axi_s_rsp_j, axi_s_rsp_flip;
    axi_narrow_req_t [1:0] axi_xbar_out_req; // 0: j, 1: flip
    axi_narrow_rsp_t [1:0] axi_xbar_out_rsp;  // 0: j, 1: flip
    mem_wide_req_t drt_s_req_j;
    mem_wide_rsp_t drt_s_rsp_j;
    mem_wide_req_t drt_s_req_flip;
    mem_wide_rsp_t drt_s_rsp_flip;
    logic [logic_cfg.NumSpin-1:0] spin_regfile;
    
    // Digital macro interface signals
    logic en_i;
    logic j_mem_ren_load;
    logic weight_ren;
    logic h_ren;
    logic sfc_ren;
    logic [$clog2(logic_cfg.NumSpin/logic_cfg.Parallelism)-1:0] j_raddr_load, weight_raddr;
    logic [logic_cfg.NumSpin*logic_cfg.BitJ*logic_cfg.Parallelism-1:0] j_rdata, weight;
    logic [logic_cfg.BitH*logic_cfg.NumSpin-1:0] h_rdata, hbias;
    logic [logic_cfg.ScalingBit-1:0] sfc_rdata, hscaling;
    logic en_comparison, cmpt_en, cmpt_idle, host_readout;
    logic flip_ren, flip_disable;
    logic [$clog2(logic_cfg.FlipIconDepth)+1-1:0] flip_raddr, icon_last_raddr_plus_one;
    logic [logic_cfg.NumSpin-1:0] flip_rdata;

    logic [logic_cfg.NumSpin * logic_cfg.BitJ-1:0] analog_wbl;
    logic [logic_cfg.NumSpin-1:0] analog_dt_j_wwl;
    logic analog_dt_h_wwl;
    logic [logic_cfg.NumSpin-1:0] spin_wwl;
    logic [logic_cfg.NumSpin-1:0] spin_compute_mode;
    logic [logic_cfg.NumSpin-1:0] analog_spin_output;

    ////////
    // This is a temporary implementation
    ////////
    assign mode_select = 1'b1;

    //////////////////////////////////////////////////////////
    // L1 memory, with narrow and direct access //////////////
    //////////////////////////////////////////////////////////
    // Configuration of the AXI crossbar
    localparam axi_pkg::xbar_cfg_t xbar_cfg = '{
        NoSlvPorts         : 1,
        NoMstPorts         : 2,
        MaxMstTrans        : 1,
        MaxSlvTrans        : 1,
        FallThrough        : 1'b0,
        LatencyMode        : 10'b111_11_111_11,
        PipelineStages     : 0,
        AxiIdWidthSlvPorts : `LAGD_AXI_ID_WIDTH,
        AxiIdUsedSlvPorts  : `LAGD_AXI_ID_WIDTH+1,
        UniqueIds          : 1'b0,
        AxiAddrWidth       : `CVA6_ADDR_WIDTH,
        AxiDataWidth       : `LAGD_AXI_DATA_WIDTH,
        NoAddrRules        : 2
    };

    // Define the xbar rule type
    typedef struct packed {
        logic [31:0] idx;
        logic [`CVA6_ADDR_WIDTH-1:0] start_addr;
        logic [`CVA6_ADDR_WIDTH-1:0] end_addr;
    } rule_t;

    localparam rule_t [xbar_cfg.NoAddrRules-1:0] AddrMap = '{
        '{idx: 0, start_addr: `IC_MEM_BASE_ADDR, end_addr: `IC_J_MEM_END_ADDR-1},
        '{idx: 1, start_addr: `IC_J_MEM_END_ADDR, end_addr: `IC_FLIP_MEM_END_ADDR-1}
    };

    assign axi_s_req_j = axi_xbar_out_req[0];
    assign axi_s_req_flip = axi_xbar_out_req[1];
    assign axi_xbar_out_rsp[0] = axi_s_rsp_j;
    assign axi_xbar_out_rsp[1] = axi_s_rsp_flip;

    axi_xbar #(
    .Cfg                   (xbar_cfg               ),
    .Connectivity          ('1                     ),
    .ATOPs                 (0                      ),
    .slv_aw_chan_t         (axi_slv_aw_chan_t      ),
    .mst_aw_chan_t         (axi_slv_aw_chan_t      ),
    .w_chan_t              (axi_slv_w_chan_t       ),
    .slv_b_chan_t          (axi_slv_b_chan_t       ),
    .mst_b_chan_t          (axi_slv_b_chan_t       ),
    .slv_ar_chan_t         (axi_slv_ar_chan_t      ),
    .mst_ar_chan_t         (axi_slv_ar_chan_t      ),
    .slv_r_chan_t          (axi_slv_r_chan_t       ),
    .mst_r_chan_t          (axi_slv_r_chan_t       ),
    .slv_req_t             (axi_slv_req_t          ),
    .slv_resp_t            (axi_slv_rsp_t          ),
    .mst_req_t             (axi_slv_req_t          ),
    .mst_resp_t            (axi_slv_rsp_t          ),
    .rule_t                (rule_t                 )
    ) i_axi_xbar ( 
    .clk_i                 (clk_i                  ),
    .rst_ni                (rst_ni                 ),
    .test_i                (1'b0                   ),
    .slv_ports_req_i       (axi_s_req_i            ),
    .slv_ports_resp_o      (axi_s_rsp_o            ),
    .mst_ports_req_o       (axi_xbar_out_req       ),
    .mst_ports_resp_i      (axi_xbar_out_rsp       ),
    .addr_map_i            (AddrMap                ),
    .en_default_mst_port_i ('0                     ),
    .default_mst_port_i    ('0                     )
    );

    // L1 memory instances
    memory_island_wrap #(
        .Cfg                   (l1_mem_cfg_j           ),
        .axi_narrow_req_t      (axi_narrow_req_t       ),
        .axi_narrow_rsp_t      (axi_narrow_rsp_t       ),
        .axi_wide_req_t        (axi_wide_req_t         ),
        .axi_wide_rsp_t        (axi_wide_rsp_t         ),
        .mem_narrow_req_t      (mem_narrow_req_t       ),
        .mem_narrow_rsp_t      (mem_narrow_rsp_t       ),
        .mem_wide_req_t        (mem_wide_req_t         ),
        .mem_wide_rsp_t        (mem_wide_rsp_t         )
    ) i_l1_mem_j (
        .clk_i                  (clk_i                 ),
        .rst_ni                 (rst_ni                ),
        .axi_narrow_req_i       (axi_s_req_j           ),
        .axi_narrow_rsp_o       (axi_s_rsp_j           ),
        .axi_wide_req_i         ('0                    ),
        .axi_wide_rsp_o         (                      ),
        .mem_narrow_req_i       (                      ),
        .mem_narrow_rsp_o       ('0                    ),
        .mem_wide_req_i         (drt_s_req_j           ),
        .mem_wide_rsp_o         (drt_s_rsp_j           )
    );

    memory_island_wrap #(
        .Cfg                   (l1_mem_cfg_flip        ),
        .axi_narrow_req_t      (axi_narrow_req_t       ),
        .axi_narrow_rsp_t      (axi_narrow_rsp_t       ),
        .axi_wide_req_t        (axi_wide_req_t         ),
        .axi_wide_rsp_t        (axi_wide_rsp_t         ),
        .mem_narrow_req_t      (mem_narrow_req_t       ),
        .mem_narrow_rsp_t      (mem_narrow_rsp_t       ),
        .mem_wide_req_t        (mem_wide_req_t         ),
        .mem_wide_rsp_t        (mem_wide_rsp_t         )
    ) i_l1_mem_flip (
        .clk_i                  (clk_i                 ),
        .rst_ni                 (rst_ni                ),
        .axi_narrow_req_i       (axi_s_req_flip        ),
        .axi_narrow_rsp_o       (axi_s_rsp_flip        ),
        .axi_wide_req_i         ('0                    ),
        .axi_wide_rsp_o         (                      ),
        .mem_narrow_req_i       (                      ),
        .mem_narrow_rsp_o       ('0                    ),
        .mem_wide_req_i         (drt_s_req_flip        ),
        .mem_wide_rsp_o         (drt_s_rsp_flip        )
    );

    //////////////////////////////////////////////////////////
    // Analog Macro //////////////////////////////////////////
    //////////////////////////////////////////////////////////
    galena_256 #(
        .ArraySize              (logic_cfg.NumSpin     ),
        .WordWidth              (logic_cfg.BitJ        )
    ) u_galena (
        .vdd_aio                (                      ),
        .vss_aio                (                      ),
        .iref_aio               (                      ),
        .vup_aio                (                      ),
        .vdn_aio                (                      ),
        .wdata_i                (analog_wbl            ), // wbl
        .write_cu_i             (analog_dt_j_wwl       ), // dt_j_wwl
        .write_h_i              (analog_dt_h_wwl       ), // dt_h_wwl
        .write_au_i             (spin_wwl              ), // spin_wwl
        .cont_en_i              (spin_compute_mode     ), // spin mode
        .spins_o                (analog_spin_output    )
    );

    //////////////////////////////////////////////////////////
    // Digital Macro /////////////////////////////////////////
    //////////////////////////////////////////////////////////
    $info("Instantiating ising digital macro with parameters: NumSpin=%d, BitJ=%d, BitH=%d",
        logic_cfg.NumSpin, logic_cfg.BitJ,  logic_cfg.BitH);
    digital_macro #(
        .bit_j                  (logic_cfg.BitJ                   ),
        .bit_h                  (logic_cfg.BitH                   ),
        .num_spin               (logic_cfg.NumSpin                ),
        .scaling_bit            (logic_cfg.ScalingBit             ),
        .parallelism            (logic_cfg.Parallelism            ),
        .energy_total_bit       (logic_cfg.EnergyTotalBit         ),
        .little_endian          (logic_cfg.LittleEndian           ),
        .pipesintf              (logic_cfg.PipesIntf              ),
        .pipesmid               (logic_cfg.PipesMid               ),
        .spin_depth             (logic_cfg.SpinDepth              ),
        .flip_icon_depth        (logic_cfg.FlipIconDepth          ),
        .counter_bitwidth       (logic_cfg.CfgCounterBitwidth     ),
        .synchronizer_pipe_depth(logic_cfg.SynchronizerPipeDepth  )
    ) u_digital_macro (
        .clk_i                     (clk_i                         ),
        .rst_ni                    (rst_ni                        ),
        .en_i                      (en_i                          ),
        .config_valid_em_i         (1'b0                          ), // to be connected to reg interface
        .config_valid_fm_i         (1'b0                          ), // to be connected to reg interface
        .config_valid_aw_i         (1'b0                          ), // to be connected to reg interface
        .config_counter_i          (                              ), // to be connected to reg interface
        .config_spin_initial_i     (                              ), // to be connected to reg interface
        .config_spin_initial_skip_i(                              ), // to be connected to reg interface
        .cfg_trans_num_i           (                              ), // to be connected to reg interface
        .cycle_per_dt_write_i      (                              ), // to be connected to reg interface
        .cycle_per_spin_write_i    (                              ), // to be connected to reg interface
        .cycle_per_spin_compute_i  (                              ), // to be connected to reg interface
        .spin_wwl_strobe_i         (                              ), // to be connected to reg interface
        .spin_mode_i               (                              ), // to be connected to reg interface
        .synchronizer_pipe_num_i   (2'b11                         ), // to be connected to reg interface
        .synchronizer_mode_i       (1'b0                          ), // to be connected to reg interface
        .dt_cfg_enable_i           (1'b0                          ), // to be connected to reg interface
        .j_mem_ren_o               (j_mem_ren_load                ),
        .j_raddr_o                 (j_raddr_load                  ),
        .j_rdata_i                 (j_rdata                       ),
        .h_ren_o                   (h_ren                         ),
        .h_rdata_i                 (h_rdata                       ),
        .sfc_ren_o                 (sfc_ren                       ),
        .sfc_rdata_i               (sfc_rdata                     ),
        .flush_i                   (                              ), // to be connected to reg interface
        .en_comparison_i           (en_comparison                 ),
        .cmpt_en_i                 (cmpt_en                       ),
        .cmpt_idle_o               (cmpt_idle                     ),
        .host_readout_i            (host_readout                  ),
        .flip_ren_o                (flip_ren                      ),
        .flip_raddr_o              (flip_raddr                    ),
        .icon_last_raddr_plus_one_i(icon_last_raddr_plus_one      ),
        .flip_rdata_i              (flip_rdata                    ),
        .flip_disable_i            (flip_disable                  ),
        .weight_ren_o              (weight_ren                    ),
        .weight_raddr_o            (weight_raddr                  ),
        .weight_i                  (weight                        ),
        .hbias_i                   (hbias                         ),
        .hscaling_i                (hscaling                      ),
        .j_one_hot_wwl_o           (analog_dt_j_wwl               ),
        .h_wwl_o                   (analog_dt_h_wwl               ),
        .sfc_wwl_o                 (                              ), // not used in current version
        .wbl_o                     (analog_wbl                    ),
        .spin_wwl_o                (spin_wwl                      ),
        .spin_compute_en_o         (spin_compute_mode             ),
        .analog_spin_i             (analog_spin_output            )
    );


    always_comb begin
        drt_s_req_flip.q.addr          = flip_raddr;
        drt_s_req_flip.q.write         = '0;
        drt_s_req_flip.q.data          = '0;
        drt_s_req_flip.q.strb          = {(`IC_L1_FLIP_MEM_DATA_WIDTH/8){1'b1}};
        drt_s_req_flip.q.user          = '0;
        drt_s_req_flip.q_valid         = flip_ren;
        flip_rdata                     = drt_s_rsp_flip.p.data;
        // drt_s_rsp_flip.q_ready; // not sure how to use this signal
        // drt_s_rsp_flip.p.valid; // not used yet
    end

    always_comb begin
        case(mode_select)
            1'b0: begin: load_mode
                drt_s_req_j.q.addr         = j_raddr_load;
                drt_s_req_j.q.write        = 1'b0;
                drt_s_req_j.q.data         = '0;
                drt_s_req_j.q.strb         = {(`IC_L1_J_MEM_DATA_WIDTH/8){1'b1}};
                drt_s_req_j.q.user         = '0;
                drt_s_req_j.q_valid        = j_mem_ren_load;
                j_rdata                    = drt_s_rsp_j.p.data;
                // drt_s_rsp_j.q_ready        = 1'b1; // not sure how to use this signal
                // drt_s_rsp_j.p.valid        = 1'b1; // not used yet
            end
            1'b1: begin: compute_mode
                drt_s_req_j.q.addr         = weight_raddr;
                drt_s_req_j.q.write        = 1'b0;
                drt_s_req_j.q.data         = '0;
                drt_s_req_j.q.strb         = {(`IC_L1_J_MEM_DATA_WIDTH/8){1'b1}};
                drt_s_req_j.q.user         = '0;
                drt_s_req_j.q_valid        = weight_ren;
                weight                     = drt_s_rsp_j.p.data;
                // drt_s_rsp_j.q_ready        = 1'b1; // not sure how to use this signal
                // drt_s_rsp_j.p.valid        = 1'b1; // not used yet
            end
        endcase
    end

endmodule
