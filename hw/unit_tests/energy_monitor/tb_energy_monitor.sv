// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`timescale 1ns / 1ps

`ifndef DBG
`define DBG 0
`endif

module tb_energy_monitor;

    localparam int BITJ = 4; // J precision
    localparam int BITH = 4; // bias precision
    localparam int DATASPIN = 4; // number of spins
    localparam int SCALING_BIT = 5; // bit width of scaling factor
    localparam int LOCAL_ENERGY_BIT = 16; // bit width of local energy
    localparam int ENERGY_TOTAL_BIT = 32; // bit width of total energy
    localparam int PIPES = 0; // number of pipeline stages

    localparam int CLKCYCLE = 2;
    localparam int MEM_LATENCY = 1; // latency of memories in cycles
    localparam int SPIN_LATENCY = 10; // latency of spin input in cycles
    localparam bit RANDOM_TEST = 0; // set to 1 for random tests, 0 for fixed tests
    localparam int NUM_TESTS = 1; // number of test cases

    // Testbench signals
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
    logic signed [BITJ-1:0] weight_reg [0:DATASPIN-1];
    logic signed [BITH-1:0] hbias_reg;
    logic unsigned [SCALING_BIT-1:0] hscaling_reg;
    logic expected_valid;
    logic unsigned [DATASPIN-1:0] expected_spin_counter;
    logic signed [LOCAL_ENERGY_BIT-1:0] expected_local_energy;
    logic signed [ENERGY_TOTAL_BIT-1:0] expected_energy;
    logic unsigned [31:0] testcase_counter;
    logic unsigned [ $clog2(DATASPIN)-1 : 0 ] transaction_count;

    assign expected_valid = energy_ready_i;

    initial begin
        transaction_count = 0;
    end

    initial begin
        testcase_counter = 1;
        $display("Starting energy monitor testbench. Running %0d/%0d tests...", testcase_counter, NUM_TESTS);
        if (testcase_counter >= NUM_TESTS) begin
            wait (energy_valid_o);
            $finish;
        end else if (spin_valid_i && spin_ready_o) begin
            testcase_counter += 1;
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
                        expected_local_energy += hbias_i * hscaling_i;
                        $display("Bias contribution (%0d): %0d * %0d = %0d\n", j, hbias_i, hscaling_i, hbias_i * hscaling_i);
                    end else begin
                        weight_expected = $signed(weight_i[j*BITJ +: BITJ]);
                        expected_local_energy += spin_reg[testcase_counter-1][j] ? weight_expected : -weight_expected;
                        $display("Weight contribution (%0d): spin %0d * weight %0d = %0d\n", j, spin_reg[testcase_counter-1][j], weight_expected, spin_reg[testcase_counter-1][j] ? weight_expected : -weight_expected);
                    end
                end
                expected_local_energy = spin_reg[testcase_counter-1][expected_spin_counter] ? expected_local_energy : -expected_local_energy;
                expected_energy += expected_local_energy;
                expected_spin_counter += 1;
                if (expected_spin_counter == DATASPIN)
                    energy_ready_i = 1;
                else
                    energy_ready_i = 0;
            end
        end
    end


    // Initial values for debug signal and energy ready signal
    initial begin
        debug_en_i = 0;
    end

    // Run tests
    initial begin
        if (`DBG) begin
            $display("Debug mode enabled. Running with detailed output.");
            $dumpfile("tb_energy_monitor.vcd");
            $dumpvars(1,tb_energy_monitor);
            $dumpvars(0, dut.u_counter_ctrl);
            $dumpvars(1, dut.u_logic_ctrl);
            $dumpvars(1, dut.u_accumulator);
        end
        // $display("Starting energy monitor testbench. Running %0d tests...", NUM_TESTS);
        // for (int i = 0; i < NUM_TESTS; i++) begin
        //     a = test_a[i];
        //     expected_output = expected_outputs[i];
        //     #5;
        //     assert (out == expected_output)
        //         else $fatal("Test %0d failed: expected_output=%0h, got %0h",
        //                     i, expected_outputs[i], out);
        //     $write( "Test %0d,\t expected_output=%0h,\t\t got %0h\n",
        //         i, expected_output, out);
        // end
        // #10;
        // $display("All tests (#%0d) completed successfully.", NUM_TESTS);
        // $finish;
    end

    // ========================================================================
    // Tasks and functions
    // ========================================================================
    // Task for scoreboard
    task automatic check_energy();
        begin
            integer correct_count;
            integer error_count;
            integer total_count;
            correct_count = 0;
            error_count = 0;
            total_count = 0;
            wait(rst_ni);
            forever begin
                @(posedge clk_i);
                if (energy_valid_o && energy_ready_i) begin
                    if (energy_o !== expected_energy) begin
                    $error("Energy mismatch: received %0d, expected %0d",
                        energy_o, expected_energy);
                    error_count = error_count + 1;
                    end else begin
                        $display("Energy match: %0d", energy_o);
                        correct_count = correct_count + 1;
                    end
                    total_count = total_count + 1;
                    $display("Scoreboard: %0d correct, %0d errors, out of %0d total",
                        correct_count, error_count, total_count);
                end
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
                    if (RANDOM_TEST)
                        spin_i[i] = $urandom() % 2;
                    else
                        spin_i[i] = 1'b1;
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
            integer spin_idx;

            spin_idx = 0;

            weight_valid_i = 0;
            weight_i = 'd0;
            hbias_i = 'd0;
            hscaling_i = 'd0;
            wait(rst_ni);

            forever begin
                // Wait for config to complete if it's active
                if (config_valid_i) begin
                    wait (!config_valid_i);
                    @(posedge clk_i); // Wait one more cycle after config
                end

                // Generate and send weight data
                weight_valid_i = 1;
                for (int i = 0; i < DATASPIN; i++) begin
                    if (RANDOM_TEST) begin
                        weight_temp = $urandom();
                    end else begin
                        weight_temp = 'd1;
                    end
                    weight_i[i*BITJ +: BITJ] = weight_temp;
                end

                weight_i[spin_idx*BITJ +: BITJ] = 'd0; // Set self-interaction weight to 0
                spin_idx = (spin_idx + 1) % DATASPIN;

                if (RANDOM_TEST) begin
                    hbias_i = $urandom();
                    hbias_i = hbias_i[BITH-1:0];
                end else begin
                    hbias_i = 'd1;
                end
                if (RANDOM_TEST)
                    hscaling_i = 1 << ($urandom() % SCALING_BIT);
                else
                    hscaling_i = 1;

                // Wait for handshake
                wait (weight_ready_o);
                transaction_count = transaction_count + 1;
                // $display("Weight transactions: %0d\n", transaction_count);
                @(posedge clk_i);
                weight_valid_i = 0;
                // Wait before next memory operation
                repeat(MEM_LATENCY) @(posedge clk_i);
            end
        end
    endtask

    // ========================================================================
    // Testbench logic
    // ========================================================================
    // Spin interface
    initial begin
        fork
            spin_interface();
            weight_interface();
            check_energy();
        join_none
    end
    initial begin
        #(1000 * CLKCYCLE);
        $display("Testbench timeout reached. Ending simulation.");
        $finish;
    end

endmodule
