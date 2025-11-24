// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`timescale 1ns / 1ps

`ifndef DBG
`define DBG 0
`endif

`define S1W1H1_TEST 000
`define S0W1H1_TEST 001
`define S0W0H0_TEST 010
`define S1W0H0_TEST 011
`define MaxPosValue_TEST 100
`define MaxNegValue_TEST 101
`define RANDOM_TEST 110


module tb_energy_monitor;

    // Testbench parameters
    localparam int test_mode = `RANDOM_TEST; // select test mode
    localparam int NUM_TESTS = 1_000_000; // number of test cases
    localparam int CLKCYCLE = 2; // clock cycle in ns
    localparam int MEM_LATENCY = 1; // latency of memories in cycles
    localparam int SPIN_LATENCY = 10; // latency of spin input in cycles

    // Module parameters
    localparam int BITJ = 4; // J precision
    localparam int BITH = 4; // bias precision
    localparam int DATASPIN = 256; // number of spins
    localparam int SCALING_BIT = 5; // bit width of scaling factor
    localparam int LOCAL_ENERGY_BIT = 16; // bit width of local energy
    localparam int ENERGY_TOTAL_BIT = 32; // bit width of total energy
    localparam int PIPES = 0; // number of pipeline stages

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

    logic [DATASPIN-1:0] spin_reg [0:NUM_TESTS-1];
    logic signed [BITJ-1:0] weight_expected;
    logic [DATASPIN*BITJ-1:0] weight_stored;
    logic signed [BITH-1:0] hbias_stored;
    logic unsigned [SCALING_BIT-1:0] hscaling_stored;
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
                $display("Starting energy monitor testbench. Running %0d/%0d tests...", testcase_counter, NUM_TESTS);
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
            $display("Debug mode enabled. Running with detailed output.");
            $dumpfile("tb_energy_monitor.vcd");
            $dumpvars(2, weight_interface);
            $dumpvars(2, tb_energy_monitor);
                #(2000 * CLKCYCLE); // To avoid generating too large VCD files
                $display("Testbench timeout reached. Ending simulation.");
                $finish;
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
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            for (int i = 0; i < NUM_TESTS; i++) begin
                spin_reg[i] = 0;
            end
        end
        else begin
            if (spin_valid_i && spin_ready_o) begin
                spin_reg[testcase_counter-1] = spin_i;
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
            if (energy_valid_o && energy_ready_i) begin
                energy_ready_i = 0;
                expected_spin_counter = 0;
                expected_energy = 0;
                expected_local_energy = 0;
            end
            else if (expected_spin_counter == DATASPIN) begin
                energy_ready_i = energy_ready_i;
                expected_spin_counter = expected_spin_counter;
                expected_energy = expected_energy;
                expected_local_energy = expected_local_energy;
            end
            else if (weight_valid_i && weight_ready_o) begin
                expected_local_energy = 0;
                for (int j = 0; j < DATASPIN; j++) begin
                    if (j == expected_spin_counter) begin
                        expected_local_energy += hbias_i * $signed({1'b0, hscaling_i});
                    end else begin
                        weight_expected = $signed(weight_i[j*BITJ +: BITJ]);
                        expected_local_energy += spin_reg[testcase_counter-1][j] ? weight_expected : -weight_expected;
                    end
                end
                expected_local_energy = spin_reg[testcase_counter-1][expected_spin_counter] ? expected_local_energy : -expected_local_energy;
                expected_energy += expected_local_energy;
                expected_spin_counter += 1;
                if (expected_spin_counter == DATASPIN) begin
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
            forever begin
                // Wait for config to complete if it's active
                if (config_valid_i) begin
                    wait (!config_valid_i);
                    @(posedge clk_i); // Wait one more cycle after config
                end

                // Generate and send spin data
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
                repeat(SPIN_LATENCY) @(posedge clk_i);
            end
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
                    repeat(MEM_LATENCY) @(posedge clk_i);
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
        join_none
    end

endmodule
