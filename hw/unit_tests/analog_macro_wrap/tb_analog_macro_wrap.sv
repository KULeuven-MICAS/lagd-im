// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Jiacong Sun <jiacong.sun@kuleuven.be>

`timescale 1ns / 1ps

`ifndef DBG
`define DBG 0
`endif

`ifndef VCD_FILE
`define VCD_FILE "tb_analog_macro_wrap.vcd"
`endif

`ifndef SYN
`define SYN 0
`endif

module tb_analog_macro_wrap;

    // module parameters
    localparam int NUM_SPIN = 16; // number of spins
    localparam int BITDATA = 4; // bit width of J and h, sfc
    localparam int COUNTER_BITWIDTH = 8;
    localparam int SYNCHRONIZER_PIPE_DEPTH = 3;
    localparam int DEBUG_WADDR_WIDTH = $clog2(1024); // width of debug spin read address
    localparam int PARALLELISM = 4; // number of parallel data in J memory
    localparam int SPIN_WBL_OFFSET = 0; // offset of spin wbl in the wbl data from digital macro (must less than BITDATA)
    localparam int J_ADDRESS_WIDTH = $clog2(NUM_SPIN / PARALLELISM);
    localparam int OnloadingTestNum = 2; // number of onloading tests
    localparam int CmptTestNum = 2; // number of compute tests
    localparam int DebugTestNum = 2;

    // testbench parameters
    localparam int CLKCYCLE = 2;

    // dut run-time configuration
    localparam int CyclePerWwlHigh = 3;
    localparam int CyclePerWwlLow = 3;
    localparam int CyclePerSpinWrite = 3;
    localparam int CyclePerSpinCompute = 5;
    localparam int SynchronizerPipeNum = 3;
    localparam int SpinWwlStrobe = {(NUM_SPIN){1'b1}}; // all spins enabled
    localparam int SpinFeedback = {(NUM_SPIN){1'b1}}; // all spins in feedback mode

    // testbench internal signals
    logic clk_i;
    logic rst_ni;
    logic en_i;
    logic analog_wrap_configure_enable_i;
    logic [COUNTER_BITWIDTH-1:0] cfg_trans_num_i;
    logic [COUNTER_BITWIDTH-1:0] cycle_per_wwl_high_i, cycle_per_wwl_low_i;
    logic [COUNTER_BITWIDTH-1:0] cycle_per_spin_write_i;
    logic [COUNTER_BITWIDTH-1:0] cycle_per_spin_compute_i;
    logic bypass_data_conversion_i;
    logic [NUM_SPIN-1:0] spin_wwl_strobe_i;
    logic [NUM_SPIN-1:0] spin_feedback_i;
    logic [$clog2(SYNCHRONIZER_PIPE_DEPTH)-1:0] synchronizer_pipe_num_i;
    logic [$clog2(SYNCHRONIZER_PIPE_DEPTH)-1:0] synchronizer_wbl_pipe_num_i;
    logic [NUM_SPIN*BITDATA-1:0] wbl_floating_i;
    logic dt_cfg_enable_i;
    logic j_mem_ren_o;
    logic [J_ADDRESS_WIDTH-1:0] j_raddr_o;
    logic [NUM_SPIN*BITDATA*PARALLELISM-1:0] j_rdata_i, j_rdata_latched;
    logic h_ren_o;
    logic [NUM_SPIN*BITDATA-1:0] h_rdata_i, hbias_in_reg;
    logic [NUM_SPIN-1:0] j_one_hot_wwl_o;
    logic h_wwl_o;
    logic [NUM_SPIN*BITDATA-1:0] wbl_copy, wbl_floating_o;
    logic [NUM_SPIN*BITDATA-1:0] wbl_o, wblb_o;
    logic [NUM_SPIN*BITDATA-1:0] wbl_read_i;
    logic spin_pop_valid_i;
    logic spin_pop_ready_o;
    logic spin_pop_handshake;
    logic spin_push_handshake;
    logic [NUM_SPIN-1:0] spin_pop_i, spin_pop_ref;
    logic spin_pop_ref_valid;
    logic [NUM_SPIN-1:0] spin_wwl_o;
    logic [NUM_SPIN-1:0] spin_feedback_o;
    logic [NUM_SPIN*BITDATA-1:0] wbl_i; // used only in testbench reference model
    logic [NUM_SPIN-1:0] spin_analog_i;
    logic spin_valid_o;
    logic spin_ready_i;
    logic [NUM_SPIN-1:0] spin_o;
    logic dt_cfg_idle_o;
    logic analog_rx_idle_o;
    logic analog_tx_idle_o;
    logic [COUNTER_BITWIDTH-1:0] debug_cycle_per_synchronization_i;
    logic [COUNTER_BITWIDTH-1:0] debug_synchronization_num_i;
    // debugging interface
    logic debug_j_write_en_i;
    logic debug_j_read_en_i;
    logic [NUM_SPIN-1:0] debug_j_one_hot_wwl_i;
    logic [$clog2(NUM_SPIN)-1:0] debug_j_analog_waddr, debug_j_analog_raddr;
    logic debug_h_wwl_i;
    logic [NUM_SPIN*BITDATA-1:0] debug_wbl_i;
    logic debug_spin_write_en_i;
    logic [NUM_SPIN-1:0] debug_spin_wwl_i;
    logic [NUM_SPIN-1:0] debug_spin_feedback_i;
    logic debug_spin_read_en_i;
    logic debug_spin_read_busy_o;
    logic debug_spin_valid_o;
    logic [DEBUG_WADDR_WIDTH-1:0] debug_spin_waddr_o;
    logic [NUM_SPIN-1:0] debug_spin_o;
    logic debug_j_read_data_valid_o;
    logic [NUM_SPIN*BITDATA-1:0] debug_j_read_data_o;

    logic config_aw_done;
    logic config_galena_done;
    logic debug_galena_done;
    logic [NUM_SPIN/PARALLELISM-1:0][NUM_SPIN*BITDATA*PARALLELISM-1:0] weights_in_mem;
    logic [NUM_SPIN-1:0][NUM_SPIN*BITDATA-1:0] weights_in_mem_ordered, weights_analog;
    logic [NUM_SPIN*BITDATA-1:0] hbias_analog;
    logic [ $clog2(NUM_SPIN / PARALLELISM)-1 : 0 ] j_raddr_ref;
    integer galena_addr_idx;
    integer dt_write_cycle_cnt_j, dt_write_cycle_cnt_hbias;
    integer onloading_test_idx;
    integer cmpt_test_idx;
    integer galena_spin_write_cycle_cnt;
    integer config_test_correct_cnt_j, config_test_correct_cnt_h;
    integer cmpt_correct_cnt, cmpt_error_cnt;
    integer spin_pop_handshake_cnt;
    logic debug_j_write_en_dly1, debug_j_read_en_dly1, debug_spin_write_en_dly1, debug_spin_read_en_dly1;
    logic debug_j_write_en_posedge, debug_j_read_en_posedge, debug_spin_write_en_posedge, debug_spin_read_en_posedge;
    integer debug_test_idx;
    integer debug_dt_write_cycle_cnt_j;

    assign spin_pop_handshake = spin_pop_valid_i & spin_pop_ready_o;
    assign spin_push_handshake = spin_valid_o & spin_ready_i;

    assign debug_j_write_en_posedge = debug_j_write_en_i & (~debug_j_write_en_dly1);
    assign debug_j_read_en_posedge = debug_j_read_en_i & (~debug_j_read_en_dly1);
    assign debug_spin_write_en_posedge = debug_spin_write_en_i & (~debug_spin_write_en_dly1);
    assign debug_spin_read_en_posedge = debug_spin_read_en_i & (~debug_spin_read_en_dly1);

    always_comb begin
        for (int i=0; i < NUM_SPIN; i=i+1) begin
            spin_analog_i[i] = wbl_i[i*BITDATA + SPIN_WBL_OFFSET];
        end
    end

    initial begin
        en_i = 1;
        bypass_data_conversion_i = 0;
    end

    // Module instantiation
    analog_macro_wrap #(
        .NUM_SPIN(NUM_SPIN),
        .BITDATA(BITDATA),
        .PARALLELISM(PARALLELISM),
        .COUNTER_BITWIDTH(COUNTER_BITWIDTH),
        .SYNCHRONIZER_PIPEDEPTH(SYNCHRONIZER_PIPE_DEPTH),
        .SPIN_WBL_OFFSET(SPIN_WBL_OFFSET),
        .DEBUG_WADDR_WIDTH(DEBUG_WADDR_WIDTH)
    ) dut (
        .clk_i                             (clk_i                            ),
        .rst_ni                            (rst_ni                           ),
        .en_i                              (en_i                             ),
        .analog_wrap_configure_enable_i    (analog_wrap_configure_enable_i   ),
        .cfg_trans_num_i                   (cfg_trans_num_i                  ),
        .cycle_per_wwl_high_i              (cycle_per_wwl_high_i             ),
        .cycle_per_wwl_low_i               (cycle_per_wwl_low_i              ),
        .cycle_per_spin_write_i            (cycle_per_spin_write_i           ),
        .cycle_per_spin_compute_i          (cycle_per_spin_compute_i         ),
        .bypass_data_conversion_i          (bypass_data_conversion_i         ),
        .spin_wwl_strobe_i                 (spin_wwl_strobe_i                ),
        .spin_feedback_i                   (spin_feedback_i                  ),
        .synchronizer_pipe_num_i           (synchronizer_pipe_num_i          ),
        .synchronizer_wbl_pipe_num_i       (synchronizer_wbl_pipe_num_i      ),
        .debug_cycle_per_synchronization_i (debug_cycle_per_synchronization_i),
        .debug_synchronization_num_i       (debug_synchronization_num_i      ),
        .dt_cfg_enable_i                   (dt_cfg_enable_i                  ),
        .j_mem_ren_o                       (j_mem_ren_o                      ),
        .j_raddr_o                         (j_raddr_o                        ),
        .j_rdata_i                         (j_rdata_i                        ),
        .h_ren_o                           (h_ren_o                          ),
        .h_rdata_i                         (h_rdata_i                        ),
        .j_one_hot_wwl_o                   (j_one_hot_wwl_o                  ),
        .h_wwl_o                           (h_wwl_o                          ),
        .wbl_o                             (wbl_o                            ),
        .wblb_o                            (wblb_o                           ),
        .wbl_read_i                        (wbl_read_i                       ),
        .wbl_floating_o                    (wbl_floating_o                   ),
        .spin_pop_valid_i                  (spin_pop_valid_i                 ),
        .spin_pop_ready_o                  (spin_pop_ready_o                 ),
        .spin_pop_i                        (spin_pop_i                       ),
        .spin_wwl_o                        (spin_wwl_o                       ),
        .spin_analog_i                     (spin_analog_i                    ),
        .spin_feedback_o                   (spin_feedback_o                  ),
        .spin_valid_o                      (spin_valid_o                     ),
        .spin_ready_i                      (spin_ready_i                     ),
        .spin_o                            (spin_o                           ),
        // debugging interface
        .debug_j_write_en_i                (debug_j_write_en_i               ),
        .debug_j_read_en_i                 (debug_j_read_en_i                ),
        .debug_j_one_hot_wwl_i             (debug_j_one_hot_wwl_i            ),
        .debug_h_wwl_i                     (debug_h_wwl_i                    ),
        .debug_wbl_i                       (debug_wbl_i                      ),
        .debug_j_read_data_valid_o         (debug_j_read_data_valid_o        ),
        .debug_j_read_data_o               (debug_j_read_data_o              ),
        .debug_spin_write_en_i             (debug_spin_write_en_i            ),
        .debug_spin_wwl_i                  (debug_spin_wwl_i                 ),
        .debug_spin_feedback_i             (debug_spin_feedback_i            ),
        .wbl_floating_i                    (wbl_floating_i                   ),
        .debug_spin_read_en_i              (debug_spin_read_en_i             ),
        .debug_spin_read_busy_o            (debug_spin_read_busy_o           ),
        .debug_spin_valid_o                (debug_spin_valid_o               ),
        .debug_spin_waddr_o                (debug_spin_waddr_o               ),
        .debug_spin_o                      (debug_spin_o                     ),
        // status
        .dt_cfg_idle_o                     (dt_cfg_idle_o                    ),
        .analog_rx_idle_o                  (analog_rx_idle_o                 ),
        .analog_tx_idle_o                  (analog_tx_idle_o                 )
    );

    // Clock generation
    initial begin
        clk_i = 0;
        forever #(CLKCYCLE/2) clk_i = ~clk_i;
    end

    // Reset generation
    initial begin
        rst_ni = 0;
        #(5 * CLKCYCLE);
        rst_ni = 1;
        #(5 * CLKCYCLE);
        en_i = 1;
    end

    // Run tests
    initial begin
        if (`DBG) begin
            $display("Debug mode enabled. Running with detailed output.");
            $dumpfile(`VCD_FILE);
            $dumpvars(4, tb_analog_macro_wrap); // Dump all variables in testbench module
            $timeformat(-9, 1, " ns", 9);
            #(5_00 * CLKCYCLE); // To avoid generating huge VCD files
            $display("[Time: %t] testbench timeout reached. Ending simulation.", $time);
            $finish;
        end
        else begin
            // $timeformat(-9, 1, " ns", 9);
            // #(20_000_000 * CLKCYCLE);
            // $display("[Time: %t] testbench timeout reached. Ending simulation.", $time);
            // $finish;
        end
    end

    // ========================================================================
    // Always blocks
    // ========================================================================
    // pipe j_rdata_i
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            j_rdata_i <= 'd0;
        end else begin
            j_rdata_i <= j_rdata_latched;
        end
    end
    assign h_rdata_i = hbias_in_reg;
    // dly of debug en
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            debug_j_write_en_dly1 <= 1'b0;
            debug_j_read_en_dly1 <= 1'b0;
            debug_spin_write_en_dly1 <= 1'b0;
            debug_spin_read_en_dly1 <= 1'b0;
        end else begin
            debug_j_write_en_dly1 <= debug_j_write_en_i;
            debug_j_read_en_dly1 <= debug_j_read_en_i;
            debug_spin_write_en_dly1 <= debug_spin_write_en_i;
            debug_spin_read_en_dly1 <= debug_spin_read_en_i;
        end
    end

    // ========================================================================
    // Tasks
    // ========================================================================
    // Task for AW config interface
    task automatic aw_config_interface();
        config_aw_done = 0;
        analog_wrap_configure_enable_i = 0;
        cfg_trans_num_i = 'd0;
        cycle_per_wwl_high_i = 'd0;
        cycle_per_wwl_low_i = 'd0;
        cycle_per_spin_write_i = 'd0;
        cycle_per_spin_compute_i = 'd0;
        synchronizer_pipe_num_i = 'd0;
        synchronizer_wbl_pipe_num_i = 'd0;
        spin_wwl_strobe_i = 'd0;
        spin_feedback_i = 'd0;
        // Apply configuration
        wait (rst_ni == 1 && en_i == 1);
        @(negedge clk_i);
        $display("[Time: %t] AW configuration starts.", $time);
        analog_wrap_configure_enable_i = 1;
        cfg_trans_num_i = NUM_SPIN/PARALLELISM-1+1; // total transfer number (j + h)
        cycle_per_wwl_high_i = CyclePerWwlHigh - 1;
        cycle_per_wwl_low_i = CyclePerWwlLow - 1;
        cycle_per_spin_write_i = CyclePerSpinWrite - 1;
        cycle_per_spin_compute_i = CyclePerSpinCompute - 1;
        synchronizer_pipe_num_i = SynchronizerPipeNum;
        synchronizer_wbl_pipe_num_i = SynchronizerPipeNum;
        spin_wwl_strobe_i = SpinWwlStrobe;
        spin_feedback_i = SpinFeedback;
        @(negedge clk_i);
        analog_wrap_configure_enable_i = 0;
        config_aw_done = 1;
        $display("[Time: %t] AW configuration finished.", $time);
    endtask

    // Task for galena config
    task automatic galena_config_interface();
        wait (rst_ni == 0);
        config_galena_done = 0;
        dt_cfg_enable_i = 0;
        onloading_test_idx = 0;
        wait (rst_ni == 1 && en_i == 1 && config_aw_done == 1);
        @(negedge clk_i);
        while (onloading_test_idx < OnloadingTestNum) begin
            if (`DBG)
                $display("[Time: %t] Galena configuration testcase %0d starts.", $time, onloading_test_idx);
            @(negedge clk_i);
            dt_cfg_enable_i = 1;
            @(negedge clk_i);
            dt_cfg_enable_i = 0;
            wait (dt_cfg_idle_o == 1);
            onloading_test_idx = onloading_test_idx + 1;
            repeat ($urandom_range(0, 20)) @(negedge clk_i);
        end
        config_galena_done = 1;
    endtask

    // Task for h generation
    task automatic generate_hbias_input();
        integer spin_idx;
        logic signed [BITDATA-1:0] temp_hbias;
        hbias_in_reg = 'd0;
        wait (rst_ni == 1 && en_i == 1);
        forever begin
            @(negedge clk_i);
            for (spin_idx = 0; spin_idx < NUM_SPIN; spin_idx = spin_idx + 1) begin
                do begin
                    temp_hbias = $urandom_range(-2**(BITDATA-1), 2**(BITDATA-1) - 1);
                end while (temp_hbias == {1'b1, {BITDATA-1{1'b0}}});  // Exclude unsupported most negative value
                hbias_in_reg[spin_idx*BITDATA +: BITDATA] = temp_hbias;
            end
            wait (dt_cfg_enable_i == 1); // to avoid changing hbias continuously during idle
            @(negedge clk_i);
            wait (dt_cfg_idle_o == 1);
        end
    endtask

    // Task for j generation
    task automatic generate_j_weights_in_mem();
        integer j_mem_addr_idx;
        integer spin_idx, inner_spin_idx;
        logic signed [BITDATA-1:0] temp_weight;
        j_mem_addr_idx = 0;
        wait (rst_ni == 1 && en_i == 1);
        forever begin
            j_mem_addr_idx = 0;
            @(negedge clk_i);
            while (j_mem_addr_idx < (NUM_SPIN / PARALLELISM)) begin
                for (spin_idx = 0; spin_idx < PARALLELISM; spin_idx = spin_idx + 1) begin
                    weights_in_mem[j_mem_addr_idx][spin_idx*NUM_SPIN*BITDATA +: NUM_SPIN*BITDATA] = 'd0;
                    for (inner_spin_idx = 0; inner_spin_idx < NUM_SPIN; inner_spin_idx = inner_spin_idx + 1) begin
                        do begin
                            temp_weight = $urandom_range(-2**(BITDATA-1), 2**(BITDATA-1) - 1);
                        end while (temp_weight == {1'b1, {BITDATA-1{1'b0}}});  // Exclude unsupported most negative value
                        weights_in_mem_ordered[j_mem_addr_idx*PARALLELISM + spin_idx][inner_spin_idx*BITDATA +: BITDATA]
                            = temp_weight;
                        weights_in_mem[j_mem_addr_idx][spin_idx*NUM_SPIN*BITDATA + inner_spin_idx*BITDATA +: BITDATA]
                            = temp_weight;
                    end
                end
                j_mem_addr_idx = j_mem_addr_idx + 1;
            end
            wait (dt_cfg_enable_i == 1); // to avoid changing hbias continuously during idle
            @(negedge clk_i);
            wait (dt_cfg_idle_o == 1);
        end
    endtask

    // Interface: J mem <-> analog wrap
    task automatic j_mem_interface();
        j_rdata_latched = 'd0;
        j_raddr_ref = 'd0;
        wait (rst_ni == 1 && en_i == 1);
        forever begin
            @(negedge clk_i);
            // Interface to analog wrap: standard 1-cycle-delay memory interface
            if (j_mem_ren_o == 1) begin
                if (j_raddr_o != j_raddr_ref) begin
                    $fatal(1, "[Time: %t] Error: J memory read address mismatch. Expected: %0d, Got: %0d",
                        $time, j_raddr_ref, j_raddr_o);
                end
                j_rdata_latched = weights_in_mem[j_raddr_o];
                j_raddr_ref = j_raddr_ref + 1;
            end
        end
    endtask

    // Interface: analog_wrap <-> galena spin wwl
    task automatic galena_spin_wwl_interface();
        galena_spin_write_cycle_cnt = 0;
        wait (rst_ni == 1 && en_i == 1 && config_galena_done == 1);
        forever begin
            @(posedge clk_i);
            if (spin_pop_valid_i & spin_pop_ready_o) begin
                galena_spin_write_cycle_cnt = 0;
            end
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
            end
        end
    endtask

    // Interface: analog_wrap <-> galena output
    task automatic galena_spin_output_interface();
        integer galena_spin_cmpt_cycle_cnt;
        galena_spin_cmpt_cycle_cnt = 0;
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

    // Interface: analog_wrap <-> energy monitor
    task automatic energy_monitor_interface();
        spin_ready_i = 1;
        wait (rst_ni == 1 && en_i == 1 && config_galena_done == 1);
        forever begin
            @(posedge clk_i);
            spin_ready_i = 1; // randomly generate ready signal
        end
    endtask

    // Interface: analog_wrap <-> flip manager
    task automatic flip_manager_interface();
        integer spin_idx;
        spin_pop_i = 'd0;
        spin_pop_handshake_cnt = 0;
        spin_pop_valid_i = 0;
        wait (rst_ni == 1 && en_i == 1 && config_galena_done == 1 && debug_galena_done == 1);
        while (spin_pop_handshake_cnt < CmptTestNum) begin
            @(posedge clk_i);
            // generate new spin_pop_i
            for (spin_idx = 0; spin_idx < NUM_SPIN; spin_idx = spin_idx + 1) begin
                spin_pop_i[spin_idx] = $urandom_range(0, 1);
            end
            spin_pop_valid_i = $urandom_range(0, 1); // randomly generate valid signal
            while (spin_pop_handshake == 0) begin
                spin_pop_valid_i = $urandom_range(0, 1);
                @(posedge clk_i);
            end
            spin_pop_handshake_cnt = spin_pop_handshake_cnt + 1;
        end
    endtask

    // ========================================================================
    // Debug
    // ========================================================================
    task automatic debug_model_wr();
    begin
        integer debug_idx;
        logic [BITDATA-1:0] temp_debug_wbl_data;

        debug_j_write_en_i = 1'b0;
        debug_j_read_en_i = 1'b0;
        debug_j_one_hot_wwl_i = 'd0;
        debug_j_analog_waddr = 'd0;
        debug_j_analog_raddr = 'd0;
        debug_h_wwl_i = 1'b0;
        debug_wbl_i = 'd0;
        wbl_floating_i = {(NUM_SPIN*BITDATA){1'b0}};
        debug_test_idx = 'd0;
        debug_galena_done = 1'b0;
        wait (rst_ni == 1 && en_i == 1 && config_galena_done == 1);
        @(posedge clk_i);
        while (debug_test_idx < DebugTestNum) begin
            // ---------------------------------------
            // test: writing j/h
            // ---------------------------------------
            // set wbl_floating to 0
            wbl_floating_i = {(NUM_SPIN*BITDATA){1'b0}};
            analog_wrap_configure_enable_i = 1'b1;
            @(posedge clk_i);
            analog_wrap_configure_enable_i = 1'b0;
            // generate random wwl address and one-hot wwl
            debug_j_analog_waddr = $urandom_range(0, 2 * NUM_SPIN);
            if (debug_j_analog_waddr >= NUM_SPIN) begin
                debug_h_wwl_i = 1'b1;
                debug_j_one_hot_wwl_i = 'd0;
            end else begin
                debug_j_one_hot_wwl_i = 1'b1 << debug_j_analog_waddr;
                debug_h_wwl_i = 1'b0;
            end
            // generate random wbl data
            for (int i = 0; i < NUM_SPIN; i = i + 1) begin
                do begin
                    temp_debug_wbl_data = $urandom_range(-2**(BITDATA-1), 2**(BITDATA-1) - 1);
                end while (temp_debug_wbl_data == {1'b1, {BITDATA-1{1'b0}}});  // Exclude unsupported most negative value
                debug_wbl_i[i*BITDATA +: BITDATA] = temp_debug_wbl_data;
            end
            debug_j_write_en_i = 1'b1;
            repeat (CyclePerWwlHigh+CyclePerWwlLow+1) @(posedge clk_i);
            debug_j_write_en_i = 1'b0;
            // ---------------------------------------
            // test: reading j/h
            // ---------------------------------------
            // set wbl_floating to 1
            wbl_floating_i = {(NUM_SPIN*BITDATA){1'b1}};
            analog_wrap_configure_enable_i = 1'b1;
            @(posedge clk_i);
            analog_wrap_configure_enable_i = 1'b0;
            // generate random wwl address and one-hot wwl
            debug_j_analog_raddr = $urandom_range(0, 2 * NUM_SPIN);
            if (debug_j_analog_raddr >= NUM_SPIN) begin
                debug_h_wwl_i = 1'b1;
                debug_j_one_hot_wwl_i = 'd0;
            end else begin
                debug_h_wwl_i = 1'b0;
                debug_j_one_hot_wwl_i = 1'b1 << debug_j_analog_raddr;
            end
            debug_j_read_en_i = 1'b1;
            repeat (CyclePerWwlHigh) @(posedge clk_i);
            // send in wbl_read_i
            if (debug_j_analog_raddr >= NUM_SPIN) begin
                wbl_read_i = hbias_analog;
            end else begin
                wbl_read_i = weights_analog[debug_j_analog_raddr];
            end
            debug_j_read_en_i = 1'b0;
            repeat (CyclePerWwlLow + 2) @(posedge clk_i); // +2 to wait for read to finish
            @(posedge clk_i); // wait an extra cycle before next test
            debug_test_idx = debug_test_idx + 1'b1;
        end
        debug_galena_done = 1'b1;
    end
    endtask

    task automatic debug_model_spin_wr();
    begin
        debug_spin_write_en_i = 1'b0;
        debug_spin_read_en_i = 1'b0;
        debug_spin_wwl_i = 'd0;
        debug_spin_feedback_i = 'd0;
    end
    endtask

    // ========================================================================
    // Checks
    // ========================================================================
    // Function for converting wbl in analog format to signed integer
    function automatic integer wbl_analog_to_signed_int(input logic [4-1:0] wbl_analog);
        logic signed [4-1:0] signed_int;
        begin
            case (wbl_analog)
                4'b1110: signed_int = -7; // 4'b1001
                4'b1100: signed_int = -6; // 4'b1010
                4'b1010: signed_int = -5; // 4'b1011
                4'b1000: signed_int = -4; // 4'b1100
                4'b0110: signed_int = -3; // 4'b1101
                4'b0100: signed_int = -2; // 4'b1110
                4'b0010: signed_int = -1; // 4'b1111
                4'b0000: signed_int =  0; // 4'b0000
                4'b0011: signed_int =  1; // 4'b0001
                4'b0101: signed_int =  2; // 4'b0010
                4'b0111: signed_int =  3; // 4'b0011
                4'b1001: signed_int =  4; // 4'b0100
                4'b1011: signed_int =  5; // 4'b0101
                4'b1101: signed_int =  6; // 4'b0110
                4'b1111: signed_int =  7; // 4'b0111
                default: signed_int = 'z; // floating for invalid codes
            endcase
            return signed_int;
        end
    endfunction

    // Task for analog galena interface: config data check: j
    task automatic analog_interface_config_check_j();
        config_test_correct_cnt_j = 0;
        galena_addr_idx = 0;
        dt_write_cycle_cnt_j = 0;
        wait (rst_ni == 1 && en_i == 1);
        while (config_test_correct_cnt_j < OnloadingTestNum) begin
            wait (dt_cfg_enable_i == 1);
            @(posedge clk_i);
            // check if j and h are loaded correctly
            while (galena_addr_idx < NUM_SPIN) begin
                wait (j_one_hot_wwl_o != 0);
                while (dt_write_cycle_cnt_j < CyclePerWwlHigh) begin
                    @(negedge clk_i);
                    // monitor if j_one_hot_wwl_o remains valid for the dedefined cycles
                    if (j_one_hot_wwl_o == 0 && dt_write_cycle_cnt_j != 0) begin
                        $fatal(1, "[Time: %t] Error: j_one_hot_wwl_o switches to zero during dt write cycle %0d for galena_addr_idx %0d",
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
                    if (bypass_data_conversion_i) begin
                        weights_analog[galena_addr_idx][i*BITDATA +: BITDATA]
                            = wbl_o[i*BITDATA +: BITDATA];
                    end else begin
                        weights_analog[galena_addr_idx][i*BITDATA +: BITDATA]
                            = wbl_analog_to_signed_int(wbl_o[i*BITDATA +: BITDATA]);
                    end
                end
                // compare data to reference
                if (weights_analog[galena_addr_idx] != weights_in_mem_ordered[galena_addr_idx]) begin
                    $fatal(1, "[Time: %t] Error: Weights mismatch at galena_addr_idx %0d. Expected: 'h%h, Got: 'h%h",
                        $time, galena_addr_idx, weights_in_mem_ordered[galena_addr_idx], weights_analog[galena_addr_idx]);
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
            $time, config_test_correct_cnt_j, OnloadingTestNum, OnloadingTestNum - config_test_correct_cnt_j, OnloadingTestNum);
        $display("----------------------------------------");
    endtask

    // Task for analog galena interface: config data check: h
    task automatic analog_interface_config_check_h();
        config_test_correct_cnt_h = 0;
        while (config_test_correct_cnt_h < OnloadingTestNum) begin
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
                        = wbl_analog_to_signed_int(wbl_o[i*BITDATA +: BITDATA]);
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

    // Task for debugging mode: data write
    task automatic debug_analog_interface_j_h_write();
        debug_dt_write_cycle_cnt_j = 0;
        wait (rst_ni == 1 && en_i == 1);
        while (debug_galena_done == 0) begin
            if (debug_j_write_en_posedge) begin: debug_j_writing_mode
                debug_dt_write_cycle_cnt_j = 'd0;
                @(negedge clk_i);
                while (debug_dt_write_cycle_cnt_j < CyclePerWwlHigh) begin
                    if (debug_h_wwl_i) begin
                    end else begin
                        if (|j_one_hot_wwl_o) begin
                            // check if one-hot encoded and matches galena_addr_idx
                            if ($countbits(j_one_hot_wwl_o, '1) != 1)
                                $fatal(1, "[Time: %t][Debug data write mode] Error: j_one_hot_wwl_o is not one-hot encoded, j_one_hot_wwl_o: 'b%b", $time, j_one_hot_wwl_o);
                        end
                    end
                    debug_dt_write_cycle_cnt_j = debug_dt_write_cycle_cnt_j + 1;
                    @(negedge clk_i);
                end
                // load output to analog reference model data
                if (debug_h_wwl_i) begin
                    // after dt write cycles, write hbias
                    for (int i=0; i<NUM_SPIN; i=i+1) begin
                        hbias_analog[i*BITDATA +: BITDATA] = wbl_o[i*BITDATA +: BITDATA];
                    end
                    // compare data
                    if (hbias_analog != debug_wbl_i) begin
                        $fatal(1, "[Time: %t][Debug data write mode] Error: Hbias writing mismatch. Expected: 'h%h, Got: 'h%h",
                            $time, debug_wbl_i, hbias_analog);
                    end
                end else begin
                    // after dt write cycles, write hbias
                    for (int i=0; i<NUM_SPIN; i=i+1) begin
                        weights_analog[debug_j_analog_waddr][i*BITDATA +: BITDATA] = wbl_o[i*BITDATA +: BITDATA];
                    end
                    // compare data
                    if (weights_analog[debug_j_analog_waddr] != debug_wbl_i) begin
                        $fatal(1, "[Time: %t][Debug data write mode] Error: J writing mismatch. Expected: 'h%h, Got: 'h%h",
                            $time, debug_wbl_i, weights_analog[debug_j_analog_waddr]);
                    end
                end
            end
            @(negedge clk_i);
        end
    endtask

    // Task for debugging mode: data read
    task automatic debug_analog_interface_j_h_read();
        integer debug_dt_read_cycle_cnt_j = 0;
        logic [NUM_SPIN * BITDATA - 1:0] debug_j_read_data_decoded;

        wait (rst_ni == 1 && en_i == 1);
        while (debug_galena_done == 0) begin
            @(negedge clk_i);
            if (debug_j_read_en_posedge) begin
                wait (debug_j_read_data_valid_o == 1'b1);
                @(negedge clk_i);
                // accept data
                debug_j_read_data_decoded = debug_j_read_data_o;
                // compare data
                if (debug_h_wwl_i) begin: compare_h
                    if (debug_j_read_data_decoded != hbias_analog) begin
                        $fatal(1, "[Time: %t][Debug data read mode] Error: Hbias read mismatch. Expected: 'h%h, Got: 'h%h",
                            $time, hbias_analog, debug_j_read_data_decoded);
                    end
                end else begin: compare_j
                    if (debug_j_read_data_decoded != weights_analog[debug_j_analog_raddr]) begin
                        $fatal(1, "[Time: %t][Debug data read mode] Error: J read mismatch. Expected: 'h%h, Got: 'h%h",
                            $time, weights_analog[debug_j_analog_raddr], debug_j_read_data_decoded);
                    end else begin
                        if (`DBG)
                            $display("[Time: %t][Debug data read mode] Info: J read match at addr %0d. Data: 'h%h",
                                $time, debug_j_analog_raddr, debug_j_read_data_decoded);
                    end
                end
            end
        end
    endtask


    // Task for spin_wwl_o check
    task automatic spin_wwl_check();
        integer spin_wwl_cycle_cnt;
        spin_wwl_cycle_cnt = 0;
        wait (rst_ni == 1 && en_i == 1 && config_galena_done == 1 && debug_galena_done == 1);
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

    // Task for spin_o_check check (assume spin_o is a copy of spin_pop_i)
    task automatic spin_o_check();
        cmpt_correct_cnt = 0;
        cmpt_error_cnt = 0;
        spin_pop_ref_valid = 0;
        spin_pop_ref = 'd0;
        wait (rst_ni == 1 && en_i == 1 && config_galena_done == 1 && debug_galena_done == 1);
        while (cmpt_correct_cnt + cmpt_error_cnt < CmptTestNum) begin
            @(negedge clk_i);
            if (spin_pop_ready_o & spin_pop_valid_i) begin: fetch_spin_pop
                if (spin_pop_ref_valid == 1)
                    $fatal(1, "[Time: %t] Error: spin_pop_ref valid signal not cleared before new data arrival.",
                        $time);
                else begin
                    spin_pop_ref = spin_pop_i;
                    spin_pop_ref_valid = 1;
                end
            end
            if (spin_ready_i & spin_valid_o) begin: clear_spin_pop_ref
                if (spin_pop_ref_valid == 0)
                    $fatal(1, "[Time: %t] Error: spin_pop_ref valid signal cleared before data arrival.",
                        $time);
                else begin
                    if (spin_o != spin_pop_ref) begin
                        $fatal(1, "[Time: %t] Error: spin_o data mismatch. Expected: 'h%h, Got: 'h%h",
                            $time, spin_pop_ref, spin_o);
                        cmpt_error_cnt = cmpt_error_cnt + 1;
                    end else begin
                        // correct data
                        cmpt_correct_cnt = cmpt_correct_cnt + 1;
                        if (`DBG)
                            $display("[Time: %t] Info: spin_o/spin_pop_i match. Data: 'h%h",
                                $time, spin_o);
                    end
                    spin_pop_ref = 'd0;
                    spin_pop_ref_valid = 0;
                end
            end
        end
        // after all compute tests
        $display("----------------------------------------");
        $display("CMPT Scoreboard [Time %0d ns]: %0d/%0d correct, %0d/%0d errors",
            $time, cmpt_correct_cnt, CmptTestNum, cmpt_error_cnt, CmptTestNum);
        $display("----------------------------------------");
        repeat (10) @(posedge clk_i);
        $finish;
    endtask

    // Timer: config
    task automatic config_timer();
        integer config_start_time, config_end_time;
        integer config_total_time, config_total_cycles;
        integer config_transaction_time, config_transaction_cycles;
        config_total_cycles = 0;
        config_transaction_cycles = 0;
        config_total_time = 0;
        config_transaction_time = 0;
        config_start_time = 0;
        config_end_time = 0;
        wait (rst_ni == 1 && en_i == 1 && dt_cfg_enable_i == 1);
        config_start_time = $time;
        wait (config_test_correct_cnt_j >= OnloadingTestNum && config_test_correct_cnt_h >= OnloadingTestNum);
        config_end_time = $time;
        config_total_time = config_end_time - config_start_time;
        config_total_cycles = config_total_time / CLKCYCLE;
        config_transaction_cycles = config_total_cycles / OnloadingTestNum;
        config_transaction_time = config_total_time / OnloadingTestNum;
        $display("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
        $display("Configuration Timer [Time %0d ns]: start time: %0d ns, end time: %0d ns, duration: %0d ns, configs: %0d",
            $time, config_start_time, config_end_time, config_total_time, OnloadingTestNum);
        $display("Configuration Timer [Time %0d ns]: Total cycles: %0d cc [%0d ns], Cycles/config: %0d cc [%0d ns]",
            $time, config_total_cycles, config_total_time, config_transaction_cycles, config_transaction_time);
        $display("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
    endtask

    // Timer: cmpt
    task automatic cmpt_timer();
        integer cmpt_start_time, cmpt_end_time;
        integer cmpt_total_time, cmpt_total_cycles;
        integer cmpt_transaction_time, cmpt_transaction_cycles;
        cmpt_total_cycles = 0;
        cmpt_transaction_cycles = 0;
        cmpt_total_time = 0;
        cmpt_transaction_time = 0;
        cmpt_start_time = 0;
        cmpt_end_time = 0;
        wait (rst_ni == 1 && en_i == 1 && config_galena_done == 1);
        wait (spin_pop_ready_o & spin_pop_valid_i);
        cmpt_start_time = $time;
        wait (cmpt_correct_cnt + cmpt_error_cnt >= CmptTestNum);
        cmpt_end_time = $time;
        cmpt_total_time = cmpt_end_time - cmpt_start_time;
        cmpt_total_cycles = cmpt_total_time / CLKCYCLE;
        cmpt_transaction_cycles = cmpt_total_cycles / CmptTestNum;
        cmpt_transaction_time = cmpt_total_time / CmptTestNum;
        $display("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
        $display("CMPT Timer [Time %0d ns]: start time: %0d ns, end time: %0d ns, duration: %0d ns, transactions: %0d",
            $time, cmpt_start_time, cmpt_end_time, cmpt_total_time, CmptTestNum);
        $display("CMPT Timer [Time %0d ns]: Total cycles: %0d cc [%0d ns], Cycles/transaction: %0d cc [%0d ns]",
            $time, cmpt_total_cycles, cmpt_total_time, cmpt_transaction_cycles, cmpt_transaction_time);
        $display("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
    endtask

    // ========================================================================
    // Event execution
    // ========================================================================
    initial begin
        fork
            // Configurations
            aw_config_interface();
            galena_config_interface();
            generate_hbias_input();
            generate_j_weights_in_mem();
            // Peripheral interfaces
            j_mem_interface();
            energy_monitor_interface();
            flip_manager_interface();
            // Galena interfaces
            galena_spin_wwl_interface();
            galena_spin_output_interface();
            // Checks
            analog_interface_config_check_j();
            analog_interface_config_check_h();
            spin_wwl_check();
            spin_o_check();
            // Timer
            config_timer();
            cmpt_timer();
            // Debug operations
            debug_model_wr();
            debug_model_spin_wr();
            // Debug checks
            debug_analog_interface_j_h_write();
            debug_analog_interface_j_h_read();
        join_none
    end

endmodule
