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
    parameter type mem_j_req_t = logic,
    parameter type mem_j_rsp_t = logic,
    parameter type mem_f_req_t = logic,
    parameter type mem_f_rsp_t = logic,
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
    output reg_rsp_t reg_s_rsp_o,

    // Galena wires
    inout wire galena_j_iref_i,
    inout wire galena_j_vup_i,
    inout wire galena_j_vdn_i,
    inout wire galena_h_iref_i,
    inout wire galena_h_vup_i,
    inout wire galena_h_vdn_i,
    inout wire galena_vread_i
);
    // Internal signals
    axi_narrow_req_t axi_s_req_j, axi_s_req_flip;
    axi_narrow_rsp_t axi_s_rsp_j, axi_s_rsp_flip;
    axi_narrow_req_t [1:0] axi_xbar_out_req; // 0: j, 1: flip
    axi_narrow_rsp_t [1:0] axi_xbar_out_rsp;  // 0: j, 1: flip
    mem_j_req_t drt_s_req_j;
    mem_j_rsp_t drt_s_rsp_j;
    mem_f_req_t drt_s_req_flip;
    mem_f_rsp_t drt_s_rsp_flip;
    
    // Digital macro input signals
    // registers
    logic flush_en;
    logic en_aw, en_fm, en_em, en_ff, en_ef, en_analog_loop;
    logic en_comparison;
    logic cmpt_en;
    logic config_valid_em;
    logic config_valid_fm;
    logic config_valid_aw;
    logic debug_dt_configure_enable;
    logic debug_spin_configure_enable;
    logic [$clog2(logic_cfg.NumSpin)-1:0] config_counter;
    logic [logic_cfg.NumSpin-1:0] config_spin_initial;
    logic config_spin_initial_skip;
    logic [logic_cfg.CounterBitwidth-1:0] cfg_trans_num;
    logic [logic_cfg.CounterBitwidth-1:0] cycle_per_wwl_high;
    logic [logic_cfg.CounterBitwidth-1:0] cycle_per_wwl_low;
    logic [logic_cfg.CounterBitwidth-1:0] cycle_per_spin_write;
    logic [logic_cfg.CounterBitwidth-1:0] cycle_per_spin_compute;
    logic [logic_cfg.NumSpin:0] wwl_vdd_cfg;
    logic [logic_cfg.NumSpin:0] wwl_vread_cfg;
    logic bypass_data_conversion;
    logic [logic_cfg.NumSpin-1:0] spin_wwl_strobe;
    logic [logic_cfg.NumSpin-1:0] spin_feedback_cfg;
    logic [$clog2(logic_cfg.SynchronizerPipeDepth)-1:0] synchronizer_pipe_num;
    logic [$clog2(logic_cfg.SynchronizerPipeDepth)-1:0] synchronizer_wbl_pipe_num;
    logic dt_cfg_enable;
    logic host_readout;
    logic [logic_cfg.HRegDataBitwidth-1:0] h_rdata, dgt_hbias;
    logic [logic_cfg.FmemAddrBitwidth-1+1:0] icon_last_raddr_plus_one;
    logic flip_disable;
    logic [logic_cfg.ScalingBit-1:0] dgt_hscaling;
    logic [logic_cfg.HRegDataBitwidth-1:0] wbl_floating;
    logic [logic_cfg.JmemAddrBitwidth-1:0] dgt_addr_upper_bound;
    logic enable_flip_detection;
    logic [logic_cfg.CounterBitwidth-1:0] debug_cycle_per_spin_read;
    logic [logic_cfg.CounterBitwidth-1:0] debug_spin_read_num;
    logic debug_j_write_en;
    logic debug_j_read_en;
    logic [logic_cfg.NumSpin-1:0] debug_j_one_hot_wwl;
    logic debug_h_wwl;
    logic debug_spin_write_en;
    logic debug_spin_compute_en;
    logic debug_spin_read_en;
    // memories
    logic [logic_cfg.JmemDataBitwidth-1:0] j_rdata, dgt_weight;
    logic [logic_cfg.NumSpin-1:0] flip_rdata;

    // Digital macro output signals
    // registers
    logic dt_cfg_idle;
    logic cmpt_idle;
    logic signed [logic_cfg.SpinDepth-1:0] [logic_cfg.EnergyTotalBit-1:0] energy_fifo_data;
    logic [logic_cfg.SpinDepth-1:0] [logic_cfg.NumSpin-1:0] spin_fifo_data;
    logic energy_fifo_update;
    logic spin_fifo_update;
    logic debug_j_read_data_valid;
    logic [logic_cfg.HRegDataBitwidth-1:0] debug_j_read_data;
    logic debug_analog_dt_w_idle;
    logic debug_analog_dt_r_idle;
    logic debug_spin_w_idle;
    logic debug_spin_r_idle;
    logic debug_spin_cmpt_idle;
    // memories
    logic j_mem_ren_load;
    logic dgt_weight_ren;
    logic [logic_cfg.JmemAddrBitwidth-1:0] j_raddr_load, dgt_weight_raddr;
    logic flip_ren;
    logic [logic_cfg.FmemAddrBitwidth-1:0] flip_raddr;
    logic debug_spin_valid;
    logic [logic_cfg.FmemAddrBitwidth-1:0] debug_spin_waddr;
    logic [logic_cfg.NumSpin-1:0] debug_spin_out;

    // analog macro signals
    logic [logic_cfg.HRegDataBitwidth-1:0] wbl_in_analog;
    logic [logic_cfg.HRegDataBitwidth-1:0] wblb_in_analog;
    logic [logic_cfg.HRegDataBitwidth-1:0] wbl_floating_in_analog;
    logic [logic_cfg.NumSpin-1:0] j_one_hot_wwl;
    logic h_wwl;
    logic [logic_cfg.NumSpin:0] wwl_vdd_analog;
    logic [logic_cfg.NumSpin:0] wwl_vread_analog;
    logic [logic_cfg.NumSpin-1:0] spin_wwl;
    logic [logic_cfg.NumSpin-1:0] spin_feedback_in_analog;
    logic [logic_cfg.HRegDataBitwidth-1:0] debug_wbl_in;
    logic [logic_cfg.NumSpin-1:0] spin_out_analog;

    $info("Instantiating ising digital macro with parameters: NumSpin=%d, BitJ=%d, BitH=%d",
        logic_cfg.NumSpin, logic_cfg.BitJ,  logic_cfg.BitH);

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

    // axi_xbar #(
    // .Cfg                   (xbar_cfg               ),
    // .Connectivity          ('1                     ),
    // .ATOPs                 (0                      ),
    // .slv_aw_chan_t         (axi_slv_aw_chan_t      ),
    // .mst_aw_chan_t         (axi_slv_aw_chan_t      ),
    // .w_chan_t              (axi_slv_w_chan_t       ),
    // .slv_b_chan_t          (axi_slv_b_chan_t       ),
    // .mst_b_chan_t          (axi_slv_b_chan_t       ),
    // .slv_ar_chan_t         (axi_slv_ar_chan_t      ),
    // .mst_ar_chan_t         (axi_slv_ar_chan_t      ),
    // .slv_r_chan_t          (axi_slv_r_chan_t       ),
    // .mst_r_chan_t          (axi_slv_r_chan_t       ),
    // .slv_req_t             (axi_slv_req_t          ),
    // .slv_resp_t            (axi_slv_rsp_t          ),
    // .mst_req_t             (axi_slv_req_t          ),
    // .mst_resp_t            (axi_slv_rsp_t          ),
    // .rule_t                (rule_t                 )
    // ) i_axi_xbar ( 
    // .clk_i                 (clk_i                  ),
    // .rst_ni                (rst_ni                 ),
    // .test_i                (1'b0                   ),
    // .slv_ports_req_i       (axi_s_req_i            ),
    // .slv_ports_resp_o      (axi_s_rsp_o            ),
    // .mst_ports_req_o       (axi_xbar_out_req       ),
    // .mst_ports_resp_i      (axi_xbar_out_rsp       ),
    // .addr_map_i            (AddrMap                ),
    // .en_default_mst_port_i ('0                     ),
    // .default_mst_port_i    ('0                     )
    // );

    // L1 memory instances
    memory_island_wrap #(
        .Cfg                   (l1_mem_cfg_j           ),
        .axi_narrow_req_t      (axi_narrow_req_t       ),
        .axi_narrow_rsp_t      (axi_narrow_rsp_t       ),
        .axi_wide_req_t        (axi_wide_req_t         ),
        .axi_wide_rsp_t        (axi_wide_rsp_t         ),
        .mem_narrow_req_t      (mem_narrow_req_t       ),
        .mem_narrow_rsp_t      (mem_narrow_rsp_t       ),
        .mem_wide_req_t        (mem_j_req_t         ),
        .mem_wide_rsp_t        (mem_j_rsp_t         )
    ) i_l1_mem_j (
        .clk_i                  (clk_i                 ),
        .rst_ni                 (rst_ni                ),
        .axi_narrow_req_i       (axi_s_req_i           ), // todo: connnect to axi_s_req_j
        .axi_narrow_rsp_o       (axi_s_rsp_o           ), // todo: connnect to axi_s_rsp_j
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
        .mem_wide_req_t        (mem_f_req_t         ),
        .mem_wide_rsp_t        (mem_f_rsp_t         )
    ) i_l1_mem_flip (
        .clk_i                  (clk_i                 ),
        .rst_ni                 (rst_ni                ),
        .axi_narrow_req_i       (axi_s_req_i           ), // todo: connnect to axi_s_req_flip
        .axi_narrow_rsp_o       (axi_s_rsp_o           ), // todo: connnect to axi_s_rsp_flip
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
    galena_256 u_galena (
        .wbl_i                   (wbl_in_analog         ),
        .wblb_i                  (wblb_in_analog        ),
        .wbl_floating_i          (wbl_floating_in_analog),
        .wwl_i                   ({h_wwl, j_one_hot_wwl}),
        .wwl_vdd_i               (wwl_vdd_analog        ),
        .wwl_vread_i             (wwl_vread_analog      ),
        .write_spin_i            (spin_wwl              ),
        .feedback_i              (spin_feedback_in_analog),
        .wbl_read_o              (debug_wbl_in          ),
        .wblb_read_o             (                      ),
        .bct_read_o              (spin_out_analog       ),
        // Galena wires
        .j_iref_aio              (galena_j_iref_i       ),
        .j_vup_aio               (galena_j_vup_i        ),
        .j_vdn_aio               (galena_j_vdn_i        ),
        .h_iref_aio              (galena_h_iref_i       ),
        .h_vup_aio               (galena_h_vup_i        ),
        .h_vdn_aio               (galena_h_vdn_i        ),
        .vread_aio               (galena_vread_i        )
    );

    //////////////////////////////////////////////////////////
    // Digital Macro /////////////////////////////////////////
    //////////////////////////////////////////////////////////
    digital_macro #(
        .BITJ                       (logic_cfg.BitJ                   ),
        .BITH                       (logic_cfg.BitH                   ),
        .NUM_SPIN                   (logic_cfg.NumSpin                ),
        .SCALING_BIT                (logic_cfg.ScalingBit             ),
        .PARALLELISM                (logic_cfg.Parallelism            ),
        .ENERGY_TOTAL_BIT           (logic_cfg.EnergyTotalBit         ),
        .LITTLE_ENDIAN              (logic_cfg.LittleEndian           ),
        .PIPESINTF                  (logic_cfg.PipesIntf              ),
        .PIPESMID                   (logic_cfg.PipesMid               ),
        .PIPESFLIPFILTER            (logic_cfg.PipesFlipFilter        ),
        .SPIN_DEPTH                 (logic_cfg.SpinDepth              ),
        .FLIP_ICON_DEPTH            (logic_cfg.FlipIconDepth          ),
        .COUNTER_BITWIDTH           (logic_cfg.CounterBitwidth        ),
        .SYNCHRONIZER_PIPEDEPTH     (logic_cfg.SynchronizerPipeDepth  ),
        .SPIN_WBL_OFFSET            (logic_cfg.SpinWblOffset          ),
        .H_IS_NEGATIVE              (logic_cfg.HIsNegative            ),
        .ENABLE_FLIP_DETECTION      (logic_cfg.EnableFlipDetection    )
    ) u_digital_macro (
        .clk_i                      (clk_i                            ),
        .rst_ni                     (rst_ni                           ),
        .en_aw_i                    (en_aw                            ),
        .en_em_i                    (en_em                            ),
        .en_ff_i                    (en_ff                            ),
        .en_fm_i                    (en_fm                            ),
        .en_ef_i                    (en_ef                            ),
        .en_analog_loop_i           (en_analog_loop                   ),
        .config_valid_em_i          (config_valid_em                  ),
        .config_valid_fm_i          (config_valid_fm                  ),
        .config_valid_aw_i          (config_valid_aw                  ),
        .debug_dt_configure_enable_i(debug_dt_configure_enable        ),
        .debug_spin_configure_enable_i(debug_spin_configure_enable    ),
        .config_counter_i           (config_counter                   ),
        .config_spin_initial_i      (config_spin_initial              ),
        .config_spin_initial_skip_i (config_spin_initial_skip         ),
        .cfg_trans_num_i            (cfg_trans_num                    ),
        .cycle_per_wwl_high_i       (cycle_per_wwl_high               ),
        .cycle_per_wwl_low_i        (cycle_per_wwl_low                ),
        .cycle_per_spin_write_i     (cycle_per_spin_write             ),
        .cycle_per_spin_compute_i   (cycle_per_spin_compute           ),
        .wwl_vdd_i                  (wwl_vdd_cfg                      ),
        .wwl_vread_i                (wwl_vread_cfg                    ),
        .bypass_data_conversion_i   (bypass_data_conversion           ),
        .spin_wwl_strobe_i          (spin_wwl_strobe                  ),
        .spin_feedback_i            (spin_feedback_cfg                ),
        .synchronizer_pipe_num_i    (synchronizer_pipe_num            ),
        .synchronizer_wbl_pipe_num_i(synchronizer_wbl_pipe_num        ),
        .debug_cycle_per_spin_read_i(debug_cycle_per_spin_read        ),
        .debug_spin_read_num_i      (debug_spin_read_num              ),
        .dt_cfg_enable_i            (dt_cfg_enable                    ),
        .j_mem_ren_o                (j_mem_ren_load                   ),
        .j_raddr_o                  (j_raddr_load                     ),
        .j_rdata_i                  (j_rdata                          ),
        .h_ren_o                    (                                 ),
        .h_rdata_i                  (h_rdata                          ),
        .dt_cfg_idle_o              (dt_cfg_idle                      ),
        .flush_i                    (flush_en                         ),
        .en_comparison_i            (en_comparison                    ),
        .cmpt_en_i                  (cmpt_en                          ),
        .cmpt_idle_o                (cmpt_idle                        ),
        .host_readout_i             (host_readout                     ),
        .flip_ren_o                 (flip_ren                         ),
        .flip_raddr_o               (flip_raddr                       ),
        .icon_last_raddr_plus_one_i (icon_last_raddr_plus_one         ),
        .flip_rdata_i               (flip_rdata                       ),
        .flip_disable_i             (flip_disable                     ),
        .dgt_weight_ren_o           (dgt_weight_ren                   ),
        .dgt_weight_raddr_o         (dgt_weight_raddr                 ),
        .dgt_addr_upper_bound_i     (dgt_addr_upper_bound             ),
        .dgt_weight_i               (dgt_weight                       ),
        .dgt_hbias_i                (dgt_hbias                        ),
        .dgt_hscaling_i             (dgt_hscaling                     ),
        .j_one_hot_wwl_o            (j_one_hot_wwl                    ),
        .h_wwl_o                    (h_wwl                            ),
        .wbl_o                      (wbl_in_analog                    ),
        .wblb_o                     (wblb_in_analog                   ),
        .wbl_read_i                 (debug_wbl_in                     ),
        .wblb_read_i                (                                 ),
        .wbl_floating_o             (wbl_floating_in_analog           ),
        .wwl_vdd_o                  (wwl_vdd_analog                   ),
        .wwl_vread_o                (wwl_vread_analog                 ),
        .spin_wwl_o                 (spin_wwl                         ),
        .spin_feedback_o            (spin_feedback_in_analog          ),
        .spin_analog_i              (spin_out_analog                  ),
        .energy_fifo_update_o       (energy_fifo_update               ),
        .spin_fifo_update_o         (spin_fifo_update                 ),
        .energy_fifo_o              (energy_fifo_data                 ),
        .spin_fifo_o                (spin_fifo_data                   ),
        .enable_flip_detection_i    (enable_flip_detection            ),
        // debugging interface
        .debug_j_write_en_i         (debug_j_write_en                 ),
        .debug_j_read_en_i          (debug_j_read_en                  ),
        .debug_j_one_hot_wwl_i      (debug_j_one_hot_wwl              ),
        .debug_h_wwl_i              (debug_h_wwl                      ),
        .debug_wbl_i                (debug_wbl_in                     ),
        .debug_j_read_data_o        (debug_j_read_data                ),
        .debug_j_read_data_valid_o  (debug_j_read_data_valid          ),
        .debug_spin_write_en_i      (debug_spin_write_en              ),
        .wbl_floating_i             (wbl_floating                     ),
        .debug_spin_compute_en_i    (debug_spin_compute_en            ),
        .debug_spin_read_en_i       (debug_spin_read_en               ),
        .debug_spin_valid_o         (debug_spin_valid                 ),
        .debug_spin_waddr_o         (debug_spin_waddr                 ),
        .debug_spin_o               (debug_spin_out                   ),
        .debug_analog_dt_w_idle_o   (debug_analog_dt_w_idle           ),
        .debug_analog_dt_r_idle_o   (debug_analog_dt_r_idle           ),
        .debug_spin_w_idle_o        (debug_spin_w_idle                ),
        .debug_spin_cmpt_idle_o     (debug_spin_cmpt_idle             ),
        .debug_spin_r_idle_o        (debug_spin_r_idle                )
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
        case(dt_cfg_enable)
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
                drt_s_req_j.q.addr         = dgt_weight_raddr;
                drt_s_req_j.q.write        = 1'b0;
                drt_s_req_j.q.data         = '0;
                drt_s_req_j.q.strb         = {(`IC_L1_J_MEM_DATA_WIDTH/8){1'b1}};
                drt_s_req_j.q.user         = '0;
                drt_s_req_j.q_valid        = dgt_weight_ren;
                dgt_weight                 = drt_s_rsp_j.p.data;
                // drt_s_rsp_j.q_ready        = 1'b1; // not sure how to use this signal
                // drt_s_rsp_j.p.valid        = 1'b1; // not used yet
            end
        endcase
    end

endmodule
