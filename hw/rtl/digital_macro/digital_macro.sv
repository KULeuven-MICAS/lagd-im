// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Digital compute macro

`include "../include/lagd_define.svh"
`include "common_cells/registers.svh"

`define True 1'b1
`define False 1'b0

module digital_macro #(
    // parameters: energy monitor
    parameter integer BITJ = 4,
    parameter integer NUM_SPIN = 256,
    parameter integer SCALING_BIT = 4,
    parameter integer PARALLELISM = 4,
    parameter integer ENERGY_TOTAL_BIT = 32,
    parameter integer LITTLE_ENDIAN = `False,
    parameter integer PIPESINTF = 1,
    parameter integer PIPESMID = 1,
    parameter integer PIPESFLIPFILTER = 1,
    // parameters: flip manager
    parameter integer SPIN_DEPTH = 2,
    parameter integer FLIP_ICON_DEPTH = 1024,
    // parameters: analog wrap
    parameter integer COUNTER_BITWIDTH = 16,
    parameter integer SYNCHRONIZER_PIPEDEPTH = 3,
    parameter integer SPIN_WBL_OFFSET = 0,
    // parameters: entire macro
    parameter integer H_IS_NEGATIVE = `False,
    parameter integer ENABLE_FLIP_DETECTION = `False,
    // derived parameters
    parameter integer BITH = BITJ,
    parameter integer SPIN_IDX_BIT = $clog2(NUM_SPIN),
    parameter integer FLIP_ICON_ADDR_DEPTH = $clog2(FLIP_ICON_DEPTH),
    parameter integer DATA_J_BIT = NUM_SPIN * BITJ * PARALLELISM,
    parameter integer DATA_H_BIT = BITH * NUM_SPIN,
    parameter integer J_MEM_ADDR_WIDTH = $clog2(NUM_SPIN / PARALLELISM),
    parameter integer DEBUG_WADDR_UP_LIMIT = FLIP_ICON_DEPTH,
    parameter integer DEBUG_WADDR_WIDTH = FLIP_ICON_ADDR_DEPTH
)(
    input  logic clk_i,
    input  logic rst_ni,
    input  logic flush_i,
    input  logic en_aw_i,
    input  logic en_em_i,
    input  logic en_fm_i,
    input  logic en_ff_i,
    input  logic en_ef_i,
    input  logic en_analog_loop_i,
    // config interface: ctrl
    input  logic config_valid_em_i,
    input  logic config_valid_fm_i,
    input  logic config_valid_aw_i,
    input  logic debug_dt_configure_enable_i,
    input  logic debug_spin_configure_enable_i,
    // config interface: energy monitor
    input  logic [SPIN_IDX_BIT-1:0] config_counter_i,
    // config interface: flip manager
    input  logic [NUM_SPIN-1:0] config_spin_initial_i,
    input  logic config_spin_initial_skip_i,
    // config interface: analog wrap
    input  logic [COUNTER_BITWIDTH-1:0] cfg_trans_num_i,
    input  logic [COUNTER_BITWIDTH-1:0] cycle_per_wwl_high_i,
    input  logic [COUNTER_BITWIDTH-1:0] cycle_per_wwl_low_i,
    input  logic [COUNTER_BITWIDTH-1:0] cycle_per_spin_write_i,
    input  logic [COUNTER_BITWIDTH-1:0] cycle_per_spin_compute_i,
    input  logic [NUM_SPIN-1:0] wwl_vdd_i,
    input  logic [NUM_SPIN-1:0] wwl_vread_i,
    input  logic bypass_data_conversion_i,
    input  logic [NUM_SPIN-1:0] spin_wwl_strobe_i,
    input  logic [NUM_SPIN-1:0] spin_feedback_i,
    input  logic [$clog2(SYNCHRONIZER_PIPEDEPTH)-1:0] synchronizer_pipe_num_i,
    input  logic [$clog2(SYNCHRONIZER_PIPEDEPTH)-1:0] synchronizer_wbl_pipe_num_i,
    input  logic [COUNTER_BITWIDTH-1:0] debug_cycle_per_spin_read_i,
    input  logic [COUNTER_BITWIDTH-1:0] debug_spin_read_num_i,
    input  logic [NUM_SPIN*BITJ-1:0] wbl_floating_i,
    // data loading interface
    input  logic dt_cfg_enable_i, // load enable for the analog macro
    output logic j_mem_ren_o,
    output logic [$clog2(NUM_SPIN / PARALLELISM)-1:0] j_raddr_o,
    input  logic [DATA_J_BIT-1:0] j_rdata_i,
    output logic h_ren_o,
    input  logic [DATA_H_BIT-1:0] h_rdata_i,
    output logic dt_cfg_idle_o,
    // runtime interface: flip manager
    input  logic en_comparison_i,
    input  logic cmpt_en_i,
    output logic cmpt_idle_o,
    input  logic host_readout_i,
    output logic flip_ren_o,
    output logic [FLIP_ICON_ADDR_DEPTH-1:0] flip_raddr_o,
    input  logic [FLIP_ICON_ADDR_DEPTH+1-1:0] icon_last_raddr_plus_one_i,
    input  logic [NUM_SPIN-1:0] flip_rdata_i,
    input  logic flip_disable_i,
    output logic energy_fifo_update_o,
    output logic spin_fifo_update_o,
    output logic [SPIN_DEPTH-1:0] [ENERGY_TOTAL_BIT-1:0] energy_fifo_o,
    output logic [SPIN_DEPTH-1:0] [NUM_SPIN-1:0] spin_fifo_o,
    // runtime interface: energy monitor
    output  logic dgt_weight_ren_o,
    output logic [J_MEM_ADDR_WIDTH-1:0] dgt_weight_raddr_o,
    input  logic [DATA_J_BIT-1:0] dgt_weight_i,
    input  logic [DATA_H_BIT-1:0] dgt_hbias_i,
    input  logic [SCALING_BIT-1:0] dgt_hscaling_i,
    // runtime interface: analog wrap
    output logic [NUM_SPIN-1:0] j_one_hot_wwl_o,
    output logic h_wwl_o,
    output logic [NUM_SPIN*BITJ-1:0] wbl_o,
    output logic [NUM_SPIN*BITJ-1:0] wblb_o,
    output logic [NUM_SPIN*BITJ-1:0] wbl_floating_o,
    output logic [NUM_SPIN-1:0] wwl_vdd_o,
    output logic [NUM_SPIN-1:0] wwl_vread_o,
    output logic [NUM_SPIN-1:0] spin_wwl_o,
    output logic [NUM_SPIN-1:0] spin_feedback_o,
    input  logic [NUM_SPIN-1:0] spin_analog_i,
    input  logic [NUM_SPIN*BITJ-1:0] wbl_read_i,
    input  logic [NUM_SPIN*BITJ-1:0] wblb_read_i, // not used
    // runtime interface: energy fifo
    input  logic [J_MEM_ADDR_WIDTH-1:0] dgt_addr_upper_bound_i,
    // interface when ENABLE_FLIP_DETECTION = True
    input  logic enable_flip_detection_i,
    // debugging interface: model write/read
    input  logic debug_j_write_en_i,
    input  logic debug_j_read_en_i,
    input  logic [NUM_SPIN-1:0] debug_j_one_hot_wwl_i,
    input  logic debug_h_wwl_i,
    input  logic [NUM_SPIN*BITJ-1:0] debug_wbl_i,
    output logic debug_j_read_data_valid_o,
    output logic [NUM_SPIN*BITJ-1:0] debug_j_read_data_o,
    // debugging interface: spin write/compute/read
    input  logic debug_spin_write_en_i,
    input  logic debug_spin_compute_en_i,
    input  logic debug_spin_read_en_i,
    output logic debug_spin_valid_o,
    output logic [DEBUG_WADDR_WIDTH-1:0] debug_spin_waddr_o,
    output logic [NUM_SPIN-1:0] debug_spin_o,
    // debugging interface: status
    output logic debug_analog_dt_w_idle_o,
    output logic debug_analog_dt_r_idle_o,
    output logic debug_spin_w_idle_o,
    output logic debug_spin_cmpt_idle_o,
    output logic debug_spin_r_idle_o
);
    // Internal signals
    logic aw_mst_valid;
    logic [NUM_SPIN-1:0] analog_spin, muxed_analog_spin, em_spin_in;
    logic em_slv_ready;
    logic em_mst_valid;
    logic em_weight_valid;
    logic em_weight_ready;
    logic aw_downstream_ready;
    logic fm_upstream_mst_valid;
    logic fm_upstream_handshake;
    logic em_ef_handshake;
    logic em_upstream_handshake;
    logic fm_downstream_handshake;
    logic signed [ENERGY_TOTAL_BIT-1:0] em_energy_output, fm_energy_input, ff_energy_baseline, ff_energy_baseline_pipe;
    logic signed [ENERGY_TOTAL_BIT-1:0] em_energy_baseline_out, em_energy_baseline_in;
    logic [NUM_SPIN-1:0] ff_spin_baseline, ff_spin_baseline_pipe;
    logic [NUM_SPIN-1:0] em_spin_output, fm_spin_input;
    logic flip_manager_spin_ready;
    logic fm_slv_ready;
    logic fm_mst_valid;
    logic [NUM_SPIN-1:0] fm_spin_out;
    logic aw_slv_ready;
    logic [SPIN_IDX_BIT-1:0] counter_spin_em, counter_weight;
    logic [SCALING_BIT*PARALLELISM-1:0] hscaling_expanded;
    logic [BITH*PARALLELISM-1:0] hbias_sliced;
    logic fm_downstream_slv_ready, em_upstream_mst_valid;
    logic counter_weight_maxed, counter_weight_overflow;
    logic [DATA_J_BIT-1:0] ef_weight_out;
    logic cmpt_en_dly1, cmpt_en_pos_trigger;
    logic em_fifo_flush_comb;
    logic ff_slv_ready;
    logic ff_mst_valid;
    logic [FLIP_ICON_ADDR_DEPTH+1-1:0] flip_raddr_fm;
    logic [J_MEM_ADDR_WIDTH-1:0] ff_raddr, ff_raddr_em, ff_raddr_em_fifo;
    logic ff_raddr_last_one, em_raddr_last_one_fifo, em_raddr_last_one;
    logic [NUM_SPIN-1:0] ff_bits_unflipped, ff_bits_unflipped_dly1;
    logic [NUM_SPIN*BITJ-1:0] ff_bits_unflipped_expand;
    logic [PARALLELISM-1:0] ff_block_bits_flipped;
    logic enable_flip_detection_dly1;
    logic dgt_weight_ren_ef;
    logic dgt_weight_ren_dly1;
    logic [ J_MEM_ADDR_WIDTH-1:0 ] dgt_weight_raddr_ef;
    logic [PARALLELISM-1:0] em_weight_valid_parallel_fifo, em_weight_valid_parallel;
    logic [DATA_J_BIT-1:0] dgt_weight_ef;
    logic [SPIN_IDX_BIT-1:0] em_external_counter_q;
    logic ff_baseline_valid;
    logic parallel_fifo_empty;
    logic em_double_weight_contri;
    logic em_baseline_done;
    logic em_busy;

    assign em_upstream_handshake = em_slv_ready & em_upstream_mst_valid;
    assign fm_downstream_handshake = fm_mst_valid & fm_downstream_slv_ready;
    assign em_ef_handshake = em_weight_valid & em_weight_ready;

    assign hscaling_expanded = {PARALLELISM{dgt_hscaling_i}};
    assign cmpt_en_pos_trigger = cmpt_en_i & ~cmpt_en_dly1;
    assign em_fifo_flush_comb = flush_i | (enable_flip_detection_i & ~enable_flip_detection_dly1);

    assign muxed_analog_spin = en_analog_loop_i ? analog_spin : fm_spin_out;
    assign flip_raddr_o = flip_raddr_fm[FLIP_ICON_ADDR_DEPTH-1:0];

    `FFL(cmpt_en_dly1, cmpt_en_i, en_fm_i, 1'b0, clk_i, rst_ni);
    `FFL(enable_flip_detection_dly1, enable_flip_detection_i, en_ff_i, 1'b0, clk_i, rst_ni);

    generate
        if (ENABLE_FLIP_DETECTION) begin: initialize_flip_filter
            logic ff_ef_handshake;
            logic ff_upstream_mst_valid;
            logic dgt_weight_ren_ff;
            logic ff_mst_valid;
            logic ff_empty, ff_empty_valid_pipe;
            logic ff_empty_downstream_ready;
            logic weight_info_fifo_push_en;
            logic signed [ENERGY_TOTAL_BIT-1:0] ff_energy_baseline_to_ef;

            assign ff_ef_handshake = dgt_weight_ren_ff & dgt_weight_ren_ef;

            assign aw_downstream_ready = ff_slv_ready;
            assign fm_downstream_slv_ready = en_analog_loop_i ? aw_slv_ready : ff_slv_ready;
            assign em_upstream_mst_valid = ff_mst_valid;
            assign ff_upstream_mst_valid = en_analog_loop_i ? aw_mst_valid : fm_mst_valid;
            assign fm_upstream_handshake = fm_upstream_mst_valid && fm_slv_ready;
            assign weight_info_fifo_push_en = enable_flip_detection_i ? ff_ef_handshake && ~ff_empty : dgt_weight_ren_ef;

            assign dgt_weight_ren_o = enable_flip_detection_i ? ff_ef_handshake : dgt_weight_ren_ef;
            assign dgt_weight_raddr_o = enable_flip_detection_i ? ff_raddr : dgt_weight_raddr_ef;
            assign dgt_weight_ef = enable_flip_detection_i ? dgt_weight_i & {(PARALLELISM){ff_bits_unflipped_expand}} : dgt_weight_i;
            assign em_external_counter_q = ff_raddr_em * PARALLELISM;
            assign em_weight_valid_parallel = (parallel_fifo_empty | ~em_weight_valid) ? 'd0 : em_weight_valid_parallel_fifo;
            assign em_raddr_last_one = (parallel_fifo_empty | ~em_weight_valid) ? 1'b0 : em_raddr_last_one_fifo;
            assign ff_raddr_em = (parallel_fifo_empty | ~em_weight_valid) ? 'd0 : ff_raddr_em_fifo;
            assign ff_energy_baseline_to_ef = ff_raddr_last_one & ~ff_empty ? ff_energy_baseline : 'd0;

            always_comb begin: priority_handshake
                if (enable_flip_detection_i & em_baseline_done & ~em_busy) begin: baseline_path
                    fm_upstream_mst_valid = ff_empty_valid_pipe;
                    fm_energy_input = ff_energy_baseline_pipe;
                    fm_spin_input = ff_spin_baseline_pipe;
                    ff_empty_downstream_ready = fm_slv_ready;
                end else begin: energy_monitor_path
                    fm_upstream_mst_valid = em_mst_valid;
                    fm_energy_input = em_energy_output;
                    fm_spin_input = em_spin_output;
                    ff_empty_downstream_ready = 1'b0;
                end
            end

            always_comb begin
                ff_bits_unflipped_expand = 'd0;
                for (int i = 0; i < NUM_SPIN; i = i + 1) begin
                    ff_bits_unflipped_expand[i*BITJ +: BITJ] = {BITJ{ff_bits_unflipped_dly1[i]}};
                end
            end

            if (LITTLE_ENDIAN) begin
                assign hbias_sliced = dgt_hbias_i[em_external_counter_q * BITH +: BITH * PARALLELISM];
            end else begin
                assign hbias_sliced = dgt_hbias_i[(NUM_SPIN - em_external_counter_q - PARALLELISM) * BITH +: BITH * PARALLELISM];
            end

            `FFLARNC(ff_bits_unflipped_dly1, ff_bits_unflipped, ff_ef_handshake, flush_i, {NUM_SPIN{1'b1}}, clk_i, rst_ni);

            // pipeline to handle handshake conflict when both ff_empty and energy monitor handshake occur
            // here its handshake has lower priority than energy monitor
            // note there is no handshake with upstream (ready_o is not connected)
            bp_pipe #(
                .DATAW(ENERGY_TOTAL_BIT + NUM_SPIN),
                .PIPES(SPIN_DEPTH > 1 ? (SPIN_DEPTH-1) : 0) // In principle this can be 0 when SPIN_DEPTH=1. But lack of data for verification. Set to 1 for safety reason.
            ) u_pipe_ff_empty (
                .clk_i(clk_i),
                .rst_ni(rst_ni),
                .data_i({ff_energy_baseline, ff_spin_baseline}),
                .data_o({ff_energy_baseline_pipe, ff_spin_baseline_pipe}),
                .valid_i(ff_empty),
                .valid_o(ff_empty_valid_pipe),
                .ready_i(ff_empty_downstream_ready),
                .ready_o()
            );

            // FIFO to cache parameters for energy monitor when flip detection is enabled
            lagd_fifo_v3 #(
                .FALL_THROUGH(1'b0),
                .DATA_WIDTH(ENERGY_TOTAL_BIT + PARALLELISM+1+J_MEM_ADDR_WIDTH+1),
                .DEPTH(3), // same as u_em_fifo + memory latency
                .RESET_VALUE(0)
            ) weight_info_fifo (
                .clk_i(clk_i),
                .rst_ni(rst_ni),
                .flush_i(flush_i),
                .full_o(),
                .empty_o(parallel_fifo_empty),
                .usage_o(),
                .data_i({ff_energy_baseline_to_ef, ff_block_bits_flipped, ff_raddr_last_one, dgt_weight_raddr_o, ff_baseline_valid & enable_flip_detection_i}),
                .push_none_i(1'b0),
                .push_i(weight_info_fifo_push_en),
                .data_o({em_energy_baseline_in, em_weight_valid_parallel_fifo, em_raddr_last_one_fifo, ff_raddr_em_fifo, em_double_weight_contri}),
                .pop_i(em_ef_handshake),
                .mem_o(),
                .almost_full_o()
            );

            flip_filter #(
                .NUM_SPIN          (NUM_SPIN               ),
                .ENERGY_TOTAL_BIT  (ENERGY_TOTAL_BIT       ),
                .PARALLELISM       (PARALLELISM            ),
                .SPIN_DEPTH        (SPIN_DEPTH             ),
                .LITTLE_ENDIAN     (LITTLE_ENDIAN          ),
                .PIPESINTF         (PIPESFLIPFILTER        ),
                .PIPES_IN_ARBITER  (0                      )
            ) u_flip_filter (
                .clk_i                  (clk_i                         ),
                .rst_ni                 (rst_ni                        ),
                .en_i                   (en_ff_i                       ),
                .enable_flip_detection_i(enable_flip_detection_i       ),
                .flush_i                (em_fifo_flush_comb            ),
                .raddr_upper_bound_i    (dgt_addr_upper_bound_i        ),
                .energy_baseline_i      (energy_fifo_o                 ),
                .spin_baseline_i        (spin_fifo_o                   ),
                .curr_baseline_valid_o  (ff_baseline_valid             ),
                .spin_upstream_valid_i  (ff_upstream_mst_valid         ),
                .spin_upstream_ready_o  (ff_slv_ready                  ),
                .spin_upstream_i        (muxed_analog_spin             ),
                .spin_downstream_valid_o(ff_mst_valid                  ),
                .spin_downstream_ready_i(em_slv_ready                  ),
                .spin_downstream_o      (em_spin_in                    ),
                .raddr_valid_o          (dgt_weight_ren_ff             ),
                .raddr_ready_i          (dgt_weight_ren_ef             ),
                .raddr_o                (ff_raddr                      ),
                .block_bits_flipped_o   (ff_block_bits_flipped         ),
                .raddr_last_one_o       (ff_raddr_last_one             ),
                .bits_unflipped_o       (ff_bits_unflipped             ),
                .energy_baseline_o      (ff_energy_baseline            ),
                .spin_baseline_o        (ff_spin_baseline              ),
                .empty_o                (ff_empty                      )
            );
        end
        else begin: energy_monitor_path_only
            assign aw_downstream_ready = em_slv_ready;
            assign fm_downstream_slv_ready = en_analog_loop_i ? aw_slv_ready : em_slv_ready;
            assign em_upstream_mst_valid = en_analog_loop_i ? aw_mst_valid : fm_mst_valid;
            assign fm_upstream_mst_valid = em_mst_valid;
            assign fm_upstream_handshake = em_mst_valid & fm_slv_ready;

            assign dgt_weight_ren_o = dgt_weight_ren_ef;
            assign dgt_weight_raddr_o = dgt_weight_raddr_ef;
            assign dgt_weight_ef = dgt_weight_i;
            assign fm_energy_input = em_energy_output;
            assign fm_spin_input = em_spin_output;
            assign em_weight_valid_parallel = {(PARALLELISM){1'b1}};
            assign em_external_counter_q = {SPIN_IDX_BIT{1'b0}};
            assign em_raddr_last_one = 1'b0;
            assign em_double_weight_contri = 1'b0;
            assign em_spin_in = muxed_analog_spin;
            assign em_energy_baseline_in = 'd0;

            if (LITTLE_ENDIAN) begin
                assign hbias_sliced = dgt_hbias_i[counter_weight * BITH +: BITH * PARALLELISM];
            end else begin
                assign hbias_sliced = dgt_hbias_i[(NUM_SPIN - counter_weight - PARALLELISM) * BITH +: BITH * PARALLELISM];
            end

            // counter for hbias slice selection
            step_counter #(
                .COUNTER_BITWIDTH($clog2(NUM_SPIN)),
                .PARALLELISM(PARALLELISM)
            ) u_em_weight_hdsk_counter (
                .clk_i(clk_i),
                .rst_ni(rst_ni),
                .en_i(en_em_i),
                .load_i(config_valid_em_i),
                .d_i(config_counter_i),
                .recount_en_i(counter_weight_maxed && em_ef_handshake),
                .step_en_i(em_ef_handshake),
                .q_o(counter_weight),
                .maxed_o(counter_weight_maxed),
                .overflow_o(counter_weight_overflow)
            );
        end
    endgenerate

    `FFLARNC(dgt_weight_ren_dly1, dgt_weight_ren_o, en_ef_i, flush_i, 1'b0, clk_i, rst_ni);
    // memory to handshake fifo for weight loading
    mem_to_handshake_fifo #(
        .DEPTH                          (2                          ),
        .ADDR_WIDTH                     (J_MEM_ADDR_WIDTH           ),
        .DATA_WIDTH                     (DATA_J_BIT                 )
    ) u_em_fifo (
        .clk_i                          (clk_i                      ),
        .rst_ni                         (rst_ni                     ),
        .en_i                           (en_ef_i                    ),
        .flush_i                        (em_fifo_flush_comb         ),
        .addr_upper_bound_i             (dgt_addr_upper_bound_i     ),
        .mem_ren_o                      (dgt_weight_ren_ef          ),
        .mem_raddr_o                    (dgt_weight_raddr_ef        ),
        .mem_rdata_valid_i              (dgt_weight_ren_dly1        ),
        .mem_rdata_i                    (dgt_weight_ef              ),
        .data_ready_i                   (em_weight_ready            ),
        .data_valid_o                   (em_weight_valid            ),
        .data_o                         (ef_weight_out              ),
        .debug_fifo_usage_o             (                           )
    );

    // instantiate energy monitor for h energy calculation
    energy_monitor #(
        .BITJ                           (BITJ                       ),
        .BITH                           (BITH                       ),
        .SPIN_DEPTH                     (SPIN_DEPTH                 ),
        .NUM_SPIN                       (NUM_SPIN                   ),
        .SCALING_BIT                    (SCALING_BIT                ),
        .PARALLELISM                    (PARALLELISM                ),
        .ENERGY_TOTAL_BIT               (ENERGY_TOTAL_BIT           ),
        .LITTLE_ENDIAN                  (LITTLE_ENDIAN              ),
        .PIPESINTF                      (PIPESINTF                  ),
        .PIPESMID                       (PIPESMID                   ),
        .ENABLE_EXTERNAL_FINISH_SIGNAL  (ENABLE_FLIP_DETECTION      ),
        .H_IS_NEGATIVE                  (H_IS_NEGATIVE              )
    ) u_energy_monitor (
        .clk_i                          (clk_i                      ),
        .rst_ni                         (rst_ni                     ),
        .en_i                           (en_em_i                    ),
        .flush_i                        (em_fifo_flush_comb         ),
        .en_external_counter_i          (enable_flip_detection_i    ),
        .config_valid_i                 (config_valid_em_i          ),
        .config_counter_i               (config_counter_i           ),
        .config_ready_o                 (                           ),
        .spin_valid_i                   (em_upstream_mst_valid      ),
        .spin_i                         (em_spin_in                 ),
        .spin_ready_o                   (em_slv_ready               ),
        .weight_valid_i                 (em_weight_valid            ),
        .weight_valid_parallel_i        (em_weight_valid_parallel   ),
        .external_counter_q_i           (em_external_counter_q      ),
        .external_finish_i              (em_raddr_last_one          ),
        .double_weight_contri_i         (em_double_weight_contri    ),
        .weight_i                       (ef_weight_out              ),
        .hbias_i                        (hbias_sliced               ),
        .hscaling_i                     (hscaling_expanded          ),
        .energy_baseline_in_i           (em_energy_baseline_in      ),
        .weight_ready_o                 (em_weight_ready            ),
        .counter_spin_o                 (counter_spin_em            ),
        .energy_valid_o                 (em_mst_valid               ),
        .energy_ready_i                 (fm_slv_ready               ),
        .energy_o                       (em_energy_output           ),
        .energy_baseline_out_o          (em_energy_baseline_out     ),
        .spin_o                         (em_spin_output             ),
        .baseline_done_o                (em_baseline_done           ),
        .busy_o                         (em_busy                    )
    );

    // instantiate flip manager for spin flipping and spin management
    flip_manager #(
        .NUM_SPIN                       (NUM_SPIN                   ),
        .SPIN_DEPTH                     (SPIN_DEPTH                 ),
        .ENERGY_TOTAL_BIT               (ENERGY_TOTAL_BIT           ),
        .FLIP_ICON_DEPTH                (FLIP_ICON_DEPTH            )
    ) u_flip_manager (
        .clk_i                          (clk_i                      ),
        .rst_ni                         (rst_ni                     ),
        .en_i                           (en_fm_i                    ),
        .flush_i                        (flush_i                    ),
        .en_comparison_i                (en_comparison_i            ),
        .cmpt_en_i                      (cmpt_en_pos_trigger        ),
        .cmpt_idle_o                    (cmpt_idle_o                ),
        .host_readout_i                 (host_readout_i             ),
        .spin_configure_valid_i         (config_valid_fm_i          ),
        .spin_configure_i               (config_spin_initial_i      ),
        .spin_configure_push_none_i     (config_spin_initial_skip_i ),
        .spin_configure_ready_o         (                           ),
        .spin_pop_valid_o               (fm_mst_valid               ),
        .spin_pop_o                     (fm_spin_out                ),
        .spin_pop_ready_i               (fm_downstream_slv_ready    ),
        .energy_valid_i                 (fm_upstream_mst_valid      ),
        .energy_ready_o                 (fm_slv_ready               ),
        .energy_i                       (fm_energy_input            ),
        .spin_i                         (fm_spin_input              ),
        .flip_ren_o                     (flip_ren_o                 ),
        .flip_raddr_o                   (flip_raddr_fm              ),
        .icon_last_raddr_plus_one_i     (icon_last_raddr_plus_one_i ),
        .flip_rdata_i                   (flip_rdata_i               ),
        .flip_disable_i                 (flip_disable_i             ),
        .energy_fifo_update_o           (energy_fifo_update_o       ),
        .spin_fifo_update_o             (spin_fifo_update_o         ),
        .energy_fifo_o                  (energy_fifo_o              ),
        .spin_fifo_o                    (spin_fifo_o                )
    );

    // instantiate analog macro wrapper for analog interface management
    analog_macro_wrap #(
        .NUM_SPIN (NUM_SPIN),
        .BITDATA (BITJ),
        .PARALLELISM (PARALLELISM),
        .COUNTER_BITWIDTH (COUNTER_BITWIDTH),
        .SYNCHRONIZER_PIPEDEPTH (SYNCHRONIZER_PIPEDEPTH),
        .SPIN_WBL_OFFSET (SPIN_WBL_OFFSET),
        .DEBUG_WADDR_UP_LIMIT (DEBUG_WADDR_UP_LIMIT)
    ) u_analog_wrap (
        .clk_i                          (clk_i                      ),
        .rst_ni                         (rst_ni                     ),
        .en_i                           (en_aw_i                    ),
        .analog_wrap_configure_enable_i (config_valid_aw_i          ),
        .debug_dt_configure_enable_i    (debug_dt_configure_enable_i         ),
        .debug_spin_configure_enable_i  (debug_spin_configure_enable_i       ),
        .cfg_trans_num_i                (cfg_trans_num_i            ),
        .cycle_per_wwl_high_i           (cycle_per_wwl_high_i       ),
        .cycle_per_wwl_low_i            (cycle_per_wwl_low_i        ),
        .cycle_per_spin_write_i         (cycle_per_spin_write_i     ),
        .cycle_per_spin_compute_i       (cycle_per_spin_compute_i   ),
        .wwl_vdd_i                      (wwl_vdd_i                  ),
        .wwl_vread_i                    (wwl_vread_i                ),
        .bypass_data_conversion_i       (bypass_data_conversion_i   ),
        .spin_wwl_strobe_i              (spin_wwl_strobe_i          ),
        .spin_feedback_i                (spin_feedback_i            ),
        .synchronizer_pipe_num_i        (synchronizer_pipe_num_i    ),
        .synchronizer_wbl_pipe_num_i    (synchronizer_wbl_pipe_num_i),
        .debug_cycle_per_spin_read_i    (debug_cycle_per_spin_read_i),
        .debug_spin_read_num_i          (debug_spin_read_num_i      ),
        .dt_cfg_enable_i                (dt_cfg_enable_i            ),
        .j_mem_ren_o                    (j_mem_ren_o                ),
        .j_raddr_o                      (j_raddr_o                  ),
        .j_rdata_i                      (j_rdata_i                  ),
        .h_ren_o                        (h_ren_o                    ),
        .h_rdata_i                      (h_rdata_i                  ),
        .j_one_hot_wwl_o                (j_one_hot_wwl_o            ),
        .h_wwl_o                        (h_wwl_o                    ),
        .wbl_o                          (wbl_o                      ),
        .wblb_o                         (wblb_o                     ),
        .wbl_read_i                     (wbl_read_i                 ),
        .wbl_floating_o                 (wbl_floating_o             ),
        .wwl_vdd_o                      (wwl_vdd_o                  ),
        .wwl_vread_o                    (wwl_vread_o                ),
        .spin_pop_valid_i               (fm_mst_valid               ),
        .spin_pop_ready_o               (aw_slv_ready               ),
        .spin_pop_i                     (fm_spin_out                ),
        .spin_wwl_o                     (spin_wwl_o                 ),
        .spin_feedback_o                (spin_feedback_o            ),
        .spin_analog_i                  (spin_analog_i              ),
        .spin_valid_o                   (aw_mst_valid               ),
        .spin_ready_i                   (aw_downstream_ready        ),
        .spin_o                         (analog_spin                ),
        // debugging interface
        .debug_j_write_en_i             (debug_j_write_en_i         ),
        .debug_j_read_en_i              (debug_j_read_en_i          ),
        .debug_j_one_hot_wwl_i          (debug_j_one_hot_wwl_i      ),
        .debug_h_wwl_i                  (debug_h_wwl_i              ),
        .debug_wbl_i                    (debug_wbl_i                ),
        .debug_j_read_data_valid_o      (debug_j_read_data_valid_o  ),
        .debug_j_read_data_o            (debug_j_read_data_o        ),
        .debug_spin_write_en_i          (debug_spin_write_en_i      ),
        .wbl_floating_i                 (wbl_floating_i             ),
        .debug_spin_compute_en_i        (debug_spin_compute_en_i    ),
        .debug_spin_read_en_i           (debug_spin_read_en_i       ),
        .debug_spin_valid_o             (debug_spin_valid_o         ),
        .debug_spin_waddr_o             (debug_spin_waddr_o         ),
        .debug_spin_o                   (debug_spin_o               ),
        // status
        .debug_dt_w_idle_o              (debug_analog_dt_w_idle_o   ),
        .debug_dt_r_idle_o              (debug_analog_dt_r_idle_o   ),
        .debug_spin_w_idle_o            (debug_spin_w_idle_o        ),
        .debug_spin_cmpt_idle_o         (debug_spin_cmpt_idle_o     ),
        .debug_spin_r_idle_o            (debug_spin_r_idle_o        ),
        .dt_cfg_idle_o                  (dt_cfg_idle_o              ),
        .analog_rx_idle_o               (                           ),
        .analog_tx_idle_o               (                           )
    );

endmodule
