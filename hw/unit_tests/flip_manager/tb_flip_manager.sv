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
    localparam int NUM_SPIN = 256; // number of spins
    localparam int ENERGY_TOTAL_BIT = 32; // bit width of total energy
    localparam int SPIN_DEPTH = 2; // depth of spin/energy FIFOs
    localparam int FLIP_ICON_DEPTH = 1024; // number of entries in flip, can be odd and even number

    // Testbench parameters
    localparam int CLKCYCLE = 2;
    localparam int ENABLE_ENERGY_COMPARISON = 1; // set to 1 to enable energy comparison
    localparam int FLIP_MEM_LATENCY = 1; // 1 means 1 cycle
    localparam int ENERGY_MONITOR_LATENCY = 5; // latency of energy monitor in cycles
    localparam int ANALOG_DELAY = 2; // delay of analog macro in cycles
    localparam bit RANDOM_TEST = 1; // set to 1 for random tests, 0 for fixed tests

    localparam int FLUSH_NUM_TESTS = 3; // no flush tests

    // Testbench internal signals
    logic clk_i;
    logic rst_ni;
    logic en_i;
    logic flush_i;
    logic en_comparison_i;
    logic cmpt_en_i;
    logic cmpt_idle_o;
    logic spin_configure_valid_i;
    logic [NUM_SPIN-1:0] spin_configure_i;
    logic spin_configure_push_none_i;
    logic spin_configure_ready_o;
    logic spin_pop_valid_o;
    logic [NUM_SPIN-1:0] spin_pop_o;
    logic spin_pop_ready_i;
    logic [NUM_SPIN-1:0] spin_i;
    logic spin_energy_monitor_ready;
    logic energy_valid_i;
    logic energy_ready_o;
    logic signed [ENERGY_TOTAL_BIT-1:0] energy_i;
    logic flip_ren_o;
    logic [$clog2(FLIP_ICON_DEPTH)+1-1:0] flip_raddr_o;
    logic [$clog2(FLIP_ICON_DEPTH)+1-1:0] icon_last_raddr_plus_one_i;
    logic [NUM_SPIN-1:0] flip_rdata_i;
    logic flip_disable_i;
    logic host_readout_i;
    logic spin_pop_ready_host;
    logic spin_pop_ready_analog;
    logic [NUM_SPIN-1:0] spin_read_out_host;
    logic signed [SPIN_DEPTH-1:0] [ENERGY_TOTAL_BIT-1:0] energy_fifo_o;

    logic configure_test_done;
    logic spin_pop_handshake;

    // Task monitoring variables
    integer configure_counter;
    integer flush_counter;
    logic [NUM_SPIN-1:0] spin_configure_prev;
    logic [$clog2(FLIP_ICON_DEPTH)-1+1:0] icon_addr;
    logic icon_finished;
    integer transaction_count_flip_icon;
    integer transaction_count_analog_rx;
    integer transaction_count_analog_tx;
    logic [$clog2(SPIN_DEPTH):0] readout_count_host;
    logic [$clog2(SPIN_DEPTH):0] readout_spin_addr_host;
    integer transaction_count_energy_monitor;
    integer rnd_delay;
    integer energy_handshake_count;
    integer spin_pop_handshake_count;
    integer cmpt_test_count;
    logic [$clog2(SPIN_DEPTH)-1:0] energy_fifo_pointer, spin_fifo_pointer;
    logic signed [ENERGY_TOTAL_BIT-1:0] energy_fifo_scoreboard [0:SPIN_DEPTH-1];
    logic [NUM_SPIN-1:0] spin_fifo_scoreboard [0:SPIN_DEPTH-1];
    logic [NUM_SPIN-1:0] expected_flipped_spin;
    logic icon_last_raddr_plus_one_is_odd;

    assign spin_pop_handshake = spin_pop_valid_o & spin_pop_ready_i;

    assign spin_pop_ready_i = spin_pop_ready_host ? spin_pop_ready_host : spin_pop_ready_analog;

    initial begin
        en_i = 1;
        en_comparison_i = ENABLE_ENERGY_COMPARISON;
        icon_last_raddr_plus_one_i = FLIP_ICON_DEPTH;
    end

    // Module instantiation
    flip_manager #(
        .NUM_SPIN(NUM_SPIN),
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
        .energy_valid_i(energy_valid_i),
        .energy_ready_o(energy_ready_o),
        .energy_i(energy_i),
        .spin_i(spin_i),
        .flip_ren_o(flip_ren_o),
        .flip_raddr_o(flip_raddr_o),
        .icon_last_raddr_plus_one_i(icon_last_raddr_plus_one_i),
        .flip_rdata_i(flip_rdata_i),
        .flip_disable_i(flip_disable_i),
        .energy_fifo_o(energy_fifo_o)
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
            #(200 * CLKCYCLE); // To avoid generating huge VCD files
            $display("Testbench timeout reached. Ending simulation.");
            $finish;
        end
        else begin
            $timeformat(-9, 1, " ns", 9);
            #(20_000_000 * CLKCYCLE);
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
                for (int i = 0; i < SPIN_DEPTH; i++) begin
                    spin_fifo_scoreboard[i] = 'd0;
                end
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

                while (configure_counter <= SPIN_DEPTH) begin
                    @(posedge clk_i);
                    // send spin
                    spin_configure_valid_i = 1;
                    spin_configure_prev = spin_configure_i;
                    if (RANDOM_TEST) begin
                        // generate random bitstring: each bit randomly 0 or 1
                        for (int i = 0; i < NUM_SPIN; i++) begin
                            spin_configure_i[i] = $urandom_range(0, 1);
                        end
                    end else begin
                        spin_configure_i = '1; // all ones
                    end
                    // check FIFO content
                    if (configure_counter > 0) begin
                        if (dut.u_spin_fifo_maintainer.spin_fifo.mem_n[configure_counter-1] !== spin_fifo_scoreboard[configure_counter-1]) begin
                            $display("Error: FIFO content mismatch at time %t: expected %h, got %h", $time, spin_fifo_scoreboard[configure_counter-1], dut.u_spin_fifo_maintainer.spin_fifo.mem_n[configure_counter-1]);
                            @(posedge clk_i);
                            $finish;
                        end
                    end
                    spin_fifo_scoreboard[configure_counter] = spin_configure_i;
                    configure_counter++;
                end
                @(posedge clk_i);
                spin_configure_valid_i = 0;
                spin_configure_i = 'd0;
            end
            while(flush_counter < FLUSH_NUM_TESTS);
            configure_test_done = 1;
            @(posedge clk_i);
            $display("--------------- Spin FIFO Configuration Check -------------------");
            $display("---- Spin fifo configuration tests completed [Pass: 'd%0d/'d%0d] ----", flush_counter, FLUSH_NUM_TESTS);
            $display("-----------------------------------------------------------------");
        end
    endtask

    // Task for lip icon rdata interface
    task automatic flip_icon_rdata_interface();
        begin
            flip_rdata_i = {(NUM_SPIN/2){2'b10}};
            wait (flip_ren_o == 1);
            forever begin
                do @(posedge clk_i);
                while (flip_ren_o == 0);
                // provide flip icon data
                flip_rdata_i = ~flip_rdata_i; // toggle data for testing
            end
        end
    endtask

    // Task for flip icon memory interface
    task automatic flip_icon_interface();
        begin
            while (!rst_ni) begin
                icon_finished = 0;
                icon_addr = 'd0;
                transaction_count_flip_icon = 0;
                @(posedge clk_i);
            end
            while (!configure_test_done | !en_i) @(posedge clk_i);

            forever begin
                do @(posedge clk_i);
                while (flip_ren_o == 0);
                // check address
                if (icon_addr != flip_raddr_o) begin
                    $display("Error: Flip icon address mismatch at time %t: expected 'h%h, got 'h%h", $time, icon_addr, flip_raddr_o);
                    @(posedge clk_i);
                    @(posedge clk_i);
                    $finish;
                end
                icon_addr++;
                transaction_count_flip_icon++;
                // check for end of icon
                if (icon_addr == icon_last_raddr_plus_one_i - 1) begin
                    icon_finished = 1;
                end

                // Insert latency
                if (FLIP_MEM_LATENCY > 0) begin
                    repeat(FLIP_MEM_LATENCY-1) @(posedge clk_i);
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

                repeat (ANALOG_DELAY) @(posedge clk_i);
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
                cmpt_test_count = 0;
                icon_last_raddr_plus_one_is_odd = 0;
                @(posedge clk_i);
            end
            while (!configure_test_done | !en_i) @(posedge clk_i);
            // random cycle delay between 5 and 10 cycles, to monitor cmpt_idle_o behavior
            #(0.1 * CLKCYCLE);
            while (cmpt_test_count < 1) begin
                readout_count_host = 0;
                readout_spin_addr_host = 0;
                host_readout_i = 0;
                spin_pop_ready_host = 0;
                cmpt_en_i = 1;
                @(posedge clk_i);
                cmpt_en_i = 0;
                // wait for completion
                do @(posedge clk_i);
                while (energy_handshake_count < icon_last_raddr_plus_one_i);

                // read out the FIFO content
                #(2.1 * CLKCYCLE); // small delay before readout
                host_readout_i = 1;
                flip_disable_i = 1; // disable flipping during host readout
                spin_pop_ready_host = 1;
                icon_last_raddr_plus_one_is_odd = icon_last_raddr_plus_one_i[0];
                while (readout_count_host < SPIN_DEPTH) begin
                    while (!spin_pop_valid_o) begin
                        // $display("Host readout waiting at time %t", $time); // for debug
                        @(negedge clk_i);
                    end
                    spin_read_out_host = spin_pop_o;
                    // check FIFO content
                    readout_spin_addr_host = icon_last_raddr_plus_one_is_odd ? (readout_count_host + 1) % SPIN_DEPTH : readout_count_host;
                    if (spin_read_out_host !== dut.u_spin_fifo_maintainer.spin_fifo.mem_n[readout_spin_addr_host]) begin
                        // note: this check fails if SPIN_DEPTH % NUM_SPIN != 0
                        $display(1, "Error: Host readout FIFO content ['d%0d] mismatch at time %t: expected 'h%h, got 'h%h",
                            readout_spin_addr_host, $time, dut.u_spin_fifo_maintainer.spin_fifo.mem_n[readout_spin_addr_host], spin_read_out_host);
                        @(negedge clk_i);
                        $finish;
                    end else begin
                        $display("Pass: Host readout FIFO content ['d%0d] match at time %t: got 'h%h",
                            readout_spin_addr_host, $time, spin_read_out_host);
                    end
                    readout_count_host++;
                    @(negedge clk_i);
                end
                host_readout_i = 0;
                flip_disable_i = 0;
                spin_pop_ready_host = 0;
                cmpt_en_i = 0;

                if (readout_count_host == SPIN_DEPTH) begin
                    $display("----------------------- Host Readout Check ---------------------");
                    $display("-- All readout tests completed successfully [Readout count: 'd%0d]! --", readout_count_host);
                    $display("----------------------------------------------------------------");
                    @(posedge clk_i);
                end
                cmpt_test_count++;
            end
            $finish;
        end
    endtask

    // Task for spin pop handshake counting
    task automatic energy_handshake_counter();
        begin
            spin_pop_handshake_count = 0;
            while (!rst_ni) begin
                @(posedge clk_i);
            end
            while (!configure_test_done | !en_i) @(posedge clk_i);
            forever begin
                do @(posedge clk_i);
                while (!spin_pop_handshake);
                spin_pop_handshake_count++;
            end
        end
    endtask

    // Task for energy monitor module interface
    task automatic energy_monitor_interface();
        begin
            integer i = 0;
            while (!rst_ni) begin
                energy_valid_i = 0;
                energy_i = {1'b0, {(ENERGY_TOTAL_BIT-1){1'b1}}};
                spin_i = {NUM_SPIN{1'b1}};
                energy_handshake_count = 0;
                @(posedge clk_i);
            end
            while (!configure_test_done | !en_i) @(posedge clk_i);
            while (energy_handshake_count < icon_last_raddr_plus_one_i) begin
                if (spin_pop_handshake_count == 0) begin
                    wait (spin_pop_handshake);
                end
                if (energy_handshake_count >= (spin_pop_handshake_count - 1)) begin: analog_cmpt_tbd
                    i = 0;
                    while (((spin_pop_handshake_count <= 1) || (!spin_pop_handshake)) && i < ANALOG_DELAY) begin: mimic_analog_delay
                        @(posedge clk_i);
                        i++;
                    end
                end
                repeat (ENERGY_MONITOR_LATENCY) @(posedge clk_i);
                if (RANDOM_TEST) begin
                    for (int i = 0; i < ENERGY_TOTAL_BIT; i++) begin
                        energy_i[i] = $urandom_range(0, 1);
                    end
                    for (int i = 0; i < NUM_SPIN; i++) begin
                        spin_i[i] = $urandom_range(0, 1);
                    end
                end else begin
                    energy_i = energy_i - 1; // decremental energy
                    spin_i = spin_i << 1; // toggle spin
                end
                #(0.1 * CLKCYCLE);
                energy_valid_i = 1;
                do @(posedge clk_i);
                while (!energy_ready_o);
                #(0.1 * CLKCYCLE);
                energy_valid_i = 0;
                energy_handshake_count++;
            end
        end
    endtask

    // Task for scoreboard check: spin flipping
    task automatic scoreboard_check_spin_flipping();
        begin
            while (!rst_ni) begin
                expected_flipped_spin = 'd0;
                @(posedge clk_i);
            end
            while (!configure_test_done | !en_i) @(posedge clk_i);
            while (spin_pop_handshake_count < icon_last_raddr_plus_one_i) begin
                while (!spin_pop_handshake) @(negedge clk_i);
                // compute expected flipped spin
                expected_flipped_spin = spin_fifo_scoreboard[spin_pop_handshake_count%SPIN_DEPTH];
                if (flip_disable_i) begin
                    // no flipping
                    expected_flipped_spin = expected_flipped_spin;
                end else begin
                    expected_flipped_spin = expected_flipped_spin ^ flip_rdata_i;
                end
                // check flipped spin
                if (spin_pop_o !== expected_flipped_spin) begin
                    $display("Error: Flipped spin mismatch at time %t: expected 'h%h, got 'h%h", $time, expected_flipped_spin, spin_pop_o);
                    @(negedge clk_i);
                    $finish;
                end
                @(negedge clk_i);
            end
            $display("----------- Scoreboard Check: spin flipping ----------");
            $display("-- Scoreboard check completed successfully ['d%0d/'d%0d]! --", spin_pop_handshake_count, icon_last_raddr_plus_one_i);
            $display("------------------------------------------------------");
        end
    endtask

    // Task for scoreboard check: spin FIFO content update
    task automatic scoreboard_check_spin_update();
        begin
            // Check if the fifo data matches the input values
            while (!rst_ni) begin
                energy_fifo_pointer = 0;
                spin_fifo_pointer = 0;
                for (int i = 0; i < SPIN_DEPTH; i++) begin
                    energy_fifo_scoreboard[i] = {1'b0, {(ENERGY_TOTAL_BIT-1){1'b1}}};
                    spin_fifo_scoreboard[i] = 'd0;
                end
                @(posedge clk_i);
            end
            while (!cmpt_en_i) @(negedge clk_i);
            while (energy_handshake_count < icon_last_raddr_plus_one_i) begin
                while (!energy_valid_i || !energy_ready_o) @(negedge clk_i);
                if (en_comparison_i & (energy_i < energy_fifo_scoreboard[energy_fifo_pointer])) begin
                    energy_fifo_scoreboard[energy_fifo_pointer] = energy_i;
                    spin_fifo_scoreboard[spin_fifo_pointer] = spin_i;
                end
                @(negedge clk_i);
                if (dut.u_energy_fifo_maintainer.energy_fifo.mem_q[energy_fifo_pointer] != energy_fifo_scoreboard[energy_fifo_pointer]) begin
                    $display("Error: Energy FIFO content mismatch at time %t: expected 'h%h, got 'h%h", $time, energy_fifo_scoreboard[energy_fifo_pointer], dut.u_energy_fifo_maintainer.energy_fifo.mem_q[energy_fifo_pointer]);
                    @(negedge clk_i);
                    $finish;
                end else begin
                    // $display("Pass: Energy FIFO content match at time %t: got 'h%h", $time, energy_fifo_scoreboard[energy_fifo_pointer]);
                end
                energy_fifo_pointer = (energy_fifo_pointer + 1);
                @(negedge clk_i);
                if (dut.u_spin_fifo_maintainer.spin_fifo.mem_q[spin_fifo_pointer] != spin_fifo_scoreboard[spin_fifo_pointer]) begin
                    $display("Error: Spin FIFO content mismatch at time %t: expected 'h%h, got 'h%h", $time, spin_fifo_scoreboard[spin_fifo_pointer], dut.u_spin_fifo_maintainer.spin_fifo.mem_q[spin_fifo_pointer]);
                    @(negedge clk_i);
                    $finish;
                end else begin
                    // $display("Pass: Spin FIFO content match at time %t: got 'h%h", $time, spin_fifo_scoreboard[spin_fifo_pointer]);
                end
                spin_fifo_pointer = (spin_fifo_pointer + 1);
            end
            $display("------------- Scoreboard Check: spin update -----------");
            $display("-- Scoreboard check completed successfully ['d%0d/'d%0d]! --", energy_handshake_count, icon_last_raddr_plus_one_i);
            $display("------------------------------------------------------");
        end
    endtask

    task automatic timer();
        begin
            integer cmpt_start_time, cmpt_end_time;
            integer cmpt_total_time, cmpt_total_cycles;
            integer cmpt_transaction_time, cmpt_transaction_cycles;
            cmpt_start_time = 0;
            cmpt_end_time = 0;
            cmpt_total_time = 0;
            cmpt_total_cycles = 0;
            cmpt_transaction_time = 0;
            cmpt_transaction_cycles = 0;
            wait (rst_ni == 1 && en_i == 1 && cmpt_en_i == 1);
            cmpt_start_time = $time;
            repeat (2) @(posedge clk_i);
            while (cmpt_idle_o == 0) @(posedge clk_i);
            cmpt_end_time = $time;
            cmpt_total_time = cmpt_end_time - cmpt_start_time;
            cmpt_total_cycles = cmpt_total_time / CLKCYCLE;
            cmpt_transaction_time = cmpt_total_time / icon_last_raddr_plus_one_i;
            cmpt_transaction_cycles = cmpt_total_cycles / icon_last_raddr_plus_one_i;
            $display("@@@@@@@@@@ Performance Check @@@@@@@@@@@");
            $display("Timer [Time %0d ns]: Computation start time: %0d ns, end time: %0d ns, duration: %0d ns, #transactions: %0d",
                $time, cmpt_start_time, cmpt_end_time, cmpt_total_time, icon_last_raddr_plus_one_i);
            $display("Timer [Time %0d ns]: Computation total cycles: %0d cc [%0d ns], Cycles/transaction: %0d cc [%0d ns]",
                $time, cmpt_total_cycles, cmpt_total_time, cmpt_transaction_cycles, cmpt_transaction_time);
            $display("In each transaction, analog macro takes %0d cc (%0d ns), energy monitor takes %0d cc (%0d ns).",
                ANALOG_DELAY, ANALOG_DELAY * CLKCYCLE, ENERGY_MONITOR_LATENCY, ENERGY_MONITOR_LATENCY * CLKCYCLE);
            $display("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
        end
    endtask

    // ========================================================================
    // Testbench task and timer setup
    // ========================================================================
    initial begin
        fork
            configure_spin();
            flip_icon_rdata_interface();
            flip_icon_interface();
            analog_rx_interface();
            host_interface();
            energy_handshake_counter();
            energy_monitor_interface();
            scoreboard_check_spin_flipping();
            scoreboard_check_spin_update();
            timer();
        join_none
    end

endmodule
