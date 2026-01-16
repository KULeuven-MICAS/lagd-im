// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Jiacong Sun <jiacong.sun@kuleuven.be>

`timescale 1ns / 1ps

`ifndef DBG
`define DBG 0
`endif

`ifndef VCD_FILE
`define VCD_FILE "tb_digital_macro.vcd"
`endif

`define True 1'b1
`define False 1'b0

`define MODEL_FILE "./data/model_1"
`define FLIP_ICON_FILE "./data/clusters_1"
`define ENERGY_REF_FILE "./data/energy_1"
`define STATE_IN_FILE "./data/states_in_1"
`define STATE_OUT_FILE "./data/states_out_1"

module tb_digital_macro;
    import analog_format_pkg::*;
    import energy_calc_pkg::*;
    import config_pkg::*;

    // testbench parameters
    localparam int CLKCYCLE = 2;
    localparam int NUM_TESTS = 1;

    // dut signals
    logic clk_i;
    logic rst_ni;
    logic en_aw_i, en_fm_i, en_em_i, en_analog_loop_i;
    logic en_i;
    logic config_valid_em_i, config_em_done;
    logic config_valid_fm_i, config_fm_done;
    logic config_valid_aw_i, config_aw_done;
    logic config_galena_done;
    logic config_dut_done;
    logic [ $clog2(NUM_SPIN)-1 : 0 ] config_counter_i;
    logic [ NUM_SPIN-1 : 0 ] config_spin_initial_i;
    logic config_spin_initial_skip_i;
    logic [ COUNTER_BITWIDTH-1 : 0] cfg_trans_num_i;
    logic [ COUNTER_BITWIDTH-1 : 0] cycle_per_wwl_high_i;
    logic [ COUNTER_BITWIDTH-1 : 0] cycle_per_wwl_low_i;
    logic [ COUNTER_BITWIDTH-1 : 0] cycle_per_spin_write_i;
    logic [ COUNTER_BITWIDTH-1 : 0] cycle_per_spin_compute_i;
    logic bypass_data_conversion_i;
    logic [ NUM_SPIN-1 : 0 ] spin_wwl_strobe_i;
    logic [ NUM_SPIN-1 : 0 ] spin_feedback_i;
    logic [ $clog2(SYNCHRONIZER_PIPEDEPTH)-1 : 0 ] synchronizer_pipe_num_i;
    logic dt_cfg_enable_i, dt_cfg_idle_o;
    logic j_mem_ren_o;
    logic [ $clog2(NUM_SPIN / PARALLELISM)-1 : 0 ] j_raddr_o, weight_raddr_o;
    logic [ $clog2(NUM_SPIN / PARALLELISM)-1 : 0 ] j_raddr_ref, weight_raddr_ref;
    logic [ NUM_SPIN*BITJ*PARALLELISM-1 : 0 ] j_rdata_i, weight_i;
    logic [ NUM_SPIN*BITJ*PARALLELISM-1 : 0 ] j_rdata_latched;
    logic h_ren_o;
    logic [ BITH*NUM_SPIN-1 : 0 ] h_rdata_i;
    logic flush_i;
    logic en_comparison_i;
    logic cmpt_en_i;
    logic cmpt_idle_o;
    logic host_readout_i;
    logic flip_ren_o;
    logic [ $clog2(FLIP_ICON_DEPTH)+1-1 : 0 ] flip_raddr_o, flip_raddr_ref;
    logic [ $clog2(FLIP_ICON_DEPTH)+1-1 : 0 ] icon_last_raddr_plus_one_i;
    logic [ NUM_SPIN-1 : 0 ] flip_rdata_i, flip_rdata_latched;
    logic flip_disable_i;
    logic weight_ready_o, weight_valid_i;
    logic [ BITH*NUM_SPIN-1 : 0 ] hbias_i;
    logic [ SCALING_BIT-1 : 0 ] hscaling_i;
    logic [ NUM_SPIN-1 : 0 ] j_one_hot_wwl_o;
    logic h_wwl_o;
    logic [NUM_SPIN*BITJ-1 : 0 ] wbl_o;
    logic [NUM_SPIN*BITJ-1 : 0 ] wblb_o;
    logic [ NUM_SPIN-1 : 0 ] spin_wwl_o;
    logic [NUM_SPIN-1 : 0 ] spin_feedback_o;
    logic [ NUM_SPIN-1 : 0 ] spin_analog_i;
    logic signed [SPIN_DEPTH-1:0] [ENERGY_TOTAL_BIT-1:0] energy_fifo_o;

    // testbench signals
    logic [NUM_SPIN*BITJ-1:0] wbl_copy;
    logic [NUM_SPIN-1:0][NUM_SPIN*BITJ-1:0] weights_in_txt, weights_analog;
    logic [NUM_SPIN/PARALLELISM-1:0][NUM_SPIN*BITJ*PARALLELISM-1:0] weights_in_mem;
    logic [NUM_SPIN*BITH-1:0] hbias_in_reg, hbias_analog;
    logic [SCALING_BIT-1:0] hscaling_in_reg;
    logic [SPIN_DEPTH-1:0] [NUM_SPIN-1:0] spin_initial_states;
    logic [NUM_SPIN*BITDATA-1:0] wbl_i;
    int signed constant;
    logic [IconLastAddrPlusOne-1:0] [NUM_SPIN-1:0] flip_icons_in_mem;
    logic signed [IconLastAddrPlusOne-1+1:0] [SPIN_DEPTH-1:0] [ENERGY_TOTAL_BIT-1:0] energy_fifo_ref;
    logic [IconLastAddrPlusOne-1+1:0] [SPIN_DEPTH-1:0] [NUM_SPIN-1:0] spin_fifo_ref;
    int unsigned total_cycles, transaction_cycles, total_time, transaction_time, start_time, end_time;
    int test_idx;
    logic cmpt_test_start, cmpt_test_end;
    integer dt_write_cycle_cnt_j;
    logic em_fm_handshake, fm_downstream_handshake, em_upstream_handshake;
    logic [SPIN_DEPTH-1:0] [NUM_SPIN-1:0] spin_fifo;

    assign em_fm_handshake = dut.em_mst_valid && dut.fm_slv_ready;
    assign fm_downstream_handshake = dut.fm_mst_valid && dut.muxed_slv_ready;
    assign em_upstream_handshake = dut.muxed_mst_valid && dut.em_slv_ready;
    assign spin_fifo = dut.u_flip_manager.u_spin_fifo_maintainer.spin_fifo_data;

    always_comb begin
        for (int i=0; i < NUM_SPIN; i=i+1) begin
            spin_analog_i[i] = wbl_i[i*BITDATA + SPIN_WBL_OFFSET];
        end
    end

    // module instantiation
    digital_macro #(
        .BITJ                       (BITJ                       ),
        .BITH                       (BITH                       ),
        .NUM_SPIN                   (NUM_SPIN                   ),
        .SCALING_BIT                (SCALING_BIT                ),
        .PARALLELISM                (PARALLELISM                ),
        .ENERGY_TOTAL_BIT           (ENERGY_TOTAL_BIT           ),
        .LITTLE_ENDIAN              (LITTLE_ENDIAN              ),
        .PIPESINTF                  (PIPESINTF                  ),
        .PIPESMID                   (PIPESMID                   ),
        .SPIN_DEPTH                 (SPIN_DEPTH                 ),
        .FLIP_ICON_DEPTH            (FLIP_ICON_DEPTH            ),
        .COUNTER_BITWIDTH           (COUNTER_BITWIDTH           ),
        .SYNCHRONIZER_PIPEDEPTH     (SYNCHRONIZER_PIPEDEPTH     ),
        .SPIN_WBL_OFFSET            (SPIN_WBL_OFFSET            )
    ) dut (
        .clk_i                      (clk_i                      ),
        .rst_ni                     (rst_ni                     ),
        .en_aw_i                    (en_aw_i                    ),
        .en_em_i                    (en_em_i                    ),
        .en_fm_i                    (en_fm_i                    ),
        .en_analog_loop_i           (en_analog_loop_i           ),
        .config_valid_em_i          (config_valid_em_i          ),
        .config_valid_fm_i          (config_valid_fm_i          ),
        .config_valid_aw_i          (config_valid_aw_i          ),
        .config_counter_i           (config_counter_i           ),
        .config_spin_initial_i      (config_spin_initial_i      ),
        .config_spin_initial_skip_i (config_spin_initial_skip_i ),
        .cfg_trans_num_i            (cfg_trans_num_i            ),
        .cycle_per_wwl_high_i       (cycle_per_wwl_high_i       ),
        .cycle_per_wwl_low_i        (cycle_per_wwl_low_i        ),
        .cycle_per_spin_write_i     (cycle_per_spin_write_i     ),
        .cycle_per_spin_compute_i   (cycle_per_spin_compute_i   ),
        .bypass_data_conversion_i   (bypass_data_conversion_i   ),
        .spin_wwl_strobe_i          (spin_wwl_strobe_i          ),
        .spin_feedback_i            (spin_feedback_i            ),
        .synchronizer_pipe_num_i    (synchronizer_pipe_num_i    ),
        .dt_cfg_enable_i            (dt_cfg_enable_i            ),
        .j_mem_ren_o                (j_mem_ren_o                ),
        .j_raddr_o                  (j_raddr_o                  ),
        .j_rdata_i                  (j_rdata_i                  ),
        .h_ren_o                    (h_ren_o                    ),
        .h_rdata_i                  (h_rdata_i                  ),
        .dt_cfg_idle_o              (dt_cfg_idle_o              ),
        .flush_i                    (flush_i                    ),
        .en_comparison_i            (en_comparison_i            ),
        .cmpt_en_i                  (cmpt_en_i                  ),
        .cmpt_idle_o                (cmpt_idle_o                ),
        .host_readout_i             (host_readout_i             ),
        .flip_ren_o                 (flip_ren_o                 ),
        .flip_raddr_o               (flip_raddr_o               ),
        .icon_last_raddr_plus_one_i (icon_last_raddr_plus_one_i ),
        .flip_rdata_i               (flip_rdata_i               ),
        .flip_disable_i             (flip_disable_i             ),
        .weight_ready_o             (weight_ready_o             ),
        .weight_valid_i             (weight_valid_i             ),
        .weight_raddr_o             (weight_raddr_o             ),
        .weight_i                   (weight_i                   ),
        .hbias_i                    (hbias_i                    ),
        .hscaling_i                 (hscaling_i                 ),
        .j_one_hot_wwl_o            (j_one_hot_wwl_o            ),
        .h_wwl_o                    (h_wwl_o                    ),
        .wbl_o                      (wbl_o                      ),
        .wblb_o                     (wblb_o                     ),
        .spin_wwl_o                 (spin_wwl_o                 ),
        .spin_feedback_o            (spin_feedback_o            ),
        .spin_analog_i              (spin_analog_i              ),
        .energy_fifo_o              (energy_fifo_o              )
    );

    // Clock generation
    initial begin
        clk_i = 0;
        forever #(CLKCYCLE/2) clk_i = ~clk_i;
    end

    assign en_aw_i = en_i;
    assign en_em_i = en_i;
    assign en_fm_i = en_i;

    // Reset and en_i generation
    initial begin
        rst_ni = 0;
        en_i = 0;
        en_analog_loop_i = 0;
        #(5 * CLKCYCLE);
        rst_ni = 1;
        #(5 * CLKCYCLE);
        en_i = 1;
        en_analog_loop_i = EnableAnalogLoop;
    end

    // Run tests
    initial begin
        if (`DBG) begin
            $display("Debug mode enabled. Running with detailed output.");
            $dumpfile(`VCD_FILE);
            $dumpvars(5, tb_digital_macro); // Dump all variables in testbench module
            $timeformat(-9, 1, " ns", 9);
            #(600 * CLKCYCLE); // To avoid generating huge VCD files
            $display("[Time: %t] Testbench timeout reached. Ending simulation.", $time);
            $finish;
        end
        else begin
            $timeformat(-9, 1, " ns", 9);
            #(2_000_000 * CLKCYCLE);
            $display("[Time: %t] Testbench timeout reached. Ending simulation.", $time);
            $finish;
        end
    end

    // ========================================================================
    // Logics
    // ========================================================================
    assign j_rdata_i = j_rdata_latched;
    assign flip_rdata_i = flip_rdata_latched;

    // ========================================================================
    // Functions
    // ========================================================================

    // ========================================================================
    // Sub-tasks
    // ========================================================================
    // Generate weight model
    task automatic gen_model();
        // generate random J
        // note: the most negative code (-8), though supported by the digital logic, is not supported by the analog part and its related data convertor
        // therefore, we avoid generating this code here
        for (int i = 0; i < NUM_SPIN; i = i + 1) begin
            for (int j = 0; j < NUM_SPIN; j = j + 1) begin
                if (LITTLE_ENDIAN) begin
                    if (j == i) begin
                        weights_in_txt[i][j*BITJ +: BITJ] = 'd0;
                    end else begin
                        do begin
                            weights_in_txt[i][j*BITJ +: BITJ] = $urandom_range(0, (1<<BITJ)-1);
                        end while (weights_in_txt[i][j*BITJ +: BITJ] == {1'b1, {BITJ-1{1'b0}}}); // avoid generating the invalid code
                    end
                end else begin
                    if (j == NUM_SPIN - 1 - i) begin
                        weights_in_txt[i][j*BITJ +: BITJ] = 'd0;
                    end else begin
                        do begin
                            weights_in_txt[i][j*BITJ +: BITJ] = $urandom_range(0, (1<<BITJ)-1);
                        end while (weights_in_txt[i][j*BITJ +: BITJ] == {1'b1, {BITJ-1{1'b0}}}); // avoid generating the invalid code
                    end
                end
            end
        end
        // map to memory format
        for (int i = 0; i < NUM_SPIN/PARALLELISM; i = i + 1) begin
            for (int j = 0; j < PARALLELISM; j = j + 1) begin
                weights_in_mem[i][j*NUM_SPIN*BITJ +: NUM_SPIN*BITJ] = weights_in_txt[i*PARALLELISM + j];
            end
        end
        // generate random h
        for (int i = 0; i < NUM_SPIN; i = i + 1) begin
            do begin
                hbias_in_reg[i*BITH +: BITH] = $urandom_range(0, (1<<BITH)-1);
            end while (hbias_in_reg[i*BITH +: BITH] == {1'b1, {BITH-1{1'b0}}}); // avoid generating the invalid code
        end
        // generate random scaling factor
        hscaling_in_reg = 1 << ($urandom_range(0, SCALING_BIT-1));
    endtask

    // Generate flipping icons
    task automatic gen_flip_icons();
        for (int i = 0; i < IconLastAddrPlusOne; i = i + 1) begin
            for (int j = 0; j < NUM_SPIN; j = j + 1) begin
                flip_icons_in_mem[i][j] = $urandom_range(0, 1);
            end
        end
    endtask

    // Generate initial spin states
    task automatic gen_initial_states();
        for (int i = 0; i < SPIN_DEPTH; i = i + 1) begin
            for (int j = 0; j < NUM_SPIN; j = j + 1) begin
                spin_initial_states[i][j] = $urandom_range(0, 1);
            end
        end
    endtask

    // Generate reference model for spin fifo
    task automatic gen_ref_energy_spin_fifo();
        logic signed [ENERGY_TOTAL_BIT-1:0] energy_temp = 0;
        integer spin_fifo_pointer = 0;
        logic [NUM_SPIN-1:0] current_spin_state;

        for (int i = 0; i < SPIN_DEPTH; i = i + 1) begin
            spin_fifo_ref[0][i] = spin_initial_states[i];
            energy_fifo_ref[0][i] = {1'b0, {(ENERGY_TOTAL_BIT-1){1'b1}}};
        end

        for (int icon_idx = 1; icon_idx <= IconLastAddrPlusOne; icon_idx = icon_idx + 1) begin
            current_spin_state = FlipDisable ? spin_fifo_ref[icon_idx-1][spin_fifo_pointer] :
                spin_fifo_ref[icon_idx-1][spin_fifo_pointer] ^ flip_icons_in_mem[icon_idx-1];
            // calc energy
            energy_temp = calculate_h_energy(
                current_spin_state,
                weights_in_txt,
                hbias_in_reg,
                hscaling_in_reg
            );
            // update fifo
            for (int j = 0; j < SPIN_DEPTH; j = j + 1) begin
                if (j != spin_fifo_pointer) begin
                    spin_fifo_ref[icon_idx][j] = spin_fifo_ref[icon_idx-1][j];
                    energy_fifo_ref[icon_idx][j] = energy_fifo_ref[icon_idx-1][j];
                end
            end
            if (EnComparison == `False) begin: always_update_fifo
                energy_fifo_ref[icon_idx][spin_fifo_pointer] = energy_temp;
                spin_fifo_ref[icon_idx][spin_fifo_pointer] = current_spin_state;
            end else begin: conditional_update_fifo
                if (energy_temp < $signed(energy_fifo_ref[icon_idx-1][spin_fifo_pointer])) begin
                    energy_fifo_ref[icon_idx][spin_fifo_pointer] = energy_temp;
                    spin_fifo_ref[icon_idx][spin_fifo_pointer] = current_spin_state;
                end else begin
                    energy_fifo_ref[icon_idx][spin_fifo_pointer] = energy_fifo_ref[icon_idx-1][spin_fifo_pointer];
                    spin_fifo_ref[icon_idx][spin_fifo_pointer] = spin_fifo_ref[icon_idx-1][spin_fifo_pointer];
                end
            end
            // update pointer
            spin_fifo_pointer = (spin_fifo_pointer + 1) % SPIN_DEPTH;
        end
    endtask

    // Sub-task for AW config interface
    task automatic aw_config_interface();
        wait (rst_ni == 0);
        config_aw_done = 0;
        config_valid_aw_i = 0;
        cfg_trans_num_i = 'd0;
        cycle_per_wwl_high_i = 'd0;
        cycle_per_spin_write_i = 'd0;
        cycle_per_spin_compute_i = 'd0;
        synchronizer_pipe_num_i = 'd0;
        spin_wwl_strobe_i = 'd0;
        spin_feedback_i = 'd0;
        bypass_data_conversion_i = BypassDataConversion;
        // Apply configuration
        wait (rst_ni == 1 && en_i == 1);
        @(posedge clk_i);
        // $display("[Time: %t] AW configuration starts.", $time);
        config_valid_aw_i = 1;
        cfg_trans_num_i = NUM_SPIN/PARALLELISM-1+1;
        cycle_per_wwl_high_i = CyclePerWwlHigh - 1;
        cycle_per_wwl_low_i = CyclePerWwlLow - 1;
        cycle_per_spin_write_i = CyclePerSpinWrite - 1;
        cycle_per_spin_compute_i = CyclePerSpinCompute - 1;
        synchronizer_pipe_num_i = SynchronizerPipeNum;;
        spin_wwl_strobe_i = SpinWwlStrobe;
        spin_feedback_i = SpinFeedback;
        @(posedge clk_i);
        config_valid_aw_i = 0;
        config_aw_done = 1;
        $display("[Time: %t] AW configuration finished.", $time);
    endtask

    // Sub-task for EM config interface
    task automatic em_config_interface();
        wait (rst_ni == 0);
        config_em_done = 0;
        config_valid_em_i = 0;
        config_counter_i = 'd0;
        wait (rst_ni == 1 && en_i == 1 && config_aw_done == 1);
        @(posedge clk_i);
        // $display("[Time: %t] EM configuration starts.", $time);
        config_valid_em_i = 1;
        config_counter_i = EmCfgCounter;
        @(posedge clk_i);
        config_valid_em_i = 0;
        config_em_done = 1;
        $display("[Time: %t] EM configuration finished.", $time);
    endtask

    // Sub-task for FM config interface
    task automatic fm_config_interface();
        wait (rst_ni == 0);
        config_fm_done = 0;
        config_valid_fm_i = 0;
        config_spin_initial_i = 'd0;
        config_spin_initial_skip_i = `False;
        flush_i = Flush;
        en_comparison_i = EnComparison;
        icon_last_raddr_plus_one_i = IconLastAddrPlusOne;
        flip_disable_i = FlipDisable;
        wait (rst_ni == 1 && en_i == 1 && config_em_done == 1);
        @(posedge clk_i);
        // $display("[Time: %t] FM configuration starts.", $time);
        for (int i = 0; i < SPIN_DEPTH; i = i + 1) begin
            config_valid_fm_i = 1;
            config_spin_initial_i = spin_initial_states[i];
            config_spin_initial_skip_i = `False;
            @(posedge clk_i);
        end
        config_valid_fm_i = 0;
        config_fm_done = 1;
        $display("[Time: %t] FM configuration finished.", $time);
    endtask

    // Sub-task for galena config
    task automatic galena_config_interface();
        wait (rst_ni == 0);
        config_galena_done = 0;
        dt_cfg_enable_i = 0;
        wait (rst_ni == 1 && en_i == 1 && config_aw_done == 1 && config_em_done == 1 && config_fm_done == 1);
        @(posedge clk_i);
        $display("[Time: %t] Galena configuration starts.", $time);
        dt_cfg_enable_i = 1;
        @(posedge clk_i);
        dt_cfg_enable_i = 0;
        @(posedge clk_i);
        wait (dt_cfg_idle_o == 1);
        config_galena_done = 1;
        $display("[Time: %t] Galena configuration finished.", $time);
    endtask

    // Sub-task for monitoring config done
    task automatic monitor_config_done();
        wait (rst_ni == 0);
        config_dut_done = 0;
        wait (config_aw_done == 1 && config_em_done == 1 && config_fm_done == 1 && config_galena_done == 1);
        @(posedge clk_i);
        config_dut_done = 1;
        $display("[Time: %t] DUT configuration is done.", $time);
    endtask

    // ========================================================================
    // Tasks
    // ========================================================================
    // Pre-compute configuration
    task automatic pre_compute_config();
        fork
            gen_model(); // generate weight model
            gen_flip_icons(); // generate flipping icons
            gen_initial_states(); // generate initial spin states
            gen_ref_energy_spin_fifo(); // generate reference energy and spin fifo
            aw_config_interface(); // configure aw module
            em_config_interface(); // configure em module
            fm_config_interface(); // configure fm module
            galena_config_interface(); // configure galena module
            monitor_config_done(); // monitor if dut config is done
        join_none
    endtask

    // Interface: analog_wrap <-> galena spin wwl
    task automatic galena_spin_wwl_interface();
        integer galena_spin_write_cycle_cnt = 0;
        wait (rst_ni == 1 && en_i == 1 && config_galena_done == 1);
        forever begin
            @(posedge clk_i);
            if ($countbits(spin_wwl_o, '1) == NUM_SPIN) begin: timer_start
                if (galena_spin_write_cycle_cnt == -1) begin: spin_write_finished
                    galena_spin_write_cycle_cnt = galena_spin_write_cycle_cnt;
                end else begin
                    if (galena_spin_write_cycle_cnt == (CyclePerSpinWrite-1)) begin: spin_write_finishing
                        wbl_copy = wbl_o;
                        galena_spin_write_cycle_cnt = -1;
                    end else begin: spin_write_ongoing
                        galena_spin_write_cycle_cnt = galena_spin_write_cycle_cnt + 1;
                    end
                end
            end else begin: spin_wwl_idle
                galena_spin_write_cycle_cnt = 0;
            end
        end
    endtask

    // Interface: analog_wrap <-> galena output
    task automatic galena_spin_output_interface();
        integer galena_spin_cmpt_cycle_cnt = 0;
        wbl_i = 'd0;
        wait (rst_ni == 1 && en_i == 1 && config_galena_done == 1);
        forever begin
            @(posedge clk_i);
            wbl_i = 'z;
            if ($countbits(spin_wwl_o, '1) == NUM_SPIN) begin: timer_start
                while (galena_spin_cmpt_cycle_cnt < (CyclePerSpinWrite+CyclePerSpinCompute-2)) begin
                    galena_spin_cmpt_cycle_cnt = galena_spin_cmpt_cycle_cnt + 1;
                    if (galena_spin_cmpt_cycle_cnt >= CyclePerSpinWrite) begin
                        // during compute cycles, generate random wbl_i
                        for (int i = 0; i < NUM_SPIN * BITDATA; i = i + 1) begin
                            wbl_i[i] = $urandom_range(0, 1);
                        end
                    end
                    @(posedge clk_i);
                end
                // after compute cycles, output wbl_i
                wbl_i = wbl_copy;
                galena_spin_cmpt_cycle_cnt = 0;
            end
        end
    endtask

    // Interface: J mem <-> analog wrap and energy monitor
    task automatic j_mem_interface();
        j_rdata_latched = 'd0;
        weight_valid_i = 0;
        weight_i = 'd0;
        j_raddr_ref = 'd0;
        weight_raddr_ref = 'd0;
        wait (rst_ni == 1 && en_i == 1);
        @(posedge clk_i);
        weight_valid_i = 1;
        weight_i = weights_in_mem[0];
        forever begin
            @(posedge clk_i);
            // Interface to analog wrap: standard 1-cycle-delay memory interface
            if (j_mem_ren_o == 1) begin
                if (j_raddr_o != j_raddr_ref) begin
                    $fatal(1, "[Time: %t] Error: J memory read address mismatch. Expected: %0d, Got: %0d",
                        $time, j_raddr_ref, j_raddr_o);
                end
                j_rdata_latched = weights_in_mem[j_raddr_o];
                j_raddr_ref = j_raddr_ref + 1;
            end
            // Interface to energy monitor: valid-ready interface
            if (weight_ready_o == 1) begin
                if (weight_raddr_o != weight_raddr_ref) begin
                    $fatal(1, "[Time: %t] Error: Weight memory read address mismatch. Expected: 'h%0h, Got: 'h%0h",
                        $time, weight_raddr_ref, weight_raddr_o);
                end
                weight_raddr_ref = weight_raddr_ref + 1;
                weight_i = weights_in_mem[weight_raddr_ref];
            end
        end
    endtask

    // H and scaling factor reg interface
    task automatic h_sfc_reg_interface();
        h_rdata_i = hbias_in_reg; // for analog onloading
        hbias_i = hbias_in_reg; // for digital energy monitor
        hscaling_i = hscaling_in_reg;
    endtask

    // Flip icon memory interface
    task automatic flip_mem_interface();
        flip_rdata_latched = 'd0;
        flip_raddr_ref = 'd0;
        wait (rst_ni == 1 && en_i == 1 && config_dut_done == 1);
        forever begin
            @(posedge clk_i);
            if (flip_ren_o == 1) begin
                if (flip_raddr_o != flip_raddr_ref) begin
                    $fatal(1, "[Time: %t] Error: Flip icon memory read address mismatch. Expected: %0d, Got: %0d",
                        $time, flip_raddr_ref, flip_raddr_o);
                end
                flip_rdata_latched = flip_icons_in_mem[flip_raddr_o];
                flip_raddr_ref = flip_raddr_ref + 1;
            end
        end
    endtask

    // Host interface
    task automatic host_interface();
        host_readout_i = 0;
        test_idx = 0;
        cmpt_en_i = 0;
        cmpt_test_start = 0;
        cmpt_test_end = 0;
        wait (rst_ni == 1 && en_i == 1 && config_dut_done == 1);
        @(posedge clk_i);
        cmpt_test_start = 1;
        while (test_idx < NUM_TESTS) begin
            cmpt_en_i = 1;
            @(posedge clk_i);
            cmpt_en_i = 0;
            @(posedge clk_i);
            wait (cmpt_idle_o == 1);
            @(posedge clk_i);
            host_readout_i = 1;
            @(posedge clk_i);
            host_readout_i = 0;
            // wait some cycles between tests
            repeat (5) @(posedge clk_i);
            test_idx = test_idx + 1;
        end
        @(posedge clk_i);
        cmpt_test_end = 1;
    endtask

    // ========================================================================
    // Checks
    // ========================================================================
    // Task for analog galena interface: config data check: j
    task automatic analog_interface_config_check_j();
        integer config_test_correct_cnt_j = 0;
        integer galena_addr_idx = 0;
        dt_write_cycle_cnt_j = 0;
        while (config_test_correct_cnt_j < 1) begin
            wait (dt_cfg_enable_i == 1);
            @(posedge clk_i);
            // check if j and h are loaded correctly
            while (galena_addr_idx < NUM_SPIN) begin
                wait (j_one_hot_wwl_o != 0);
                while (dt_write_cycle_cnt_j < CyclePerWwlHigh) begin
                    @(negedge clk_i);
                    // monitor if j_one_hot_wwl_o remains valid for the dedefined cycles
                    if (j_one_hot_wwl_o == 0 && dt_write_cycle_cnt_j != 0) begin
                        $fatal(1, "[Time: %t] Warning: j_one_hot_wwl_o switches to zero during dt write cycle %0d for galena_addr_idx %0d",
                            $time, dt_write_cycle_cnt_j, galena_addr_idx);
                    end
                    if (|j_one_hot_wwl_o) begin
                        // check if one-hot encoded and matches galena_addr_idx
                        if ($countbits(j_one_hot_wwl_o, '1) != 1)
                            $fatal(1, "[Time: %t] Error: j_one_hot_wwl_o is not one-hot encoded, j_one_hot_wwl_o: 'b%b", $time, j_one_hot_wwl_o);
                        if (j_one_hot_wwl_o[galena_addr_idx] != 1'b1) begin
                            $fatal(1, "[Time: %t] Error: j_one_hot_wwl_o does not match galena_addr_idx, j_one_hot_wwl_o: 'b%b, galena_addr_idx: 'd%0d",
                                $time, j_one_hot_wwl_o, galena_addr_idx);
                        end
                        dt_write_cycle_cnt_j = dt_write_cycle_cnt_j + 1;
                    end
                end
                for (int i=0; i<NUM_SPIN; i=i+1) begin
                    if (bypass_data_conversion_i) begin: exact_copy_of_analog_data
                        weights_analog[galena_addr_idx][i*BITDATA +: BITDATA]
                            = wbl_o[i*BITDATA +: BITDATA];
                    end else begin: convert_data_format_for_checker
                        weights_analog[galena_addr_idx][i*BITDATA +: BITDATA]
                            = analog_to_signed_int(wbl_o[i*BITDATA +: BITDATA]);
                    end
                end
                // compare data to reference
                if (weights_analog[galena_addr_idx] != weights_in_txt[galena_addr_idx]) begin
                    $fatal(1, "[Time: %t] Error: Weights mismatch at galena_addr_idx %0d. Expected: 'h%h, Got: 'h%h",
                        $time, galena_addr_idx, weights_in_txt[galena_addr_idx], weights_analog[galena_addr_idx]);
                end
                dt_write_cycle_cnt_j = 0;
                galena_addr_idx = galena_addr_idx + 1;
            end
            config_test_correct_cnt_j = config_test_correct_cnt_j + 1;
            galena_addr_idx = 0;
        end
        // after all config tests
        $display("----------------------------------------");
        $display("Config Scoreboard [Time %0d ns]: %0d/%0d correct, %0d/%0d errors",
            $time, config_test_correct_cnt_j, 1, 1 - config_test_correct_cnt_j, 1);
        $display("----------------------------------------");
    endtask

    // Task for analog galena interface: config data check: h
    task automatic analog_interface_config_check_h();
        integer dt_write_cycle_cnt_hbias = 0;
        integer config_test_correct_cnt_h = 0;
        while (config_test_correct_cnt_h < 1) begin
            wait (rst_ni == 1 && en_i == 1);
            dt_write_cycle_cnt_hbias = 0;
            wait (dt_cfg_enable_i == 1);
            while (dt_write_cycle_cnt_hbias <  CyclePerWwlHigh) begin
                @(negedge clk_i);
                // monitor if h_wwl_o remains valid for the dedefined cycles
                if (h_wwl_o == 0 && dt_write_cycle_cnt_hbias != 0) begin
                    $fatal(1, "[Time: %t] Warning: h_wwl_o switches to zero during dt write cycle %0d for hbias",
                        $time, dt_write_cycle_cnt_hbias);
                end
                if (h_wwl_o == 1) begin
                    dt_write_cycle_cnt_hbias = dt_write_cycle_cnt_hbias + 1;
                end
            end
            // after dt write cycles, check hbias
            for (int i=0; i<NUM_SPIN; i=i+1) begin
                if (bypass_data_conversion_i) begin
                    hbias_analog[i*BITDATA +: BITDATA]
                    = wbl_o[i*BITDATA +: BITDATA];
                end else begin
                    hbias_analog[i*BITDATA +: BITDATA]
                        = analog_to_signed_int(wbl_o[i*BITDATA +: BITDATA]);
                end
            end
            // compare data to reference
            if (hbias_analog != hbias_in_reg) begin
                $fatal(1, "[Time: %t] Error: Hbias mismatch. Expected: 'h%h, Got: 'h%h",
                    $time, hbias_in_reg, hbias_analog);
            end
            config_test_correct_cnt_h = config_test_correct_cnt_h + 1;
        end
    endtask

    // Task for spin_wwl_o check
    task automatic spin_wwl_check();
        integer spin_wwl_cycle_cnt;
        spin_wwl_cycle_cnt = 0;
        wait (rst_ni == 1 && en_i == 1 && config_galena_done == 1);
        @(negedge clk_i);
        forever begin
            @(negedge clk_i);
            if ($countbits(spin_wwl_o, '1) != 0) begin
                if ($countbits(spin_wwl_o, '1) != NUM_SPIN) begin
                    $fatal(1, "[Time: %t] Error: spin_wwl_o is not all-one when enabled, spin_wwl_o: 'b%b",
                        $time, spin_wwl_o);
                end
                while (spin_wwl_cycle_cnt < CyclePerSpinWrite) begin
                    if (spin_wwl_cycle_cnt > 0 && $countbits(spin_wwl_o, '1) != NUM_SPIN) begin
                        $fatal(1, "[Time: %t] Error: spin_wwl_o is not all-one during spin write cycle %0d, spin_wwl_o: 'b%b",
                            $time, spin_wwl_cycle_cnt, spin_wwl_o);
                    end
                    spin_wwl_cycle_cnt = spin_wwl_cycle_cnt + 1;
                    @(negedge clk_i);
                end
                spin_wwl_cycle_cnt = 0;
            end
        end
    endtask

    // Check energy and spin fifo content
    task automatic energy_spin_fifo_check();
        integer test_correct_cnt = 0;
        integer check_idx = 0;
        wait (cmpt_test_start == 1);
        while (check_idx < IconLastAddrPlusOne) begin
            wait (dut.u_flip_manager.spin_maintainer_push_valid == 1 & dut.u_flip_manager.spin_maintainer_push_ready == 1);
            // wait 1 cycle for fifo to update
            @(posedge clk_i);
            // switch to negedge to observe signals
            @(negedge clk_i);
            // check energy fifo
            for (int depth_idx = 0; depth_idx < SPIN_DEPTH; depth_idx = depth_idx + 1) begin
                if (energy_fifo_o[depth_idx] !== energy_fifo_ref[check_idx+1][depth_idx]) begin
                    $fatal(1, "[Time: %t] Error: Energy fifo mismatch at check_idx 'd%0d, depth_idx 'd%0d. Expected: 'h%h, Got: 'h%h, weights: 'h%h, hbias: 'h%h, hscaling: 'h%h",
                        $time, check_idx, depth_idx, energy_fifo_ref[check_idx+1][depth_idx], energy_fifo_o[depth_idx], weights_in_txt, hbias_in_reg, hscaling_in_reg);
                end
                // check spin fifo
                if (spin_fifo[depth_idx] !== spin_fifo_ref[check_idx+1][depth_idx]) begin
                    $fatal(1, "[Time: %t] Error: Spin fifo mismatch at check_idx 'd%0d, depth_idx 'd%0d. Expected: 'h%0d, Got: 'h%0d",
                        $time, check_idx, depth_idx, spin_fifo_ref[check_idx+1][depth_idx], spin_fifo[depth_idx]);
                end
            end
            test_correct_cnt = test_correct_cnt + 1;
            check_idx = check_idx + 1;
        end
        // after all tests
        $display("----------------------------------------");
        $display("Computation Scoreboard [Time %0d ns]: %0d/%0d correct, %0d/%0d errors",
            $time, test_correct_cnt, IconLastAddrPlusOne, IconLastAddrPlusOne - test_correct_cnt, IconLastAddrPlusOne);
        $display("----------------------------------------");
    endtask

    // Cmpt enable and timer
    task automatic cmpt_enable_and_timer();
        wait (rst_ni == 0);
        total_cycles = 0;
        transaction_cycles = 0;
        total_time = 0;
        transaction_time = 0;
        start_time = 0;
        end_time = 0;
        while (test_idx < NUM_TESTS) begin
            wait (cmpt_test_start == 1);
            start_time = $time;
            @(posedge clk_i);
            wait (cmpt_test_end == 1);
            end_time = $time;
            // calculate compute cycles
            total_time = end_time - start_time;
            total_cycles = total_time / CLKCYCLE;
            transaction_cycles = total_cycles / IconLastAddrPlusOne;
            transaction_time = transaction_cycles * CLKCYCLE;
            $display("@@@@@@ Timer per Computation @@@@@@@@@@@@");
            $display("Timer [Time %0d ns]: start time: %0d ns, end time: %0d ns, duration: %0d ns, flips: %0d",
                $time, start_time, end_time, total_time, IconLastAddrPlusOne);
            $display("Timer [Time %0d ns]: Total cycles: %0d cc [%0d ns], Cycles/flip: %0d cc [%0d ns]",
                $time, total_cycles, total_time, transaction_cycles, transaction_time);
            $display("@@@@@@ Timer per Computation @@@@@@@@@@@@");
        end
        $finish;
    endtask

    // ========================================================================
    // Event execution
    // ========================================================================
    initial begin
        fork
            pre_compute_config(); // configure aw, em, fm modules
            // interfaces
            galena_spin_wwl_interface();
            host_interface();
            galena_spin_output_interface();
            j_mem_interface();
            h_sfc_reg_interface();
            flip_mem_interface();
            // checks
            analog_interface_config_check_j();
            analog_interface_config_check_h();
            spin_wwl_check();
            energy_spin_fifo_check();
            // timer
            cmpt_enable_and_timer();
        join_none
    end

endmodule
