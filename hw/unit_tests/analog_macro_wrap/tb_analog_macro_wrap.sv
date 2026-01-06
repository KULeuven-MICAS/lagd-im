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

module tb_analog_macro_wrap;

    // module parameters
    localparam int NUM_SPIN = 256; // number of spins
    localparam int BITDATA = 4; // bit width of J and h, sfc
    localparam int COUNTER_BITWIDTH = 16;
    localparam int SYNCHRONIZER_PIPE_DEPTH = 3;
    localparam int PARALLELISM = 4; // number of parallel data in J memory
    localparam int J_ADDRESS_WIDTH = $clog2(NUM_SPIN / PARALLELISM);
    localparam int OnloadingTestNum = 100; // number of onloading tests
    localparam int CmptTestNum = 10000; // number of compute tests

    // testbench parameters
    localparam int CLKCYCLE = 2;

    // dut run-time configuration
    localparam int CyclePerWwlHigh = 50;
    localparam int CyclePerWwlLow = 50;
    localparam int CyclePerSpinWrite = 50;
    localparam int CyclePerSpinCompute = 100;
    localparam int SynchronizerPipeNum = 3;
    localparam int SynchronizerMode = 0; // 0: one-shot; 1: continuous
    localparam int SpinWwlStrobe = {256{1'b1}}; // all spins enabled
    localparam int SpinMode = {256{1'b1}}; // all spins in compute mode

    // testbench internal signals
    logic clk_i;
    logic rst_ni;
    logic en_i;
    logic analog_wrap_configure_enable_i;
    logic [COUNTER_BITWIDTH-1:0] cfg_trans_num_i;
    logic [COUNTER_BITWIDTH-1:0] cycle_per_wwl_high_i, cycle_per_wwl_low_i;
    logic [COUNTER_BITWIDTH-1:0] cycle_per_spin_write_i;
    logic [COUNTER_BITWIDTH-1:0] cycle_per_spin_compute_i;
    logic [NUM_SPIN-1:0] spin_wwl_strobe_i;
    logic [NUM_SPIN-1:0] spin_mode_i;
    logic [$clog2(SYNCHRONIZER_PIPE_DEPTH)-1:0] synchronizer_pipe_num_i;
    logic synchronizer_mode_i;
    logic dt_cfg_enable_i;
    logic j_mem_ren_o;
    logic [J_ADDRESS_WIDTH-1:0] j_raddr_o;
    logic [NUM_SPIN*BITDATA*PARALLELISM-1:0] j_rdata_i, j_rdata_latched;
    logic h_ren_o;
    logic [NUM_SPIN*BITDATA-1:0] h_rdata_i, hbias_in_reg;
    logic [NUM_SPIN-1:0] j_one_hot_wwl_o;
    logic h_wwl_o;
    logic [NUM_SPIN*BITDATA-1:0] wbl_o, wbl_copy;
    logic spin_pop_valid_i;
    logic spin_pop_ready_o;
    logic [NUM_SPIN-1:0] spin_pop_i, spin_pop_ref;
    logic spin_pop_ref_valid;
    logic [NUM_SPIN-1:0] spin_wwl_o;
    logic [NUM_SPIN-1:0] spin_compute_en_o;
    logic [NUM_SPIN-1:0] spin_i;
    logic spin_valid_o;
    logic spin_ready_i;
    logic [NUM_SPIN-1:0] spin_o;
    logic dt_cfg_idle_o;
    logic analog_rx_idle_o;
    logic analog_tx_idle_o;

    logic config_aw_done;
    logic config_galena_done;
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

    initial begin
        en_i = 1;
    end

    // Module instantiation
    analog_macro_wrap #(
        .NUM_SPIN(NUM_SPIN),
        .BITDATA(BITDATA),
        .PARALLELISM(PARALLELISM),
        .COUNTER_BITWIDTH(COUNTER_BITWIDTH),
        .SYNCHRONIZER_PIPEDEPTH(SYNCHRONIZER_PIPE_DEPTH)
    ) dut (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .en_i(en_i),
        .analog_wrap_configure_enable_i(analog_wrap_configure_enable_i),
        .cfg_trans_num_i(cfg_trans_num_i),
        .cycle_per_wwl_high_i(cycle_per_wwl_high_i),
        .cycle_per_wwl_low_i(cycle_per_wwl_low_i),
        .cycle_per_spin_write_i(cycle_per_spin_write_i),
        .cycle_per_spin_compute_i(cycle_per_spin_compute_i),
        .spin_wwl_strobe_i(spin_wwl_strobe_i),
        .spin_mode_i(spin_mode_i),
        .synchronizer_pipe_num_i(synchronizer_pipe_num_i),
        .synchronizer_mode_i(synchronizer_mode_i),
        .dt_cfg_enable_i(dt_cfg_enable_i),
        .j_mem_ren_o(j_mem_ren_o),
        .j_raddr_o(j_raddr_o),
        .j_rdata_i(j_rdata_i),
        .h_ren_o(h_ren_o),
        .h_rdata_i(h_rdata_i),
        .j_one_hot_wwl_o(j_one_hot_wwl_o),
        .h_wwl_o(h_wwl_o),
        .wbl_o(wbl_o),
        .wblb_o(),
        .spin_pop_valid_i(spin_pop_valid_i),
        .spin_pop_ready_o(spin_pop_ready_o),
        .spin_pop_i(spin_pop_i),
        .spin_wwl_o(spin_wwl_o),
        .spin_compute_en_o(spin_compute_en_o),
        .spin_i(spin_i),
        .spin_valid_o(spin_valid_o),
        .spin_ready_i(spin_ready_i),
        .spin_o(spin_o),
        .dt_cfg_idle_o(dt_cfg_idle_o),
        .analog_rx_idle_o(analog_rx_idle_o),
        .analog_tx_idle_o(analog_tx_idle_o)
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
            #(1_000 * CLKCYCLE); // To avoid generating huge VCD files
            $display("[Time: %t] testbench timeout reached. Ending simulation.", $time);
            $finish;
        end
        else begin
            $timeformat(-9, 1, " ns", 9);
            #(20_000_000 * CLKCYCLE);
            $display("[Time: %t] testbench timeout reached. Ending simulation.", $time);
            $finish;
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

    // ========================================================================
    // Tasks
    // ========================================================================
    // Task for AW config interface
    task automatic aw_config_interface();
        wait (rst_ni == 0);
        config_aw_done = 0;
        analog_wrap_configure_enable_i = 0;
        cfg_trans_num_i = 'd0;
        cycle_per_wwl_high_i = 'd0;
        cycle_per_wwl_low_i = 'd0;
        cycle_per_spin_write_i = 'd0;
        cycle_per_spin_compute_i = 'd0;
        synchronizer_pipe_num_i = 'd0;
        synchronizer_mode_i = 1'b0;
        spin_wwl_strobe_i = 'd0;
        spin_mode_i = 'd0;
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
        synchronizer_pipe_num_i = SynchronizerPipeNum;;
        synchronizer_mode_i = SynchronizerMode;
        spin_wwl_strobe_i = SpinWwlStrobe;
        spin_mode_i = SpinMode;
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
        hbias_in_reg = 'd0;
        wait (rst_ni == 1 && en_i == 1);
        forever begin
            @(negedge clk_i);
            for (spin_idx = 0; spin_idx < NUM_SPIN; spin_idx = spin_idx + 1) begin
                hbias_in_reg[spin_idx*BITDATA +: BITDATA] = $urandom_range(0, 2**BITDATA - 1);
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
        logic [NUM_SPIN*BITDATA-1:0] temp_weight;
        j_mem_addr_idx = 0;
        wait (rst_ni == 1 && en_i == 1);
        forever begin
            j_mem_addr_idx = 0;
            @(negedge clk_i);
            while (j_mem_addr_idx < (NUM_SPIN / PARALLELISM)) begin
                for (spin_idx = 0; spin_idx < PARALLELISM; spin_idx = spin_idx + 1) begin
                    weights_in_mem[j_mem_addr_idx][spin_idx*NUM_SPIN*BITDATA +: NUM_SPIN*BITDATA] = 'd0;
                    for (inner_spin_idx = 0; inner_spin_idx < NUM_SPIN; inner_spin_idx = inner_spin_idx + 1) begin
                        temp_weight = $urandom_range(0, 2**BITDATA - 1);
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
        wait (rst_ni == 0);
        @(negedge clk_i);
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
        wait (rst_ni == 0);
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

    // Interface: analog_wrap <-> galena spin_i output
    task automatic galena_spin_output_interface();
        integer galena_spin_cmpt_cycle_cnt;
        galena_spin_cmpt_cycle_cnt = 0;
        wait (rst_ni == 0);
        spin_i = 'd0;
        wait (rst_ni == 1 && en_i == 1 && config_galena_done == 1);
        forever begin
            @(posedge clk_i);
            if ($countbits(spin_wwl_o, '1) == NUM_SPIN) begin: timer_start
                while (galena_spin_cmpt_cycle_cnt < (CyclePerSpinCompute-1)) begin
                    galena_spin_cmpt_cycle_cnt = galena_spin_cmpt_cycle_cnt + 1;
                    @(posedge clk_i);
                end
                // after compute cycles, output spin_i
                spin_i = wbl_copy[NUM_SPIN-1:0];
                galena_spin_cmpt_cycle_cnt = 0;
            end
        end
    endtask

    // Interface: analog_wrap <-> energy monitor
    task automatic energy_monitor_interface();
        spin_ready_i = 1;
        wait (rst_ni == 1 && en_i == 1 && config_galena_done == 1);
        forever begin
            @(negedge clk_i);
            spin_ready_i = $urandom_range(0, 1); // randomly generate ready signal
        end
    endtask

    // Interface: analog_wrap <-> flip manager
    task automatic flip_manager_interface();
        integer spin_idx;
        integer spin_pop_handshake_cnt;
        spin_pop_handshake_cnt = 0;
        wait (rst_ni == 0);
        spin_pop_valid_i = 0;
        wait (rst_ni == 1 && en_i == 1 && config_galena_done == 1);
        while (spin_pop_handshake_cnt < CmptTestNum) begin
            @(negedge clk_i);
            spin_pop_valid_i = $urandom_range(0, 1); // randomly generate valid signal
            if (spin_pop_ready_o == 1 && spin_pop_valid_i == 1) begin
                // provide new spin_pop_i
                for (spin_idx = 0; spin_idx < NUM_SPIN; spin_idx = spin_idx + 1) begin
                    spin_pop_i[spin_idx] = $urandom_range(0, 1);
                end
                spin_pop_handshake_cnt = spin_pop_handshake_cnt + 1;
            end
        end
    endtask

    // ========================================================================
    // Checks
    // ========================================================================
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
                weights_analog[galena_addr_idx] = wbl_o;
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
        $display("[Time: %t] Galena configuration testcases [%0d/%0d] passed.", $time, config_test_correct_cnt_j, OnloadingTestNum);
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
            hbias_analog = wbl_o;
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

    // Task for spin_o_check check (assume spin_o is a copy of spin_pop_i)
    task automatic spin_o_check();
        cmpt_correct_cnt = 0;
        cmpt_error_cnt = 0;
        wait (rst_ni == 1 && en_i == 1 && config_galena_done == 1);
        spin_pop_ref_valid = 0;
        spin_pop_ref = 'd0;
        while (cmpt_correct_cnt + cmpt_error_cnt < CmptTestNum) begin
            @(posedge clk_i);
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
        @(posedge clk_i);
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
        join_none
    end

endmodule
