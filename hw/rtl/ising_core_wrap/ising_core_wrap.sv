// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Ising core wrapper

`include "lagd_define.svh"
`include "lagd_config.svh"
`include "lagd_typedef.svh"

module ising_core_wrap import axi_pkg::*; import memory_island_pkg::*; import ising_logic_pkg::*; import lagd_pkg::*; import lagd_core_reg_pkg::*; #(
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
    input  axi_slv_req_t axi_s_req_0_i,
    output axi_slv_rsp_t axi_s_rsp_0_o,
    input  axi_slv_req_t axi_s_req_1_i,
    output axi_slv_rsp_t axi_s_rsp_1_o,

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
    mem_j_req_t drt_s_req_j;
    mem_j_rsp_t drt_s_rsp_j;
    mem_f_req_t drt_s_req_flip;
    mem_f_rsp_t drt_s_rsp_flip;

    // Register interface signals
    lagd_core_reg_pkg::lagd_core_reg2hw_t reg2hw;
    lagd_core_reg_pkg::lagd_core_hw2reg_t hw2reg;
    
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
    logic ctnus_fifo_read;
    logic ctnus_dgt_debug;
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
    logic debug_fm_upstream_handshake;
    logic [logic_cfg.EnergyTotalBit-1:0] debug_fm_energy_input;
    logic debug_fm_downstream_handshake;
    logic [logic_cfg.NumSpin-1:0] debug_fm_spin_out;
    logic debug_aw_downstream_handshake;
    logic [logic_cfg.NumSpin-1:0] debug_aw_spin_out;
    logic debug_em_upstream_handshake;
    logic [logic_cfg.NumSpin-1:0] debug_em_spin_in;
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
    // L1 memory instances
    memory_island_wrap #(
        .Cfg                   (l1_mem_cfg_j           ),
        .axi_narrow_req_t      (axi_narrow_req_t       ),
        .axi_narrow_rsp_t      (axi_narrow_rsp_t       ),
        .axi_wide_req_t        (axi_wide_req_t         ),
        .axi_wide_rsp_t        (axi_wide_rsp_t         ),
        .mem_narrow_req_t      (mem_narrow_req_t       ),
        .mem_narrow_rsp_t      (mem_narrow_rsp_t       ),
        .mem_wide_req_t        (mem_j_req_t            ),
        .mem_wide_rsp_t        (mem_j_rsp_t            )
    ) i_l1_mem_j (
        .clk_i                  (clk_i                 ),
        .rst_ni                 (rst_ni                ),
        .axi_narrow_req_i       (axi_s_req_0_i         ),
        .axi_narrow_rsp_o       (axi_s_rsp_0_o         ),
        .axi_wide_req_i         ('0                    ),
        .axi_wide_rsp_o         (                      ),
        .mem_narrow_req_i       ('0                    ),
        .mem_narrow_rsp_o       (                      ),
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
        .mem_wide_req_t        (mem_f_req_t            ),
        .mem_wide_rsp_t        (mem_f_rsp_t            )
    ) i_l1_mem_flip (
        .clk_i                  (clk_i                 ),
        .rst_ni                 (rst_ni                ),
        .axi_narrow_req_i       (axi_s_req_1_i         ),
        .axi_narrow_rsp_o       (axi_s_rsp_1_o         ),
        .axi_wide_req_i         ('0                    ),
        .axi_wide_rsp_o         (                      ),
        .mem_narrow_req_i       ('0                    ),
        .mem_narrow_rsp_o       (                      ),
        .mem_wide_req_i         (drt_s_req_flip        ),
        .mem_wide_rsp_o         (drt_s_rsp_flip        )
    );

    //////////////////////////////////////////////////////////
    // Register Intf /////////////////////////////////////////
    //////////////////////////////////////////////////////////
    lagd_core_reg_top #(
        .reg_req_t             (reg_req_t              ),
        .reg_rsp_t             (reg_rsp_t              )
    ) u_lagd_core_reg_top (
        .clk_i                 (clk_i                  ),
        .rst_ni                (rst_ni                 ),
        .reg_req_i             (reg_s_req_i            ),
        .reg_rsp_o             (reg_s_rsp_o            ),
        // To HW
        .reg2hw                (reg2hw                 ), // Write
        .hw2reg                (hw2reg                 ), // Read
        .devmode_i             (1'b1                   )  // If 1, explicit error return for unmapped register access
    );

    // Unpack register signals
    // reg2hw
    assign flush_en                         = reg2hw.global_cfg_1.flush_en.q;
    assign en_aw                            = reg2hw.global_cfg_1.en_aw.q;
    assign en_fm                            = reg2hw.global_cfg_1.en_fm.q;
    assign en_em                            = reg2hw.global_cfg_1.en_em.q;
    assign en_ff                            = reg2hw.global_cfg_1.en_ff.q;
    assign en_ef                            = reg2hw.global_cfg_1.en_ef.q;
    assign en_analog_loop                   = reg2hw.global_cfg_1.en_analog_loop.q;
    assign en_comparison                    = reg2hw.global_cfg_1.en_comparison.q;
    assign debug_dt_configure_enable        = reg2hw.global_cfg_1.debug_dt_configure_enable.q;
    assign debug_spin_configure_enable      = reg2hw.global_cfg_1.debug_spin_configure_enable.q;
    assign config_spin_initial_skip         = reg2hw.global_cfg_1.config_spin_initial_skip.q;
    assign bypass_data_conversion           = reg2hw.global_cfg_1.bypass_data_conversion.q;
    assign host_readout                     = reg2hw.global_cfg_1.host_readout.q;
    assign flip_disable                     = reg2hw.global_cfg_1.flip_disable.q;
    assign enable_flip_detection            = reg2hw.global_cfg_1.enable_flip_detection.q;
    assign debug_j_write_en                 = reg2hw.global_cfg_1.debug_j_write_en.q;
    assign debug_j_read_en                  = reg2hw.global_cfg_1.debug_j_read_en.q;
    assign debug_spin_write_en              = reg2hw.global_cfg_1.debug_spin_write_en.q;
    assign debug_spin_compute_en            = reg2hw.global_cfg_1.debug_spin_compute_en.q;
    assign debug_spin_read_en               = reg2hw.global_cfg_1.debug_spin_read_en.q;
    assign config_counter                   = reg2hw.global_cfg_1.config_counter.q;
    assign synchronizer_wbl_pipe_num        = reg2hw.global_cfg_1.synchronizer_wbl_pipe_num.q;

    assign cmpt_en                          = reg2hw.global_cfg_2.cmpt_en.q;
    assign config_valid_aw                  = reg2hw.global_cfg_2.config_valid_aw.q;
    assign config_valid_em                  = reg2hw.global_cfg_2.config_valid_em.q;
    assign config_valid_fm                  = reg2hw.global_cfg_2.config_valid_fm.q;
    assign dt_cfg_enable                    = reg2hw.global_cfg_2.dt_cfg_enable.q;
    assign synchronizer_pipe_num            = reg2hw.global_cfg_2.synchronizer_pipe_num.q;
    assign debug_h_wwl                      = reg2hw.global_cfg_2.debug_h_wwl.q;
    assign dgt_addr_upper_bound             = reg2hw.global_cfg_2.dgt_addr_upper_bound.q;
    assign ctnus_fifo_read                  = reg2hw.global_cfg_2.ctnus_fifo_read.q;
    assign ctnus_dgt_debug                  = reg2hw.global_cfg_2.ctnus_dgt_debug.q;

    assign cfg_trans_num                    = reg2hw.counter_cfg_1.cfg_trans_num.q;
    assign cycle_per_wwl_high               = reg2hw.counter_cfg_1.cycle_per_wwl_high.q;
    assign cycle_per_wwl_low                = reg2hw.counter_cfg_2.cycle_per_wwl_low.q;
    assign cycle_per_spin_write             = reg2hw.counter_cfg_2.cycle_per_spin_write.q;
    assign cycle_per_spin_compute           = reg2hw.counter_cfg_3.cycle_per_spin_compute.q;
    assign debug_cycle_per_spin_read        = reg2hw.counter_cfg_3.debug_cycle_per_spin_read.q;
    assign debug_spin_read_num              = reg2hw.counter_cfg_4.debug_spin_read_num.q;
    assign icon_last_raddr_plus_one         = reg2hw.counter_cfg_4.icon_last_raddr_plus_one.q;
    assign dgt_hscaling                     = reg2hw.counter_cfg_4.dgt_hscaling.q;

    assign dgt_hbias = h_rdata;

    always_comb begin
        wwl_vdd_cfg = '0;
        wwl_vread_cfg = '0;
        for (int i = 0; i < logic_cfg.NumSpin/`LAGD_REG_DATA_WIDTH; i=i+1) begin
            config_spin_initial[i*`LAGD_REG_DATA_WIDTH +: `LAGD_REG_DATA_WIDTH] = reg2hw.config_spin_initial[i].q;
            wwl_vdd_cfg        [i*`LAGD_REG_DATA_WIDTH +: `LAGD_REG_DATA_WIDTH] = reg2hw.wwl_vdd_cfg[i].q;
            wwl_vread_cfg      [i*`LAGD_REG_DATA_WIDTH +: `LAGD_REG_DATA_WIDTH] = reg2hw.wwl_vread_cfg[i].q;
            spin_wwl_strobe    [i*`LAGD_REG_DATA_WIDTH +: `LAGD_REG_DATA_WIDTH] = reg2hw.spin_wwl_strobe[i].q;
            spin_feedback_cfg  [i*`LAGD_REG_DATA_WIDTH +: `LAGD_REG_DATA_WIDTH] = reg2hw.spin_feedback_cfg[i].q;
            debug_j_one_hot_wwl[i*`LAGD_REG_DATA_WIDTH +: `LAGD_REG_DATA_WIDTH] = reg2hw.debug_j_one_hot_wwl[i].q;
        end
        wwl_vdd_cfg[logic_cfg.NumSpin]   = reg2hw.global_cfg_1.wwl_vdd_cfg_256.q;
        wwl_vread_cfg[logic_cfg.NumSpin] = reg2hw.global_cfg_1.wwl_vread_cfg_256.q;
    end

    always_comb begin
        for (int i = 0; i < logic_cfg.HRegDataBitwidth/`LAGD_REG_DATA_WIDTH; i=i+1) begin
            h_rdata            [i*`LAGD_REG_DATA_WIDTH +: `LAGD_REG_DATA_WIDTH] = reg2hw.h_rdata[i].q;
            wbl_floating       [i*`LAGD_REG_DATA_WIDTH +: `LAGD_REG_DATA_WIDTH] = reg2hw.wbl_floating[i].q;
        end
    end

    // hw2reg
    assign hw2reg.output_status.dt_cfg_idle                  .de = en_aw;
    assign hw2reg.output_status.cmpt_idle                    .de = en_fm;
    assign hw2reg.output_status.energy_fifo_update           .de = en_fm | ctnus_fifo_read;
    assign hw2reg.output_status.spin_fifo_update             .de = en_fm | ctnus_fifo_read;
    assign hw2reg.output_status.debug_j_read_data_valid      .de = en_aw;
    assign hw2reg.output_status.debug_analog_dt_w_idle       .de = en_aw;
    assign hw2reg.output_status.debug_analog_dt_r_idle       .de = en_aw;
    assign hw2reg.output_status.debug_spin_w_idle            .de = en_aw;
    assign hw2reg.output_status.debug_spin_cmpt_idle         .de = en_aw;
    assign hw2reg.output_status.debug_spin_r_idle            .de = en_aw;
    assign hw2reg.output_status.debug_fm_upstream_handshake  .de = ctnus_dgt_debug;
    assign hw2reg.output_status.debug_fm_downstream_handshake.de = ctnus_dgt_debug;
    assign hw2reg.output_status.debug_aw_downstream_handshake.de = ctnus_dgt_debug;
    assign hw2reg.output_status.debug_em_upstream_handshake  .de = ctnus_dgt_debug;
    assign hw2reg.debug_fm_energy_input                      .de = ctnus_dgt_debug;
    assign hw2reg.energy_fifo_data_0                         .de = (ctnus_dgt_debug & energy_fifo_update) | ctnus_fifo_read;
    assign hw2reg.energy_fifo_data_1                         .de = (ctnus_dgt_debug & energy_fifo_update) | ctnus_fifo_read;

    assign hw2reg.output_status.dt_cfg_idle                   .d = dt_cfg_idle;
    assign hw2reg.output_status.cmpt_idle                     .d = cmpt_idle;
    assign hw2reg.output_status.energy_fifo_update            .d = energy_fifo_update;
    assign hw2reg.output_status.spin_fifo_update              .d = spin_fifo_update;
    assign hw2reg.output_status.debug_j_read_data_valid       .d = debug_j_read_data_valid;
    assign hw2reg.output_status.debug_analog_dt_w_idle        .d = debug_analog_dt_w_idle;
    assign hw2reg.output_status.debug_analog_dt_r_idle        .d = debug_analog_dt_r_idle;
    assign hw2reg.output_status.debug_spin_w_idle             .d = debug_spin_w_idle;
    assign hw2reg.output_status.debug_spin_cmpt_idle          .d = debug_spin_cmpt_idle;
    assign hw2reg.output_status.debug_spin_r_idle             .d = debug_spin_r_idle;
    assign hw2reg.output_status.debug_fm_upstream_handshake   .d = debug_fm_upstream_handshake;
    assign hw2reg.output_status.debug_fm_downstream_handshake .d = debug_fm_downstream_handshake;
    assign hw2reg.output_status.debug_aw_downstream_handshake .d = debug_aw_downstream_handshake;
    assign hw2reg.output_status.debug_em_upstream_handshake   .d = debug_em_upstream_handshake;
    assign hw2reg.debug_fm_energy_input                       .d = debug_fm_energy_input;
    assign hw2reg.energy_fifo_data_0                          .d = energy_fifo_data[0];
    assign hw2reg.energy_fifo_data_1                          .d = energy_fifo_data[1];

    always_comb begin
        for (int i = 0; i < logic_cfg.NumSpin/`LAGD_REG_DATA_WIDTH; i=i+1) begin
            hw2reg.spin_fifo_data_0 [i].de = (ctnus_dgt_debug & spin_fifo_update) | ctnus_fifo_read;
            hw2reg.spin_fifo_data_1 [i].de = (ctnus_dgt_debug & spin_fifo_update) | ctnus_fifo_read;
            hw2reg.debug_fm_spin_out[i].de = ctnus_dgt_debug;
            hw2reg.debug_aw_spin_out[i].de = ctnus_dgt_debug;
            hw2reg.debug_em_spin_in [i].de = ctnus_dgt_debug;

            hw2reg.spin_fifo_data_0 [i].d = spin_fifo_data[0][i*`LAGD_REG_DATA_WIDTH +: `LAGD_REG_DATA_WIDTH];
            hw2reg.spin_fifo_data_1 [i].d = spin_fifo_data[1][i*`LAGD_REG_DATA_WIDTH +: `LAGD_REG_DATA_WIDTH];
            hw2reg.debug_fm_spin_out[i].d = debug_fm_spin_out[i*`LAGD_REG_DATA_WIDTH +: `LAGD_REG_DATA_WIDTH];
            hw2reg.debug_aw_spin_out[i].d = debug_aw_spin_out[i*`LAGD_REG_DATA_WIDTH +: `LAGD_REG_DATA_WIDTH];
            hw2reg.debug_em_spin_in [i].d = debug_em_spin_in [i*`LAGD_REG_DATA_WIDTH +: `LAGD_REG_DATA_WIDTH];
        end
    end

    always_comb begin
        for (int i = 0; i < logic_cfg.HRegDataBitwidth/`LAGD_REG_DATA_WIDTH; i=i+1) begin
            hw2reg.debug_j_read_data[i].de = debug_j_read_data_valid;
            hw2reg.debug_j_read_data[i].d  = debug_j_read_data[i*`LAGD_REG_DATA_WIDTH +: `LAGD_REG_DATA_WIDTH];
        end
    end

    //////////////////////////////////////////////////////////
    // Analog Macro //////////////////////////////////////////
    //////////////////////////////////////////////////////////
    galena u_galena (
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

    assign j_rdata = drt_s_rsp_j.p.data;
    assign dgt_weight = drt_s_rsp_j.p.data;
    assign flip_rdata = drt_s_rsp_flip.p.data;

    digital_macro #(
        .BITJ                            (logic_cfg.BitJ                   ),
        .BITH                            (logic_cfg.BitH                   ),
        .NUM_SPIN                        (logic_cfg.NumSpin                ),
        .SCALING_BIT                     (logic_cfg.ScalingBit             ),
        .PARALLELISM                     (logic_cfg.Parallelism            ),
        .ENERGY_TOTAL_BIT                (logic_cfg.EnergyTotalBit         ),
        .LITTLE_ENDIAN                   (logic_cfg.LittleEndian           ),
        .PIPESINTF                       (logic_cfg.PipesIntf              ),
        .PIPESMID                        (logic_cfg.PipesMid               ),
        .PIPESFLIPFILTER                 (logic_cfg.PipesFlipFilter        ),
        .SPIN_DEPTH                      (logic_cfg.SpinDepth              ),
        .FLIP_ICON_DEPTH                 (logic_cfg.FlipIconDepth          ),
        .COUNTER_BITWIDTH                (logic_cfg.CounterBitwidth        ),
        .SYNCHRONIZER_PIPEDEPTH          (logic_cfg.SynchronizerPipeDepth  ),
        .SPIN_WBL_OFFSET                 (logic_cfg.SpinWblOffset          ),
        .H_IS_NEGATIVE                   (logic_cfg.HIsNegative            ),
        .ENABLE_FLIP_DETECTION           (logic_cfg.EnableFlipDetection    )
    ) u_digital_macro (
        .clk_i                           (clk_i                            ),
        .rst_ni                          (rst_ni                           ),
        .en_aw_i                         (en_aw                            ),
        .en_em_i                         (en_em                            ),
        .en_ff_i                         (en_ff                            ),
        .en_fm_i                         (en_fm                            ),
        .en_ef_i                         (en_ef                            ),
        .en_analog_loop_i                (en_analog_loop                   ),
        .config_valid_em_i               (config_valid_em                  ),
        .config_valid_fm_i               (config_valid_fm                  ),
        .config_valid_aw_i               (config_valid_aw                  ),
        .debug_dt_configure_enable_i     (debug_dt_configure_enable        ),
        .debug_spin_configure_enable_i   (debug_spin_configure_enable      ),
        .config_counter_i                (config_counter                   ),
        .config_spin_initial_i           (config_spin_initial              ),
        .config_spin_initial_skip_i      (config_spin_initial_skip         ),
        .cfg_trans_num_i                 (cfg_trans_num                    ),
        .cycle_per_wwl_high_i            (cycle_per_wwl_high               ),
        .cycle_per_wwl_low_i             (cycle_per_wwl_low                ),
        .cycle_per_spin_write_i          (cycle_per_spin_write             ),
        .cycle_per_spin_compute_i        (cycle_per_spin_compute           ),
        .wwl_vdd_i                       (wwl_vdd_cfg                      ),
        .wwl_vread_i                     (wwl_vread_cfg                    ),
        .bypass_data_conversion_i        (bypass_data_conversion           ),
        .spin_wwl_strobe_i               (spin_wwl_strobe                  ),
        .spin_feedback_i                 (spin_feedback_cfg                ),
        .synchronizer_pipe_num_i         (synchronizer_pipe_num            ),
        .synchronizer_wbl_pipe_num_i     (synchronizer_wbl_pipe_num        ),
        .debug_cycle_per_spin_read_i     (debug_cycle_per_spin_read        ),
        .debug_spin_read_num_i           (debug_spin_read_num              ),
        .dt_cfg_enable_i                 (dt_cfg_enable                    ),
        .j_mem_ren_o                     (j_mem_ren_load                   ),
        .j_raddr_o                       (j_raddr_load                     ),
        .j_rdata_i                       (j_rdata                          ),
        .h_ren_o                         (                                 ),
        .h_rdata_i                       (h_rdata                          ),
        .dt_cfg_idle_o                   (dt_cfg_idle                      ),
        .flush_i                         (flush_en                         ),
        .en_comparison_i                 (en_comparison                    ),
        .cmpt_en_i                       (cmpt_en                          ),
        .cmpt_idle_o                     (cmpt_idle                        ),
        .host_readout_i                  (host_readout                     ),
        .flip_ren_o                      (flip_ren                         ),
        .flip_raddr_o                    (flip_raddr                       ),
        .icon_last_raddr_plus_one_i      (icon_last_raddr_plus_one         ),
        .flip_rdata_i                    (flip_rdata                       ),
        .flip_disable_i                  (flip_disable                     ),
        .dgt_weight_ren_o                (dgt_weight_ren                   ),
        .dgt_weight_raddr_o              (dgt_weight_raddr                 ),
        .dgt_addr_upper_bound_i          (dgt_addr_upper_bound             ),
        .dgt_weight_i                    (dgt_weight                       ),
        .dgt_hbias_i                     (dgt_hbias                        ),
        .dgt_hscaling_i                  (dgt_hscaling                     ),
        .j_one_hot_wwl_o                 (j_one_hot_wwl                    ),
        .h_wwl_o                         (h_wwl                            ),
        .wbl_o                           (wbl_in_analog                    ),
        .wblb_o                          (wblb_in_analog                   ),
        .wbl_read_i                      (debug_wbl_in                     ),
        .wblb_read_i                     (                                 ),
        .wbl_floating_o                  (wbl_floating_in_analog           ),
        .wwl_vdd_o                       (wwl_vdd_analog                   ),
        .wwl_vread_o                     (wwl_vread_analog                 ),
        .spin_wwl_o                      (spin_wwl                         ),
        .spin_feedback_o                 (spin_feedback_in_analog          ),
        .spin_analog_i                   (spin_out_analog                  ),
        .energy_fifo_update_o            (energy_fifo_update               ),
        .spin_fifo_update_o              (spin_fifo_update                 ),
        .energy_fifo_o                   (energy_fifo_data                 ),
        .spin_fifo_o                     (spin_fifo_data                   ),
        .enable_flip_detection_i         (enable_flip_detection            ),
        // debugging interface
        .debug_j_write_en_i              (debug_j_write_en                 ),
        .debug_j_read_en_i               (debug_j_read_en                  ),
        .debug_j_one_hot_wwl_i           (debug_j_one_hot_wwl              ),
        .debug_h_wwl_i                   (debug_h_wwl                      ),
        .debug_wbl_i                     (debug_wbl_in                     ),
        .debug_j_read_data_o             (debug_j_read_data                ),
        .debug_j_read_data_valid_o       (debug_j_read_data_valid          ),
        .debug_spin_write_en_i           (debug_spin_write_en              ),
        .wbl_floating_i                  (wbl_floating                     ),
        .debug_spin_compute_en_i         (debug_spin_compute_en            ),
        .debug_spin_read_en_i            (debug_spin_read_en               ),
        .debug_spin_valid_o              (debug_spin_valid                 ),
        .debug_spin_waddr_o              (debug_spin_waddr                 ),
        .debug_spin_o                    (debug_spin_out                   ),
        .debug_analog_dt_w_idle_o        (debug_analog_dt_w_idle           ),
        .debug_analog_dt_r_idle_o        (debug_analog_dt_r_idle           ),
        .debug_spin_w_idle_o             (debug_spin_w_idle                ),
        .debug_spin_cmpt_idle_o          (debug_spin_cmpt_idle             ),
        .debug_spin_r_idle_o             (debug_spin_r_idle                ),
        .debug_fm_upstream_handshake_o   (debug_fm_upstream_handshake      ),
        .debug_fm_energy_input_o         (debug_fm_energy_input            ),
        .debug_fm_downstream_handshake_o (debug_fm_downstream_handshake    ),
        .debug_fm_spin_out_o             (debug_fm_spin_out                ),
        .debug_aw_downstream_handshake_o (debug_aw_downstream_handshake    ),
        .debug_aw_spin_out_o             (debug_aw_spin_out                ),
        .debug_em_upstream_handshake_o   (debug_em_upstream_handshake      ),
        .debug_em_spin_in_o              (debug_em_spin_in                 )
    );

    //////////////////////////////////////////////////////////
    // Memory MUX ////////////////////////////////////////////
    //////////////////////////////////////////////////////////
    // flip memory request mux
    always_comb begin
        case(debug_spin_valid)
            1'b0: begin: no_debug_spin_read
                drt_s_req_flip.q.addr          = flip_raddr;
                drt_s_req_flip.q.write         = 1'b0; // read
                drt_s_req_flip.q.data          = {`IC_L1_FLIP_MEM_DATA_WIDTH{1'b0}}; // not used for read
                drt_s_req_flip.q.strb          = {(`IC_L1_FLIP_MEM_DATA_WIDTH/8){1'b0}}; // not used for read
                drt_s_req_flip.q.user          = 'd0; // not used
                drt_s_req_flip.q_valid         = flip_ren;
            end
            1'b1: begin: debug_spin_read
                drt_s_req_flip.q.addr          = debug_spin_waddr;
                drt_s_req_flip.q.write         = 1'b1; // write
                drt_s_req_flip.q.data          = debug_spin_out;
                drt_s_req_flip.q.strb          = {(`IC_L1_FLIP_MEM_DATA_WIDTH/8){1'b1}};
                drt_s_req_flip.q.user          = 'd0; // not used
                drt_s_req_flip.q_valid         = 1'b1;
            end
        endcase
    end

    // j memory request mux
    always_comb begin
        case(dt_cfg_enable)
            1'b0: begin: load_mode
                drt_s_req_j.q.addr         = j_raddr_load;
                drt_s_req_j.q.write        = 1'b0; // read
                drt_s_req_j.q.data         = {`IC_L1_J_MEM_DATA_WIDTH{1'b0}}; // not used for read
                drt_s_req_j.q.strb         = {(`IC_L1_J_MEM_DATA_WIDTH/8){1'b0}}; // not used for read
                drt_s_req_j.q.user         = 'd0; // not used
                drt_s_req_j.q_valid        = j_mem_ren_load;
            end
            1'b1: begin: compute_mode
                drt_s_req_j.q.addr         = dgt_weight_raddr;
                drt_s_req_j.q.write        = 1'b0; // read
                drt_s_req_j.q.data         = {`IC_L1_J_MEM_DATA_WIDTH{1'b0}}; // not used for read
                drt_s_req_j.q.strb         = {(`IC_L1_J_MEM_DATA_WIDTH/8){1'b0}}; // not used for read
                drt_s_req_j.q.user         = 'd0; // not used
                drt_s_req_j.q_valid        = dgt_weight_ren;
            end
        endcase
    end

endmodule
