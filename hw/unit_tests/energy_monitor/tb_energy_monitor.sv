// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`timescale 1ns / 1ps

`ifndef DBG
`define DBG 0
`endif

`define S1W1H1_TEST 'b000
`define S0W1H1_TEST 'b001
`define S0W0H0_TEST 'b010
`define S1W0H0_TEST 'b011
`define MaxPosValue_TEST 'b100
`define MaxNegValue_TEST 'b101
`define RANDOM_TEST 'b110

`define True 1'b1
`define False 1'b0

module tb_energy_monitor;

    // Testbench parameters
    localparam int test_mode = `RANDOM_TEST; // select test mode
    localparam int NUM_TESTS = 1_000_000; // number of test cases
    localparam int CLKCYCLE = 2; // clock cycle in ns
    localparam int MEM_LATENCY = 0; // latency of memories in cycles
    localparam int SPIN_LATENCY = 10; // latency of spin input in cycles
    localparam int MEM_LATENCY_RANDOM = `True;
    localparam int SPIN_LATENCY_RANDOM = `True;

    // Module parameters
    localparam int BITJ = 4; // J precision
    localparam int BITH = 4; // bias precision
    localparam int DATASPIN = 256; // number of spins
    localparam int SCALING_BIT = 5; // bit width of scaling factor
    localparam int LOCAL_ENERGY_BIT = 16; // bit width of local energy
    localparam int ENERGY_TOTAL_BIT = 32; // bit width of total energy
    localparam int PIPES = 2; // number of pipeline stages

    // Testbench internal signals
    logic clk_i;
    logic rst_ni;
    logic en_i;
    logic config_valid_i;
    logic [ $clog2(DATASPIN)-1 : 0 ] config_counter_i;
    logic config_ready_o;
    logic spin_valid_i;
    logic [DATASPIN-1:0] spin_i;
    logic spin_ready_o;
    logic weight_valid_i;
    logic [DATASPIN*BITJ-1:0] weight_i;
    logic signed [BITH-1:0] hbias_i;
    logic unsigned [SCALING_BIT-1:0] hscaling_i;
    logic weight_ready_o;
    logic energy_valid_o;
    logic energy_ready_i;
    logic signed [ENERGY_TOTAL_BIT-1:0] energy_o;
    logic debug_en_i;
    logic accum_overflow_o;

    logic unsigned [31:0] spin_reg_valid_int;
    logic [NUM_TESTS-1:0] spin_reg_valid;
    logic [DATASPIN-1:0] spin_reg [0:NUM_TESTS-1];
    logic [PIPES-1:0] pipe_valid;
    logic unsigned [31:0] pipe_valid_int;
    logic [DATASPIN*BITJ-1:0] weight_pipe [0:PIPES-1];
    logic signed [BITH-1:0] hbias_pipe [0:PIPES-1];
    logic unsigned [SCALING_BIT-1:0] hscaling_pipe [0:PIPES-1];
    logic signed [BITJ-1:0] weight_expected;
    logic expected_valid;
    logic unsigned [ $clog2(DATASPIN) : 0 ] expected_spin_counter;
    logic signed [LOCAL_ENERGY_BIT-1:0] expected_local_energy;
    logic signed [ENERGY_TOTAL_BIT-1:0] expected_energy;
    logic unsigned [31:0] testcase_counter;
    logic unsigned [ $clog2(DATASPIN)-1 : 0 ] transaction_count;

    integer spin_idx;
    integer correct_count;
    integer error_count;
    integer total_count;
    integer total_cycles;
    integer transaction_cycles;
    integer total_time;
    integer transaction_time;
    integer start_time;
    integer end_time;

    assign expected_valid = energy_ready_i;

    initial begin
        transaction_count = 0;
    end

    initial begin
        testcase_counter = 1;
        $display("Starting energy monitor testbench. Running %0d/%0d tests...", testcase_counter, NUM_TESTS);
        forever begin
            wait (energy_valid_o && energy_ready_i);
            // Wait for the handshake to complete (energy_ready_i to go low)
            wait(!energy_ready_i);
            if (testcase_counter < NUM_TESTS) begin
                testcase_counter = testcase_counter + 1;
                $display("Running %0d/%0d tests...", testcase_counter, NUM_TESTS);
            end else begin
                #(2*CLKCYCLE);
                $finish;
            end
            @(posedge clk_i); // Wait for next clock edge before checking again
        end
    end

    // Module instantiation
    energy_monitor #(
        .BITJ(BITJ),
        .BITH(BITH),
        .DATASPIN(DATASPIN),
        .SCALING_BIT(SCALING_BIT),
        .LOCAL_ENERGY_BIT(LOCAL_ENERGY_BIT),
        .ENERGY_TOTAL_BIT(ENERGY_TOTAL_BIT),
        .PIPES(PIPES)
    ) dut (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .en_i(en_i),
        .config_valid_i(config_valid_i),
        .config_counter_i(config_counter_i),
        .config_ready_o(config_ready_o),
        .spin_valid_i(spin_valid_i),
        .spin_i(spin_i),
        .spin_ready_o(spin_ready_o),
        .weight_valid_i(weight_valid_i),
        .weight_i(weight_i),
        .hbias_i(hbias_i),
        .hscaling_i(hscaling_i),
        .weight_ready_o(weight_ready_o),
        .energy_valid_o(energy_valid_o),
        .energy_ready_i(energy_ready_i),
        .energy_o(energy_o),
        .debug_en_i(debug_en_i),
        .accum_overflow_o(accum_overflow_o)
    );

    // Clock generation
    initial begin
        clk_i = 1;
        forever #(CLKCYCLE/2) clk_i = ~clk_i;
    end

    // Reset generation
    initial begin
        rst_ni = 0;
        #(10 * CLKCYCLE);
        rst_ni = 1;
    end

    // Initial values for debug signal and energy ready signal
    initial begin
        debug_en_i = 0;
    end

    // Config channel stimulus
    initial begin
        en_i = 0;
        config_valid_i = 0;
        config_counter_i = 'd0;
        #(10 * CLKCYCLE);
        en_i = 1;
        config_valid_i = 1;
        config_counter_i = 'd0;
        #(10 * CLKCYCLE);
        config_valid_i = 1;
        config_counter_i = 'd255;
        #CLKCYCLE;
        config_valid_i = 0;
    end

    // Run tests
    initial begin
        if (`DBG) begin
            $display("Debug mode enabled. Generating VCD waveform.");
            $dumpfile("tb_energy_monitor.vcd");
            $dumpvars(2, weight_interface);
            $dumpvars(2, tb_energy_monitor);
                #(2000 * CLKCYCLE); // To avoid generating too large VCD files
                $fatal("Testbench timeout reached. Ending simulation.");
        end
        else begin
            // #(200000 * CLKCYCLE);
            // $display("Testbench timeout reached. Ending simulation.");
            // $finish;
        end
    end

    // ========================================================================
    // Reference behavior model
    // ========================================================================
    always_ff @(posedge clk_i or negedge rst_ni) begin: spin_record
        if (!rst_ni) begin
            spin_reg_valid_int = 0;
            for (int i = 0; i < NUM_TESTS; i++) begin
                spin_reg[i] = 0;
                spin_reg_valid[i] = 0;
            end
        end
        else begin
            if (spin_valid_i && spin_ready_o) begin
                assert (spin_reg_valid_int < NUM_TESTS) else $fatal("Spin register overflow: spin_reg_valid_int exceeded NUM_TESTS");
                spin_reg[spin_reg_valid_int] = spin_i;
                spin_reg_valid[spin_reg_valid_int] = 1'b1;
                spin_reg_valid_int = spin_reg_valid_int + 1;
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin: pipeline_fill
        if (!rst_ni) begin
            pipe_valid_int <= 0;
            pipe_valid <= 0;
            for (int p = 0; p < PIPES; p++) begin
                weight_pipe[p] <= 0;
                hbias_pipe[p] <= 0;
                hscaling_pipe[p] <= 0;
            end
        end else begin
            if (weight_valid_i && weight_ready_o) begin
                if (PIPES == 0) begin: no_pipeline_mode
                    // Do nothing in no pipeline mode
                end else begin: pipeline_mode
                    if (energy_ready_i) begin
                        if (testcase_counter >= NUM_TESTS) begin
                            // Do nothing, all tests completed
                        end else begin: pipeline_next_spin
                            pipe_valid[pipe_valid_int] <= 1; // Mark this stage as valid
                            weight_pipe[pipe_valid_int] <= weight_i;
                            hbias_pipe[pipe_valid_int] <= hbias_i;
                            hscaling_pipe[pipe_valid_int] <= hscaling_i;
                            pipe_valid_int <= pipe_valid_int + 1;
                            assert (pipe_valid_int <= PIPES) else $fatal("Pipeline overflow: pipe_valid_int exceeded PIPES");
                        end
                    end else begin
                        if (spin_reg_valid[testcase_counter-1] == 1'b0) begin: pipeline_current_spin
                            pipe_valid[pipe_valid_int] <= 1;
                            weight_pipe[pipe_valid_int] <= weight_i;
                            hbias_pipe[pipe_valid_int] <= hbias_i;
                            hscaling_pipe[pipe_valid_int] <= hscaling_i;
                            pipe_valid_int <= pipe_valid_int + 1;
                            assert (pipe_valid_int <= PIPES) else $fatal("Pipeline overflow [time %0d ns]: pipe_valid_int exceeded PIPES",
                            $time);
                        end else begin: pipeline_flush
                            for (int p = 0; p < pipe_valid_int; p++) begin
                                if (pipe_valid[p]) begin
                                    pipe_valid[p] <= 0;
                                end
                            end
                            pipe_valid_int <= 0;
                        end
                    end
                end
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            energy_ready_i = 0;
            expected_spin_counter = 0;
            expected_energy = 0;
            expected_local_energy = 0;
            end else begin
            if (energy_valid_o && energy_ready_i) begin: new_testcase_start
                energy_ready_i = 0;
                expected_spin_counter = 0;
                expected_energy = 0;
                expected_local_energy = 0;
            end
            else if (expected_spin_counter >= DATASPIN) begin: keep_waiting
                energy_ready_i = energy_ready_i;
                expected_spin_counter = expected_spin_counter;
                expected_energy = expected_energy;
                expected_local_energy = expected_local_energy;
            end
            else if (weight_valid_i && weight_ready_o) begin: calculate_energy
                if (PIPES == 0) begin: no_pipeline_mode
                    expected_local_energy = compute_local_energy(
                        spin_reg[testcase_counter-1],
                        weight_i,
                        hbias_i,
                        hscaling_i,
                        expected_spin_counter
                    );
                    expected_energy += expected_local_energy;
                    expected_spin_counter += 1;
                end else begin: pipeline_mode
                    if (spin_reg_valid[testcase_counter-1] == 1'b0) begin: pipeline_stall
                        // wait for spin data, do nothing
                    end else begin: pipeline_no_stall
                        for (int p = 0; p < pipe_valid_int; p++) begin
                            if (pipe_valid[p]) begin
                                expected_local_energy = compute_local_energy(
                                    spin_reg[testcase_counter-1],
                                    weight_pipe[p],
                                    hbias_pipe[p],
                                    hscaling_pipe[p],
                                    expected_spin_counter
                                );
                                expected_energy += expected_local_energy;
                                expected_spin_counter += 1;
                            end
                        end
                        expected_local_energy = compute_local_energy(
                            spin_reg[testcase_counter-1],
                            weight_i,
                            hbias_i,
                            hscaling_i,
                            expected_spin_counter
                        );
                        expected_energy += expected_local_energy;
                        expected_spin_counter += 1;
                    end
                end
                if (expected_spin_counter >= DATASPIN) begin
                    energy_ready_i = 1;
                end else begin
                    energy_ready_i = 0;
                end
            end
        end
    end

    // ========================================================================
    // Tasks and functions
    // ========================================================================
    // Function to compute local energy
    function automatic signed [LOCAL_ENERGY_BIT-1:0] compute_local_energy(
        input logic [DATASPIN-1:0] spin_vec,
        input logic [DATASPIN*BITJ-1:0] weight_vec,
        input logic signed [BITH-1:0] hbias,
        input logic unsigned [SCALING_BIT-1:0] hscaling,
        input logic [$clog2(DATASPIN)-1:0] spin_idx
    );
        logic signed [LOCAL_ENERGY_BIT-1:0] local_energy_temp;
        logic signed [BITJ-1:0] weight_temp;
        begin
            local_energy_temp = 0;
            for (int i = 0; i < DATASPIN; i++) begin
                if (i == spin_idx) begin
                    local_energy_temp += hbias * $signed({1'b0, hscaling});
                end else begin
                    weight_temp = $signed(weight_vec[i*BITJ +: BITJ]);
                    local_energy_temp += spin_vec[i] ? weight_temp : -weight_temp;
                end
            end
            compute_local_energy = spin_vec[spin_idx] ? local_energy_temp : -local_energy_temp;
        end
    endfunction

    // Task for timer
    task automatic timer();
        begin
            total_cycles = 0;
            transaction_cycles = 0;
            total_time = 0;
            transaction_time = 0;
            start_time = 0;
            end_time = 0;
            wait(rst_ni);
            wait(spin_valid_i && spin_ready_o);
            start_time = $time;
            wait(testcase_counter == NUM_TESTS && energy_valid_o && energy_ready_i);
            end_time = $time;
            total_time = end_time - start_time;
            total_cycles = total_time / CLKCYCLE;
            transaction_cycles = total_cycles / NUM_TESTS;
            transaction_time = transaction_cycles * CLKCYCLE;
            $display("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
            $display("Timer [Time %0d ns]: start time: %0d ns, end time: %0d ns, duration: %0d ns, transactions: %0d",
                $time, start_time, end_time, total_time, NUM_TESTS);
            $display("Timer [Time %0d ns]: Total cycles: %0d cc [%0d ns], Cycles/transaction: %0d cc [%0d ns]",
                $time, total_cycles, total_time, transaction_cycles, transaction_time);
            $display("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
        end
    endtask

    // Task for scoreboard
    task automatic check_energy();
        begin
            correct_count = 0;
            error_count = 0;
            total_count = 0;
            wait(rst_ni);
            forever begin
                wait(energy_valid_o && energy_ready_i);
                if (energy_o !== expected_energy) begin
                $error("Testcase [%0d] Energy mismatch: received 'd%0d, expected 'd%0d",
                    testcase_counter, energy_o, expected_energy);
                error_count = error_count + 1;
                end else begin
                    // $display("Testcase [%0d] Energy match: 'd%0d", testcase_counter, energy_o);
                    correct_count = correct_count + 1;
                end
                total_count = total_count + 1;
                if (total_count == NUM_TESTS) begin
                    @(posedge clk_i);
                    $display("----------------------------------------");
                    $display("Scoreboard [Time %0d ns]: %0d/%0d correct, %0d/%0d errors",
                        $time, correct_count, total_count, error_count, total_count);
                    $display("----------------------------------------");
                end
                @(posedge clk_i);
            end
        end
    endtask

    // Task to handle spin input
    task automatic spin_interface();
        begin
            spin_valid_i = 0;
            spin_i = 'd0;
            // Wait for reset to be released
            wait(rst_ni);
            do begin
                // Wait for config to complete if it's active
                if (config_valid_i) begin
                    wait (!config_valid_i);
                    @(posedge clk_i); // Wait one more cycle after config
                end

                // Generate and send spin data
                repeat ($urandom_range(0, 5)) @(posedge clk_i); // Random wait before sending spin data
                spin_valid_i = 1;
                for (int i = 0; i < DATASPIN; i++) begin
                    case(test_mode)
                        `S1W1H1_TEST: spin_i[i] = 1'b1;
                        `S0W1H1_TEST: spin_i[i] = 1'b0;
                        `S0W0H0_TEST: spin_i[i] = 1'b0;
                        `S1W0H0_TEST: spin_i[i] = 1'b1;
                        `MaxPosValue_TEST: spin_i[i] = 1'b1;
                        `MaxNegValue_TEST: spin_i[i] = 1'b0;
                        `RANDOM_TEST: spin_i[i] = $urandom() % 2;
                        default: spin_i[i] = 1'b0;
                    endcase
                end

                // Wait for handshake
                wait(spin_ready_o);
                @(posedge clk_i);
                spin_valid_i = 0;

                // Wait before next spin operation
                if (SPIN_LATENCY_RANDOM == `True) begin
                    repeat($urandom_range(0, SPIN_LATENCY)) @(posedge clk_i);
                end else begin
                    repeat(SPIN_LATENCY) @(posedge clk_i);
                end
            end
            while (spin_reg_valid_int < NUM_TESTS);
        end
    endtask

    // Task to handle weight input
    task automatic weight_interface();
        begin
            logic signed [BITJ-1:0] weight_temp;
            spin_idx = 0;

            weight_valid_i = 0;
            weight_i = 'd0;
            hbias_i = 'd0;
            hscaling_i = 'd0;
            wait(rst_ni);

            forever begin
                // Wait for config to complete
                if (config_valid_i) begin
                    wait (!config_valid_i);
                    @(posedge clk_i);
                end
            
                // Prepare weight data but do NOT assert yet
                for (int i = 0; i < DATASPIN; i++) begin
                    case(test_mode)
                        `S1W1H1_TEST: weight_temp = {{(BITJ-1){1'b0}},1'b1}; // +1
                        `S0W1H1_TEST: weight_temp = {{(BITJ-1){1'b0}},1'b1}; // +1
                        `S0W0H0_TEST: weight_temp = {(BITJ){1'b1}}; // -1
                        `S1W0H0_TEST: weight_temp = {(BITJ){1'b1}}; // -1
                        `MaxPosValue_TEST: weight_temp = (1 << (BITJ-1)) - 1; // Max positive value
                        `MaxNegValue_TEST: weight_temp = -(1 << (BITJ-1)); // Max negative value
                        `RANDOM_TEST: weight_temp = $urandom();
                        default: weight_temp = 'd0;
                    endcase
                    weight_i[i*BITJ +: BITJ] = weight_temp;
                end
                weight_i[spin_idx*BITJ +: BITJ] = 'd0;
            
                case(test_mode)
                    `S1W1H1_TEST: hbias_i = {{(BITH-1){1'b0}},1'b1}; // +1
                    `S0W1H1_TEST: hbias_i = {{(BITH-1){1'b0}},1'b1}; // +1
                    `S0W0H0_TEST: hbias_i = {(BITH){1'b1}}; // -1
                    `S1W0H0_TEST: hbias_i = {(BITH){1'b1}}; // -1
                    `MaxPosValue_TEST: hbias_i = (1 << (BITH-1)) - 1; // Max positive value
                    `MaxNegValue_TEST: hbias_i = -(1 << (BITH-1)); // Max negative value
                    `RANDOM_TEST: hbias_i = $urandom();
                    default: hbias_i = 'd0;
                endcase

                case(test_mode)
                    `S1W1H1_TEST: hscaling_i = 'd1;
                    `S0W1H1_TEST: hscaling_i = 'd1;
                    `S0W0H0_TEST: hscaling_i = 'd1;
                    `S1W0H0_TEST: hscaling_i = 'd1;
                    `MaxPosValue_TEST: hscaling_i = 'd16;
                    `MaxNegValue_TEST: hscaling_i = 'd16;
                    `RANDOM_TEST: hscaling_i = (1 << ($urandom() % SCALING_BIT));
                    default: hscaling_i = 'd1;
                endcase
            
                // Now assert valid and wait for a handshake
                weight_valid_i = 1;
                do @(posedge clk_i);
                while (!(weight_valid_i && weight_ready_o));
            
                // Handshake occurred here — safe to update next data next cycle
                spin_idx = (spin_idx + 1) % DATASPIN;
                transaction_count++;
            
                // Deassert valid if you want to insert latency
                if (MEM_LATENCY > 0) begin
                    weight_valid_i = 0;
                    if (MEM_LATENCY_RANDOM == `True) begin
                        repeat($urandom_range(0, MEM_LATENCY)) @(posedge clk_i);
                    end else begin
                        repeat(MEM_LATENCY) @(posedge clk_i);
                    end
                end
            end
        end
    endtask

    // ========================================================================
    // Testbench task and timer setup
    // ========================================================================
    // Spin interface
    initial begin
        fork
            spin_interface();
            weight_interface();
            check_energy();
            timer();
        join_none
    end

endmodule
