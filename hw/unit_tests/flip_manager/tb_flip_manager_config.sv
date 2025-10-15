// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Jiacong Sun <jiacong.sun@kuleuven.be>

`timescale 1ns / 1ps

`ifndef DBG
`define DBG 0
`endif

module tb_flip_manager;

    // Module parameters
    localparam int DATASPIN = 256; // number of spins
    localparam int ENERGY_TOTAL_BIT = 32; // bit width of total energy
    localparam int SPIN_DEPTH = 64; // depth of spin/energy FIFOs
    localparam int FLIP_ICON_DEPTH = 1024; // number of entries in flip
    localparam int PIPES = 0; // number of pipeline stages

    // Testbench parameters
    localparam int CLKCYCLE = 2;
    localparam int FLUSH_NUM_TESTS = 5; // number of flush tests

    // Testbench internal signals
    logic clk_i;
    logic rst_ni;
    logic en_i;
    logic flush_i;
    logic cmpt_en_i;
    logic debug_cmpt_stop_i;
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
    logic energy_valid_i;
    logic energy_ready_o;
    logic signed [ENERGY_TOTAL_BIT-1:0] energy_i, energy_configure_i;
    logic flip_ren_o;
    logic [$clog2(FLIP_ICON_DEPTH)-1:0] flip_raddr_o;
    logic [DATASPIN-1:0] flip_rdata_i;
    logic flip_disable_i;
    logic host_readout_i;

    logic configure_test_done;

    initial begin
        en_i = 0;
        flush_i = 0;
        cmpt_en_i = 0;
        debug_cmpt_stop_i = 0;
        host_readout_i = 0;
        spin_pop_ready_i = 0;
        spin_valid_i = 0;
        spin_i = '0;
        energy_valid_i = 0;
        energy_i = '0;
        flip_rdata_i = '0;
        flip_disable_i = 0;
    end

    // Module instantiation
    flip_manager #(
        .DATASPIN(DATASPIN),
        .SPIN_DEPTH(SPIN_DEPTH),
        .ENERGY_TOTAL_BIT(ENERGY_TOTAL_BIT),
        .FLIP_ICON_DEPTH(FLIP_ICON_DEPTH),
        .PIPES(PIPES)
    ) dut (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .en_i(en_i),
        .flush_i(flush_i),
        .cmpt_en_i(cmpt_en_i),
        .debug_cmpt_stop_i(debug_cmpt_stop_i),
        .cmpt_idle_o(cmpt_idle_o),
        .host_readout_i(host_readout_i),
        .spin_configure_valid_i(spin_configure_valid_i),
        .spin_configure_i(spin_configure_i),
        .energy_configure_i(energy_configure_i),
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
        .flip_rdata_i(flip_rdata_i),
        .flip_disable_i(flip_disable_i)
    );

    // Clock generation
    initial begin
        clk_i = 1;
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
            $dumpfile("tb_flip_manager.vcd");
            $dumpvars(5, tb_flip_manager);
            #(2000 * CLKCYCLE); // To avoid generating huge VCD files
            $display("Testbench timeout reached. Ending simulation.");
            $finish;
        end
        else begin
            #(1.5 * DATASPIN * FLUSH_NUM_TESTS * CLKCYCLE);
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
            integer configure_counter;
            integer flush_counter;
            integer rnd_delay;
            logic [DATASPIN-1:0] spin_configure_prev;

            configure_counter = 0;
            flush_counter = 0;
            configure_test_done = 0;

            while (!(rst_ni & en_i)) begin
                spin_configure_valid_i = 0;
                spin_configure_i = 'd0;
                spin_configure_prev = 'd0;
                spin_configure_push_none_i = 1'b0;
                @(posedge clk_i);
            end
            do begin
                while (configure_counter < SPIN_DEPTH) begin
                    @(posedge clk_i);
                    // send spin
                    spin_configure_valid_i = 1;
                    spin_configure_prev = spin_configure_i;
                    // generate random bitstring: each bit randomly 0 or 1
                    for (int i = 0; i < DATASPIN; i++) begin
                        spin_configure_i[i] = $urandom_range(0, 1);
                    end
                    // check FIFO content
                    if (configure_counter > 0) begin
                        if (dut.spin_fifo_maintainer_inst.spin_fifo.mem_n[configure_counter-1] !== spin_configure_prev) begin
                            $display("Error: FIFO content mismatch at time %t: expected %h, got %h", $time, spin_configure_prev, dut.spin_fifo_maintainer_inst.spin_fifo.mem_n[configure_counter-1]);
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

                // random cycle delay between 1 and 5 cycles
                rnd_delay = $urandom_range(1, 5);
                repeat (rnd_delay) @(posedge clk_i);
                flush_i = 1;
                @(posedge clk_i);
                flush_i = 0;
                flush_counter++;
                configure_counter = 0;
            end
            while(flush_counter < FLUSH_NUM_TESTS);
            configure_test_done = 1;
            @(posedge clk_i);
            $display("------------------------------------------------");
            $display("------ Spin configuration test completed -------");
            $display("------------------------------------------------");
            $finish;
        end
    endtask

    // ========================================================================
    // Testbench task and timer setup
    // ========================================================================
    initial begin
        fork
            configure_spin();
        join_none
    end

endmodule
