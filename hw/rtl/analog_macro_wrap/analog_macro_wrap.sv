// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Analog macro wrapper

`ifndef SYN
`define SYN 0
`endif

`include "common_cells/registers.svh"

module analog_macro_wrap #(
    parameter integer NUM_SPIN = 256,
    parameter integer BITDATA = 4,
    parameter integer PARALLELISM = 4, // min: 1
    parameter integer COUNTER_BITWIDTH = 16,
    parameter integer SYNCHRONIZER_PIPEDEPTH = 3,
    parameter integer SPIN_WBL_OFFSET = 0, // offset of spin wbl in the wbl data from digital macro (must less than BITDATA)
    parameter integer DEBUG_WADDR_UP_LIMIT = 1024,
    // derived parameters
    parameter integer DEBUG_WADDR_WIDTH = $clog2(DEBUG_WADDR_UP_LIMIT),
    parameter integer J_ADDRESS_WIDTH = $clog2(NUM_SPIN / PARALLELISM)
)(
    input logic clk_i,
    input logic rst_ni,
    input logic en_i,
    // config interface
    input  logic analog_wrap_configure_enable_i,
    input  logic debug_dt_configure_enable_i,
    input  logic debug_spin_configure_enable_i,
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
    // data config interface <-> digital
    input  logic dt_cfg_enable_i,
    output logic j_mem_ren_o,
    output logic [J_ADDRESS_WIDTH-1:0] j_raddr_o,
    input  logic [NUM_SPIN*BITDATA*PARALLELISM-1:0] j_rdata_i,
    output logic h_ren_o,
    input  logic [NUM_SPIN*BITDATA-1:0] h_rdata_i,
    // data config interface <-> analog macro
    output logic [NUM_SPIN-1:0] j_one_hot_wwl_o,
    output logic h_wwl_o,
    input  logic [NUM_SPIN*BITDATA-1:0] wbl_read_i,
    output logic [NUM_SPIN*BITDATA-1:0] wbl_o,
    output logic [NUM_SPIN*BITDATA-1:0] wblb_o,
    output logic [NUM_SPIN*BITDATA-1:0] wbl_floating_o,
    output logic [NUM_SPIN-1:0] wwl_vdd_o,
    output logic [NUM_SPIN-1:0] wwl_vread_o,
    // spin interface: rx <-> digital
    input  logic spin_pop_valid_i,
    output logic spin_pop_ready_o,
    input  logic [NUM_SPIN-1:0] spin_pop_i,
    // spin interface: rx <-> analog macro
    output logic [NUM_SPIN-1:0] spin_wwl_o,
    output logic [NUM_SPIN-1:0] spin_feedback_o,
    // spin interface: tx <- analog macro
    input  logic [NUM_SPIN-1:0] spin_analog_i,
    // spin interface: tx <-> digital
    output logic spin_valid_o,
    input  logic spin_ready_i,
    output logic [NUM_SPIN-1:0] spin_o,
    // debug interface: j/h writing/reading
    input  logic debug_j_write_en_i,
    input  logic debug_j_read_en_i,
    input  logic [NUM_SPIN-1:0] debug_j_one_hot_wwl_i,
    input  logic debug_h_wwl_i,
    input  logic [NUM_SPIN*BITDATA-1:0] debug_wbl_i,
    input  logic [NUM_SPIN*BITDATA-1:0] wbl_floating_i,
    output logic debug_j_read_data_valid_o,
    output logic [NUM_SPIN*BITDATA-1:0] debug_j_read_data_o,
    // debug interface: spin writing
    input  logic debug_spin_write_en_i,
    // debug interface: spin computing
    input  logic debug_spin_compute_en_i,
    // debug interface: spin reading
    input  logic debug_spin_read_en_i,
    output logic debug_spin_valid_o,
    output logic [DEBUG_WADDR_WIDTH-1:0] debug_spin_waddr_o,
    output logic [NUM_SPIN-1:0] debug_spin_o,
    // status
    output logic dt_cfg_idle_o,
    output logic analog_rx_idle_o,
    output logic analog_tx_idle_o,
    output logic debug_dt_w_idle_o,
    output logic debug_dt_r_idle_o,
    output logic debug_spin_w_idle_o,
    output logic debug_spin_cmpt_idle_o,
    output logic debug_spin_r_idle_o
);

    // Internal signals
    logic spin_tx_handshake;
    logic [NUM_SPIN*BITDATA-1:0] wbl_dt;
    logic [NUM_SPIN-1:0] wbl_spin;
    logic [NUM_SPIN*BITDATA-1:0] wbl_spin_expanded;
    logic [NUM_SPIN*BITDATA-1:0] wbl_write_output;
    logic [NUM_SPIN*BITDATA-1:0] wblb_write_output;
    logic [NUM_SPIN*BITDATA-1:0] wbl_read_input;
    logic [NUM_SPIN*BITDATA-1:0] wblb_read_input;
    logic analog_macro_cmpt_finish;
    logic [NUM_SPIN-1:0] j_one_hot_wwl_cfg_output;
    logic [NUM_SPIN-1:0] spin_wwl_rx_output;
    logic [NUM_SPIN-1:0] spin_feedback_rx_output;
    logic h_wwl_cfg_out;
    logic [COUNTER_BITWIDTH-1:0] debug_cycle_per_synchronization_reg;
    logic [COUNTER_BITWIDTH-1:0] debug_synchronization_num_reg;
    logic debug_spin_reading_en_dly1;
    logic debug_spin_read_addr_busy;
    logic debug_syn_cycle_cnt_maxed;
    logic debug_syn_num_cnt_maxed;
    logic debug_syn_num_cnt_overflow;
    logic analog_macro_cmpt_finish_rx_out;
    logic spin_valid_tx;
    logic spin_ready_tx;
    logic [COUNTER_BITWIDTH-1:0] debug_syn_num_cnt_q;
    logic [$clog2(SYNCHRONIZER_PIPEDEPTH)-1:0] synchronizer_pipe_num_tx_reg;
    logic debug_spin_read_en_posedge;
    logic debug_j_write_en_dly1, debug_j_read_en_dly1, debug_spin_write_en_dly1;
    logic debug_spin_compute_en_dly1;
    logic debug_j_write_en_posedge, debug_j_read_en_posedge, debug_spin_write_en_posedge, debug_spin_compute_en_posedge;
    logic debug_spin_compute_posedge;
    logic [NUM_SPIN-1:0] debug_j_write_wwl;
    logic debug_h_write_wwl;
    logic [NUM_SPIN*BITDATA-1:0] debug_wbl_dt_write, debug_wbl_spin, debug_wblb_spin;
    logic debug_analog_dt_idle;
    logic debug_dt_sync_en;
    logic debug_analog_dt_w_idle, debug_analog_dt_r_idle;
    logic [NUM_SPIN*BITDATA-1:0] wbl_floating_reg;
    logic debug_spin_sync_en;
    logic debug_spin_idle, debug_spin_w_idle, debug_spin_feedback_idle, debug_spin_r_idle;
    logic [NUM_SPIN-1:0] debug_spin_wwl;
    logic [NUM_SPIN-1:0] debug_spin_feedback;
    logic [NUM_SPIN-1:0] wwl_vdd_reg, wwl_vread_reg;
    genvar i;

    // debugging control logic
    assign j_one_hot_wwl_o = (~debug_analog_dt_idle) ? debug_j_write_wwl : j_one_hot_wwl_cfg_output;
    assign h_wwl_o = (~debug_analog_dt_idle) ? debug_h_write_wwl : h_wwl_cfg_out;

    assign debug_j_write_en_posedge = debug_j_write_en_i & (~debug_j_write_en_dly1);
    assign debug_j_read_en_posedge = debug_j_read_en_i & (~debug_j_read_en_dly1);
    assign debug_spin_write_en_posedge = debug_spin_write_en_i & (~debug_spin_write_en_dly1);
    assign debug_spin_compute_en_posedge = debug_spin_compute_en_i & (~debug_spin_compute_en_dly1);
    assign debug_spin_read_en_posedge = debug_spin_read_en_i & (~debug_spin_reading_en_dly1);

    `FFL(debug_j_write_en_dly1, debug_j_write_en_i, en_i, 1'b0, clk_i, rst_ni)
    `FFL(debug_j_read_en_dly1, debug_j_read_en_i, en_i, 1'b0, clk_i, rst_ni)
    `FFL(debug_spin_write_en_dly1, debug_spin_write_en_i, en_i, 1'b0, clk_i, rst_ni)
    `FFL(debug_spin_reading_en_dly1, debug_spin_read_en_i, en_i, 1'b0, clk_i, rst_ni)
    `FFL(debug_spin_compute_en_dly1, debug_spin_compute_en_i, en_i, 1'b0, clk_i, rst_ni)

    assign spin_valid_o       = debug_spin_read_addr_busy ? 1'b0 : spin_valid_tx;
    assign debug_spin_valid_o = debug_spin_read_addr_busy ? spin_valid_tx : 1'b0;
    assign spin_ready_tx      = debug_spin_read_addr_busy ? 1'b1 : spin_ready_i;

    assign debug_dt_w_idle_o = debug_analog_dt_w_idle;
    assign debug_dt_r_idle_o = debug_analog_dt_r_idle;
    assign debug_spin_w_idle_o    = debug_spin_w_idle;
    assign debug_spin_cmpt_idle_o = debug_spin_feedback_idle;
    assign debug_spin_r_idle_o    = ~debug_spin_read_addr_busy;

    // data path
    assign debug_spin_waddr_o = debug_spin_read_addr_busy ? debug_syn_num_cnt_q[DEBUG_WADDR_WIDTH-1:0] : {DEBUG_WADDR_WIDTH{1'b0}};
    assign debug_spin_o       = debug_spin_read_addr_busy ? spin_o : {NUM_SPIN{1'b0}};

    assign wbl_floating_o = wbl_floating_reg;

    assign spin_wwl_o = (~debug_spin_w_idle) ? debug_spin_wwl : spin_wwl_rx_output;
    assign spin_feedback_o = ((~debug_spin_feedback_idle) | (~debug_spin_r_idle)) ? debug_spin_feedback : spin_feedback_rx_output;
    assign wbl_o = (~debug_analog_dt_w_idle) ? debug_wbl_dt_write :
                   (~debug_spin_w_idle     ) ? debug_wbl_spin : wbl_write_output;
    assign wblb_o = (~debug_analog_dt_w_idle) ? ~wbl_o :
                    (~debug_spin_w_idle     ) ? debug_wblb_spin : wblb_write_output;

    assign analog_macro_cmpt_finish = debug_spin_read_addr_busy ? debug_spin_sync_en : analog_macro_cmpt_finish_rx_out;

    `FFL(wbl_floating_reg, wbl_floating_i, (en_i & debug_dt_configure_enable_i), 'b0, clk_i, rst_ni)
    `FFLARNC(debug_spin_read_addr_busy, 1'b1, debug_spin_read_en_posedge, debug_syn_num_cnt_overflow, 1'b0, clk_i, rst_ni)

    // regular control logic
    assign spin_tx_handshake = spin_valid_o & spin_ready_i;
    assign wbl_write_output = dt_cfg_idle_o ? wbl_spin_expanded : wbl_dt;
    assign wblb_write_output = dt_cfg_idle_o ? '0 : ~wbl_write_output;
    assign wwl_vdd_o = wwl_vdd_reg;
    assign wwl_vread_o = wwl_vread_reg;

    `FFL(wwl_vdd_reg, wwl_vdd_i, (en_i & (analog_wrap_configure_enable_i | debug_dt_configure_enable_i)), 'b0, clk_i, rst_ni)
    `FFL(wwl_vread_reg, wwl_vread_i, (en_i & (analog_wrap_configure_enable_i | debug_dt_configure_enable_i)), 'b0, clk_i, rst_ni)

    generate
        for (i = 0; i < NUM_SPIN; i = i + 1) begin : expand_wbl_spin
            assign wbl_spin_expanded[i*BITDATA +: BITDATA] = {{(BITDATA-1){1'b0}}, wbl_spin[i]} << SPIN_WBL_OFFSET;
        end
    endgenerate

    // debugg spin read addr generator
    step_counter #(
        .COUNTER_BITWIDTH (COUNTER_BITWIDTH >= DEBUG_WADDR_WIDTH ? COUNTER_BITWIDTH : DEBUG_WADDR_WIDTH),
        .PARALLELISM (1)
    ) i_debug_syn_num_cnt (
        .clk_i            (clk_i                                             ),
        .rst_ni           (rst_ni                                            ),
        .en_i             (en_i                                              ),
        .load_i           (debug_spin_configure_enable_i                     ),
        .d_i              (debug_spin_read_num_i                             ),
        .recount_en_i     (debug_spin_read_en_posedge | debug_syn_num_cnt_overflow ),
        .step_en_i        (debug_spin_read_addr_busy && spin_valid_tx        ),
        .q_o              (debug_syn_num_cnt_q                               ),
        .maxed_o          (debug_syn_num_cnt_maxed                           ),
        .overflow_o       (debug_syn_num_cnt_overflow                        )
    );

    // ========================================================================
    // Regular modules
    // ========================================================================
    // analog config module
    analog_cfg #(
        .NUM_SPIN (NUM_SPIN),
        .BITDATA (BITDATA),
        .COUNTER_BITWIDTH (COUNTER_BITWIDTH),
        .PARALLELISM (PARALLELISM)
    ) u_analog_cfg (
        .clk_i                    (clk_i                                     ),
        .rst_ni                   (rst_ni                                    ),
        .en_i                     (en_i                                      ),
        // config interface
        .cfg_configure_enable_i   (analog_wrap_configure_enable_i            ),
        .bypass_data_conversion_i (bypass_data_conversion_i                  ),
        .cycle_per_wwl_high_i     (cycle_per_wwl_high_i                      ),
        .cycle_per_wwl_low_i      (cycle_per_wwl_low_i                       ),
        .cfg_trans_num_i          (cfg_trans_num_i                           ),
        // data config interface <-> digital
        .dt_cfg_enable_i          (dt_cfg_enable_i                           ),
        .j_mem_ren_o              (j_mem_ren_o                               ),
        .j_raddr_o                (j_raddr_o                                 ),
        .j_rdata_i                (j_rdata_i                                 ),
        .h_ren_o                  (h_ren_o                                   ),
        .h_rdata_i                (h_rdata_i                                 ),
        // data config interface -> analog macro
        .j_one_hot_wwl_o          (j_one_hot_wwl_cfg_output                  ),
        .h_wwl_o                  (h_wwl_cfg_out                             ),
        .wbl_o                    (wbl_dt                                    ),
        // status
        .dt_cfg_idle_o            (dt_cfg_idle_o                             )
    );

    // analog rx module
    analog_rx #(
        .NUM_SPIN (NUM_SPIN),
        .COUNTER_BITWIDTH (COUNTER_BITWIDTH)
    ) u_analog_rx (
        .clk_i                    (clk_i                                     ),
        .rst_ni                   (rst_ni                                    ),
        .en_i                     (en_i                                      ),
        // config interface
        .rx_configure_enable_i    (analog_wrap_configure_enable_i            ),
        .cycle_per_spin_write_i   (cycle_per_spin_write_i                    ),
        .spin_wwl_strobe_i        (spin_wwl_strobe_i                         ),
        .spin_feedback_i          (spin_feedback_i                           ),
        .cycle_per_spin_compute_i (cycle_per_spin_compute_i                  ),
        // spin interface: rx <-> digital
        .spin_pop_valid_i         (spin_pop_valid_i                          ),
        .spin_pop_ready_o         (spin_pop_ready_o                          ),
        .spin_pop_i               (spin_pop_i                                ),
        .analog_macro_idle_i      (spin_tx_handshake                         ),
        // spin interface: rx -> analog macro
        .spin_wwl_o               (spin_wwl_rx_output                        ),
        .spin_feedback_o          (spin_feedback_rx_output                   ),
        .wbl_o                    (wbl_spin                                  ),
        // status
        .analog_rx_idle_o         (analog_rx_idle_o                          ),
        .analog_macro_cmpt_finish_o (analog_macro_cmpt_finish_rx_out         )
    );

    // analog tx module: spin read
    analog_tx #(
        .NUM_SPIN (NUM_SPIN),
        .SYNCHRONIZER_PIPEDEPTH (SYNCHRONIZER_PIPEDEPTH)
    ) u_analog_tx_spin (
        .clk_i                    (clk_i                                     ),
        .rst_ni                   (rst_ni                                    ),
        .en_i                     (en_i                                      ),
        // config interface
        .tx_configure_enable_i    (analog_wrap_configure_enable_i            ),
        .synchronizer_pipe_num_i  (synchronizer_pipe_num_i                   ),
        .synchronizer_pipe_num_reg_o (synchronizer_pipe_num_tx_reg           ),
        // spin interface: tx <- analog macro
        .spin_i                   (spin_analog_i                             ),
        // spin interface: rx -> tx
        .analog_macro_cmpt_finish_i (analog_macro_cmpt_finish                ),
        // spin interface: tx <-> digital
        .spin_valid_o             (spin_valid_tx                             ),
        .spin_ready_i             (spin_ready_tx                             ),
        .spin_o                   (spin_o                                    ),
        // status
        .analog_tx_idle_o         (analog_tx_idle_o                          )
    );

    // ========================================================================
    // Debugging modules
    // ========================================================================
    // debug wbl synchronization module: j/h read
    analog_tx #(
        .NUM_SPIN (NUM_SPIN*BITDATA),
        .SYNCHRONIZER_PIPEDEPTH (SYNCHRONIZER_PIPEDEPTH)
    ) u_analog_tx_wbl (
        .clk_i                    (clk_i                                     ),
        .rst_ni                   (rst_ni                                    ),
        .en_i                     (en_i                                      ),
        // config interface
        .tx_configure_enable_i    (debug_dt_configure_enable_i               ),
        .synchronizer_pipe_num_i  (synchronizer_wbl_pipe_num_i               ),
        .synchronizer_pipe_num_reg_o (                                       ),
        // input interface: tx <- analog macro
        .spin_i                      (wbl_read_i                             ),
        // spin interface: rx -> tx
        .analog_macro_cmpt_finish_i  (debug_dt_sync_en                       ),
        // spin interface: tx <-> digital
        .spin_valid_o             (debug_j_read_data_valid_o                 ),
        .spin_ready_i             (1'b1                                      ),
        .spin_o                   (debug_j_read_data_o                       ),
        // status
        .analog_tx_idle_o         (                                          )
    );

    // debug data write/read module
    analog_dt_debug #(
        .NUM_SPIN                 (NUM_SPIN                                  ),
        .BITDATA                  (BITDATA                                   ),
        .COUNTER_BITWIDTH         (COUNTER_BITWIDTH                          )
    ) u_analog_dt_debug (
        .clk_i                    (clk_i                                     ),
        .rst_ni                   (rst_ni                                    ),
        .en_i                     (en_i                                      ),
        // config interface
        .configure_enable_i       (debug_dt_configure_enable_i               ),
        .cycle_per_wwl_high_i     (cycle_per_wwl_high_i                      ),
        .cycle_per_wwl_low_i      (cycle_per_wwl_low_i                       ),
        // debug interface <-> digital
        .debug_wen_i              (debug_j_write_en_posedge                  ),
        .debug_ren_i              (debug_j_read_en_posedge                   ),
        .debug_j_one_hot_wwl_i    (debug_j_one_hot_wwl_i                     ),
        .debug_h_wwl_i            (debug_h_wwl_i                             ),
        .wbl_dt_i                 (debug_wbl_i                               ),
        .debug_dt_sync_en_o       (debug_dt_sync_en                          ),
        // debug interface <-> analog
        .j_one_hot_wwl_o          (debug_j_write_wwl                         ),
        .h_wwl_o                  (debug_h_write_wwl                         ),
        .wbl_o                    (debug_wbl_dt_write                        ),
        .debug_dt_idle_o          (debug_analog_dt_idle                      ),
        .debug_dt_w_idle_o        (debug_analog_dt_w_idle                    ),
        .debug_dt_r_idle_o        (debug_analog_dt_r_idle                    )
    );

    // debug spin write/compute/read module
    analog_spin_debug #(
        .NUM_SPIN (NUM_SPIN),
        .BITDATA (BITDATA),
        .COUNTER_BITWIDTH (COUNTER_BITWIDTH)
    ) u_analog_spin_debug (
        .clk_i                    (clk_i                                     ),
        .rst_ni                   (rst_ni                                    ),
        .en_i                     (en_i                                      ),
        // config interface
        .configure_enable_i       (debug_spin_configure_enable_i             ),
        .cycle_per_spin_write_i   (cycle_per_spin_write_i                    ),
        .cycle_per_spin_compute_i (cycle_per_spin_compute_i                  ),
        .cycle_per_spin_read_i    (debug_cycle_per_spin_read_i               ),
        .spin_read_num_i          (debug_spin_read_num_i                     ),
        .spin_wwl_strobe_i        (spin_wwl_strobe_i                         ),
        .spin_feedback_i          (spin_feedback_i                           ),
        // debug interface <-> digital
        .debug_wen_i              (debug_spin_write_en_posedge               ),
        .debug_feedback_en_i      (debug_spin_compute_en_posedge             ),
        .debug_ren_i              (debug_spin_read_en_posedge                ),
        .wbl_spin_i               (debug_wbl_i                               ),
        .debug_ren_sync_en_o      (debug_spin_sync_en                        ),
        // debug interface <-> analog
        .spin_wwl_o               (debug_spin_wwl                            ),
        .spin_feedback_o          (debug_spin_feedback                       ),
        .wbl_spin_o               (debug_wbl_spin                            ),
        .wblb_spin_o              (debug_wblb_spin                           ),
        // status
        .debug_spin_idle_o        (debug_spin_idle                           ),
        .debug_spin_w_idle_o      (debug_spin_w_idle                         ),
        .debug_spin_feedback_idle_o(debug_spin_feedback_idle                 ),
        .debug_spin_r_idle_o      (debug_spin_r_idle                         )
    );

endmodule
