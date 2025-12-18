// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Jiacong Sun <jiacong.sun@kuleuven.be>

`timescale 1ns / 1ps

`ifndef DBG
`define DBG 0
`endif

`ifndef VCD_FILE
`define VCD_FILE "tb_flip_manager.vcd"
`endif

module tb_flip_manager;

    // Module parameters
    localparam int DATASPIN = 256; // number of spins
    localparam int ENERGY_TOTAL_BIT = 32; // bit width of total energy
    localparam int SPIN_DEPTH = 2; // depth of spin/energy FIFOs
    localparam int FLIP_ICON_DEPTH = 1024; // number of entries in flip, must be multiply of SPIN_DEPTH

    // Testbench parameters
    localparam int CLKCYCLE = 2;
    localparam int ENABLE_ENERGY_COMPARISON = 1; // set to 1 to enable energy comparison
    localparam int MEM_LATENCY = 0; // latency of memories in cycles (must be 0, which means 1 cycle)
    localparam int ENERGY_MONITOR_LATENCY = 1; // latency of energy monitor in cycles
    localparam int ANALOG_DELAY = 1; // delay of analog macro in cycles
    localparam bit RANDOM_TEST = 1; // set to 1 for random tests, 0 for fixed tests
    // localparam int NUM_TESTS = 1; // number of test cases (not used)

    localparam int FLUSH_NUM_TESTS = 1; // no flush tests

    // Testbench internal signals
    logic clk_i;
    logic rst_ni;
    logic en_i;
    logic flush_i;
    logic en_comparison_i;
    logic cmpt_en_i;
    logic cmpt_idle_o;
    logic spin_configure_valid_i;
    logic [DATASPIN-1:0] spin_configure_i;
    logic spin_configure_push_none_i;
    logic spin_configure_ready_o;
    logic spin_pop_valid_o;
    logic [DATASPIN-1:0] spin_pop_o;
    logic spin_pop_ready_i;
    logic spin_valid_i;
    logic [DATASPIN-1:0] spin_i;
    logic spin_ready_o;
    logic spin_energy_monitor_ready;
    logic energy_valid_i;
    logic energy_ready_o;
    logic signed [ENERGY_TOTAL_BIT-1:0] energy_i;
    logic flip_ren_o;
    logic [$clog2(FLIP_ICON_DEPTH)+1-1:0] flip_raddr_o;
    logic [$clog2(FLIP_ICON_DEPTH)+1-1:0] icon_last_raddr_plus_one_i;
    logic [DATASPIN-1:0] flip_rdata_i;
    logic flip_disable_i;
    logic host_readout_i;
    logic spin_pop_ready_host;
    logic spin_pop_ready_analog;
    logic [DATASPIN-1:0] spin_read_out_host;

    logic configure_test_done;
    logic spin_push_handshake;
    logic spin_pop_handshake;

    // Task monitoring variables (moved to module level for VCD dumping)
    integer configure_counter;
    integer flush_counter;
    logic [DATASPIN-1:0] spin_configure_prev;
    logic [$clog2(FLIP_ICON_DEPTH)-1:0] icon_addr;
    logic icon_finished;
    integer transaction_count_flip_icon;
    integer transaction_count_analog_rx;
    integer transaction_count_analog_tx;
    integer readout_count_host;
    integer transaction_count_energy_monitor;
    integer rnd_delay;
    integer energy_handshake_count;

    assign spin_push_handshake = spin_valid_i & spin_ready_o & spin_energy_monitor_ready;
    assign spin_pop_handshake = spin_pop_valid_o & spin_pop_ready_i;

    assign spin_pop_ready_i = spin_pop_ready_host ? spin_pop_ready_host : spin_pop_ready_analog;

    initial begin
        en_i = 1;
        en_comparison_i = ENABLE_ENERGY_COMPARISON;
        icon_last_raddr_plus_one_i = FLIP_ICON_DEPTH;
    end

    // Module instantiation
    flip_manager #(
        .DATASPIN(DATASPIN),
        .SPIN_DEPTH(SPIN_DEPTH),
        .ENERGY_TOTAL_BIT(ENERGY_TOTAL_BIT),
        .FLIP_ICON_DEPTH(FLIP_ICON_DEPTH)
    ) dut (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .en_i(en_i),
        .flush_i(flush_i),
        .en_comparison_i(en_comparison_i),
        .cmpt_en_i(cmpt_en_i),
        .cmpt_idle_o(cmpt_idle_o),
        .host_readout_i(host_readout_i),
        .spin_configure_valid_i(spin_configure_valid_i),
        .spin_configure_i(spin_configure_i),
        .spin_configure_push_none_i(spin_configure_push_none_i),
        .spin_configure_ready_o(spin_configure_ready_o),
        .spin_pop_valid_o(spin_pop_valid_o),
        .spin_pop_o(spin_pop_o),
        .spin_pop_ready_i(spin_pop_ready_i),
        .spin_valid_i(spin_valid_i),
        .spin_i(spin_i),
        .spin_ready_o(spin_ready_o),
        .energy_valid_i(energy_valid_i),
        .energy_ready_o(energy_ready_o),
        .energy_i(energy_i),
        .flip_ren_o(flip_ren_o),
        .flip_raddr_o(flip_raddr_o),
        .icon_last_raddr_plus_one_i(icon_last_raddr_plus_one_i),
        .flip_rdata_i(flip_rdata_i),
        .flip_disable_i(flip_disable_i)
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
            $dumpvars(4, tb_flip_manager); // Dump all variables in testbench module
            $timeformat(-9, 1, " ns", 9);
            #(600 * CLKCYCLE); // To avoid generating huge VCD files
            $display("Testbench timeout reached. Ending simulation.");
            $finish;
        end
        else begin
            $timeformat(-9, 1, " ns", 9);
            #(2_000_000 * CLKCYCLE);
            $display("Testbench timeout reached. Ending simulation.");
            $finish;
        end
    end

    // ========================================================================
    // Tasks and functions
    // ========================================================================
    // Task for spin configuration
    task automatic configure_spin();
        begin
            configure_counter = 0;
            flush_counter = 0;
            configure_test_done = 0;

            while (!rst_ni) begin
                spin_configure_valid_i = 0;
                spin_configure_i = 'd0;
                spin_configure_prev = 'd0;
                spin_configure_push_none_i = 1'b0;
                flush_i = 0;
                @(posedge clk_i);
            end
            while (!en_i) @(posedge clk_i);
            do begin
                // random cycle delay between 1 and 5 cycles
                rnd_delay = $urandom_range(1, 5);
                repeat (rnd_delay) @(posedge clk_i);
                #(0.1 * CLKCYCLE);
                flush_i = 1;
                #(CLKCYCLE);
                flush_i = 0;
                flush_counter++;
                configure_counter = 0;

                while (configure_counter < SPIN_DEPTH) begin
                    @(posedge clk_i);
                    // send spin
                    spin_configure_valid_i = 1;
                    spin_configure_prev = spin_configure_i;
                    if (RANDOM_TEST) begin
                        // generate random bitstring: each bit randomly 0 or 1
                        for (int i = 0; i < DATASPIN; i++) begin
                            spin_configure_i[i] = $urandom_range(0, 1);
                        end
                    end else begin
                        spin_configure_i = '1; // all ones
                    end
                    // check FIFO content
                    if (configure_counter > 0) begin
                        if (dut.u_spin_fifo_maintainer.spin_fifo.mem_n[configure_counter-1] !== spin_configure_prev) begin
                            $display("Error: FIFO content mismatch at time %t: expected %h, got %h", $time, spin_configure_prev, dut.u_spin_fifo_maintainer.spin_fifo.mem_n[configure_counter-1]);
                            @(posedge clk_i);
                            $finish;
                        end
                    end
                    // Wait for spin handshake
                    while (!spin_configure_ready_o) begin
                        @(posedge clk_i);
                    end
                    configure_counter++;
                end
                @(posedge clk_i);
                spin_configure_valid_i = 0;
                spin_configure_i = 'd0;
            end
            while(flush_counter < FLUSH_NUM_TESTS);
            configure_test_done = 1;
            @(posedge clk_i);
            $display("------------------------------------------------");
            $display("---- Spin configuration completed [Pass: %0d] ----", flush_counter);
            $display("------------------------------------------------");
        end
    endtask

    // Task for flip icon memory interface
    task automatic flip_icon_interface();
        begin
            while (!rst_ni) begin
                flip_rdata_i = 'd0;
                icon_finished = 0;
                icon_addr = 'd0;
                transaction_count_flip_icon = 0;
                @(posedge clk_i);
            end
            while (!configure_test_done | !en_i) @(posedge clk_i);

            forever begin
                if (RANDOM_TEST) begin
                    for (int i = 0; i < DATASPIN; i++) begin
                        flip_rdata_i[i] = $urandom_range(0, 1);
                    end
                end else begin
                    flip_rdata_i = '1; // all ones
                end
                do @(posedge clk_i);
                while (!flip_ren_o);
                if (transaction_count_flip_icon > 0)
                    if (icon_addr != flip_raddr_o - 1) begin
                        $display("Error: Flip icon address mismatch at time %t: expected %h, got %h", $time, icon_addr, flip_raddr_o);
                        @(posedge clk_i);
                        // $finish;
                    end
                // record the address
                icon_addr = flip_raddr_o;
                transaction_count_flip_icon++;
                // check for end of icon
                if (icon_addr == icon_last_raddr_plus_one_i - 1) begin
                    icon_finished = 1;
                end

                // Insert latency
                if (MEM_LATENCY > 0) begin
                    repeat(MEM_LATENCY) @(posedge clk_i);
                end
            end
        end
    endtask

    // Task for analog RX interface (spin input)
    task automatic analog_rx_interface();
        begin
            integer i = 0;
            while (!rst_ni) begin
                spin_pop_ready_analog = 0;
                transaction_count_analog_rx = 0;
                @(posedge clk_i);
            end
            while (!configure_test_done | !en_i) @(posedge clk_i);
            #(0.1 * CLKCYCLE);
            spin_pop_ready_analog = 1;
            forever begin
                while (spin_pop_ready_host) @(posedge clk_i); // give priority to host readout
                do begin
                    spin_pop_ready_analog = 1;
                    @(posedge clk_i);
                end
                while (!spin_pop_valid_o);
                #(0.1 * CLKCYCLE);
                spin_pop_ready_analog = 0;
                transaction_count_analog_rx++;

                // Wait for spin_push_handshake to become active
                wait(spin_push_handshake);
                @(posedge clk_i);
            end
        end
    endtask

    // Task for analog TX interface (spin output)
    task automatic analog_tx_interface();
        begin
            while (!rst_ni) begin
                spin_valid_i = 0;
                spin_i = 'd0;
                transaction_count_analog_tx = 0;
                @(posedge clk_i);
            end
            while (!configure_test_done | !en_i) @(posedge clk_i);
            forever begin
                do @(posedge clk_i);
                while (!(spin_pop_handshake) | spin_pop_ready_host); // give priority to host readout
                // mimic random delay of analog macro, range between 1 and 20 cycles
                if (RANDOM_TEST) begin
                    repeat (ANALOG_DELAY) @(posedge clk_i);
                end else begin
                    repeat (1) @(posedge clk_i); // mimic analog latency, 1 means 1 cycle
                end
                while (!spin_energy_monitor_ready) @(posedge clk_i);
                if (RANDOM_TEST) begin
                    for (int i = 0; i < DATASPIN; i++) begin
                        spin_i[i] = $urandom_range(0, 1);
                    end
                end else begin
                    if (transaction_count_analog_tx % 2 == 0)
                        spin_i = '0; // all zeros
                    else
                        spin_i = '1; // all ones
                end
                #(0.1 * CLKCYCLE);
                spin_valid_i = 1;
                do @(posedge clk_i);
                while (!(spin_ready_o & spin_energy_monitor_ready));
                spin_valid_i = 0;
                transaction_count_analog_tx++;
            end
        end
    endtask

    // Task for energy handshake counter
    task automatic energy_handshake_counter();
        begin
            while (!rst_ni) begin
                energy_handshake_count = 0;
                @(posedge clk_i);
            end
            while (!configure_test_done | !en_i) @(posedge clk_i);
            forever begin
                do @(posedge clk_i);
                while (!energy_valid_i || !energy_ready_o);
                energy_handshake_count++;
            end
        end
    endtask

    // Task for host interface (cmpt start and readout)
    task automatic host_interface();
        begin
            while (!rst_ni) begin
                readout_count_host = 0;
                cmpt_en_i = 0;
                flip_disable_i = 0;
                host_readout_i = 0;
                spin_pop_ready_host = 0;
                @(posedge clk_i);
            end
            while (!configure_test_done | !en_i) @(posedge clk_i);
            // random cycle delay between 5 and 10 cycles, to monitor cmpt_idle_o behavior
            #(0.1 * CLKCYCLE);
            forever begin
                cmpt_en_i = 1;
                @(posedge clk_i);
                cmpt_en_i = 0;
                // wait for completion
                do @(posedge clk_i);
                while (energy_handshake_count < icon_last_raddr_plus_one_i);

                // read out the FIFO content
                #(20.1 * CLKCYCLE); // small delay before readout
                host_readout_i = 1;
                flip_disable_i = 1; // disable flipping during host readout
                spin_pop_ready_host = 1;
                while (readout_count_host < SPIN_DEPTH) begin
                    do @(posedge clk_i);
                    while (!spin_pop_valid_o);
                    spin_read_out_host = spin_pop_o;
                    // check FIFO content
                    if (spin_read_out_host !== dut.u_spin_fifo_maintainer.spin_fifo.mem_n[readout_count_host]) begin
                        // note: this check fails if SPIN_DEPTH % DATASPIN != 0
                        @(posedge clk_i);
                        $fatal(1, "Error: Host readout FIFO content ['d%0d] mismatch at time %t: expected 'h%h, got 'h%h",
                            readout_count_host, $time, dut.u_spin_fifo_maintainer.spin_fifo.mem_n[readout_count_host], spin_read_out_host);
                    end else begin
                        $display("Pass: Host readout FIFO content ['d%0d] match at time %t: got 'h%h",
                            readout_count_host, $time, spin_read_out_host);
                    end
                    readout_count_host++;
                end
                host_readout_i = 0;
                flip_disable_i = 0;
                spin_pop_ready_host = 0;
                cmpt_en_i = 0;

                if (readout_count_host == SPIN_DEPTH) begin
                    $display("------------------------------------------------------");
                    $display("-- All readout tests completed [Readout count: 'd%0d] --", readout_count_host);
                    $display("------------------------------------------------------");
                    @(posedge clk_i);
                    $finish;
                end
            end
        end
    endtask

    // Task for energy monitor module interface
    task automatic energy_monitor_interface();
        begin
            while (!rst_ni) begin
                spin_energy_monitor_ready = 1;
                energy_valid_i = 0;
                energy_i = {1'b0, {(ENERGY_TOTAL_BIT-1){1'b1}}}; // initial energy value
                transaction_count_energy_monitor = 0;
                @(posedge clk_i);
            end
            while (!configure_test_done | !en_i) @(posedge clk_i);
            forever begin
                while (!(spin_push_handshake)) @(posedge clk_i);
                spin_energy_monitor_ready = 0;
                repeat (ENERGY_MONITOR_LATENCY) @(posedge clk_i);
                if (RANDOM_TEST) begin
                    for (int i = 0; i < ENERGY_TOTAL_BIT; i++) begin
                        energy_i[i] = $urandom_range(0, 1);
                    end
                end else begin
                    energy_i = energy_i - 1; // decremental energy
                end
                #(0.1 * CLKCYCLE);
                energy_valid_i = 1;
                do @(posedge clk_i);
                while (!energy_ready_o);
                #(0.1 * CLKCYCLE);
                energy_valid_i = 0;
                spin_energy_monitor_ready = 1;
                transaction_count_energy_monitor++;
            end
        end
    endtask

    // Task for scoreboard check
    task automatic scoreboard_check();
        begin
            // Check if the scoreboard matches the expected values
        end
    endtask

    // ========================================================================
    // Testbench task and timer setup
    // ========================================================================
    initial begin
        fork
            configure_spin();
            flip_icon_interface();
            analog_rx_interface();
            analog_tx_interface();
            host_interface();
            energy_handshake_counter();
            energy_monitor_interface();
        join_none
    end

endmodule
