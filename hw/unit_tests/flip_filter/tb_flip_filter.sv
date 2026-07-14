// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Jiacong Sun <jiacong.sun@kuleuven.be>

`timescale 1ns / 1ps

`ifndef DBG
`define DBG 0
`endif

`ifndef VCD_FILE
`define VCD_FILE "tb_flip_filter.vcd"
`endif

module tb_flip_filter;

    // ========================================================================
    // Module parameters
    // ========================================================================
    localparam int unsigned NUM_SPIN         = 256; // number of spins
    localparam int unsigned ENERGY_TOTAL_BIT = 32;  // bit width of baseline energy
    localparam int unsigned PARALLELISM      = 4;   // spins processed per block/address
    localparam int unsigned SPIN_DEPTH       = 2;   // number of stored baselines
    localparam int          LITTLE_ENDIAN    = 0;   // 0: MSB-first addressing, 1: LSB-first
    localparam int unsigned PIPESINTF        = 0;   // interface pipeline stages
    localparam int unsigned PIPES_IN_ARBITER = 0;   // arbiter pipeline stages
    // Derived parameters
    localparam int unsigned NUM_BLOCK  = NUM_SPIN / PARALLELISM;
    localparam int unsigned ADDR_WIDTH = $clog2(NUM_BLOCK);
    localparam int unsigned IDX_W      = (SPIN_DEPTH > 1) ? $clog2(SPIN_DEPTH) : 1;

    // ========================================================================
    // Testbench parameters
    // ========================================================================
    localparam int CLKCYCLE            = 2;  // clock period (ns)
    localparam bit RANDOM_TEST         = 1;  // 1: random stimulus, 0: fixed patterns
    localparam bit RADDR_BACKPRESSURE  = 1;  // 1: apply random backpressure on the raddr channel
    localparam int NUM_WARMUP_TESTS    = 6;  // transactions to reach curr_baseline_valid == 1
    localparam int NUM_RANDOM_TESTS    = 40; // main randomized transactions
    localparam int NUM_EMPTY_TESTS     = 4;  // transactions where upstream == baseline (empty case)

    // ========================================================================
    // DUT ports
    // ========================================================================
    logic                                        clk_i;
    logic                                        rst_ni;
    logic                                        en_i;
    logic                                        enable_flip_detection_i;
    logic                                        flush_i;
    logic [ADDR_WIDTH-1:0]                        raddr_upper_bound_i;

    logic [SPIN_DEPTH-1:0][ENERGY_TOTAL_BIT-1:0] energy_baseline_i;
    logic [SPIN_DEPTH-1:0][NUM_SPIN-1:0]         spin_baseline_i;
    logic                                        curr_baseline_valid_o;

    logic                                        spin_upstream_valid_i;
    logic                                        spin_upstream_ready_o;
    logic [NUM_SPIN-1:0]                          spin_upstream_i;

    logic                                        spin_downstream_valid_o;
    logic                                        spin_downstream_ready_i;
    logic [NUM_SPIN-1:0]                          spin_downstream_o;

    logic                                        raddr_valid_o;
    logic                                        raddr_ready_i;
    logic [ADDR_WIDTH-1:0]                        raddr_o;
    logic [PARALLELISM-1:0]                       block_bits_flipped_o;
    logic                                        raddr_last_one_o;

    logic [ENERGY_TOTAL_BIT-1:0]                 energy_baseline_o;
    logic [NUM_SPIN-1:0]                          spin_baseline_o;
    logic [NUM_SPIN-1:0]                          bits_unflipped_o;
    logic                                        empty_o;

    // ========================================================================
    // Scoreboard / bookkeeping
    // ========================================================================
    integer test_count;
    integer error_count;
    integer addr_error_count;

    // per-transaction expected values (captured at the upstream handshake)
    logic [IDX_W-1:0]     cap_baseline_idx;
    logic                 cap_baseline_valid;
    logic [NUM_SPIN-1:0]  exp_bits_flipped;   // baseline ^ upstream (or all ones)
    logic                 exp_empty;
    logic [NUM_BLOCK-1:0] exp_block_nz;       // 1 per block that must produce an address
    integer               exp_num_addr;

    // drain-time coverage
    logic [NUM_BLOCK-1:0] seen_block_mask;
    integer               seen_addr_count;

    // ========================================================================
    // DUT instantiation
    // ========================================================================
    flip_filter #(
        .NUM_SPIN         (NUM_SPIN),
        .ENERGY_TOTAL_BIT (ENERGY_TOTAL_BIT),
        .PARALLELISM      (PARALLELISM),
        .SPIN_DEPTH       (SPIN_DEPTH),
        .LITTLE_ENDIAN    (LITTLE_ENDIAN),
        .PIPESINTF        (PIPESINTF),
        .PIPES_IN_ARBITER (PIPES_IN_ARBITER)
    ) dut (
        .clk_i                   (clk_i),
        .rst_ni                  (rst_ni),
        .en_i                    (en_i),
        .enable_flip_detection_i (enable_flip_detection_i),
        .flush_i                 (flush_i),
        .raddr_upper_bound_i     (raddr_upper_bound_i),
        .energy_baseline_i       (energy_baseline_i),
        .spin_baseline_i         (spin_baseline_i),
        .curr_baseline_valid_o   (curr_baseline_valid_o),
        .spin_upstream_valid_i   (spin_upstream_valid_i),
        .spin_upstream_ready_o   (spin_upstream_ready_o),
        .spin_upstream_i         (spin_upstream_i),
        .spin_downstream_valid_o (spin_downstream_valid_o),
        .spin_downstream_ready_i (spin_downstream_ready_i),
        .spin_downstream_o       (spin_downstream_o),
        .raddr_valid_o           (raddr_valid_o),
        .raddr_ready_i           (raddr_ready_i),
        .raddr_o                 (raddr_o),
        .block_bits_flipped_o    (block_bits_flipped_o),
        .raddr_last_one_o        (raddr_last_one_o),
        .energy_baseline_o       (energy_baseline_o),
        .spin_baseline_o         (spin_baseline_o),
        .bits_unflipped_o        (bits_unflipped_o),
        .empty_o                 (empty_o)
    );

    // ========================================================================
    // Clock and reset generation
    // ========================================================================
    initial begin
        clk_i = 0;
        forever #(CLKCYCLE/2) clk_i = ~clk_i;
    end

    initial begin
        rst_ni = 0;
        #(5 * CLKCYCLE);
        rst_ni = 1;
    end

    // ========================================================================
    // Static input setup
    // ========================================================================
    initial begin
        en_i                    = 1'b1;
        enable_flip_detection_i = 1'b1;
        flush_i                 = 1'b0;
        raddr_upper_bound_i     = NUM_BLOCK - 1;         // no capping of the address stream
        spin_upstream_valid_i   = 1'b0;
        spin_upstream_i         = '0;
        spin_downstream_ready_i = 1'b1;                  // always accept passthrough spins
        raddr_ready_i           = 1'b1;
        energy_baseline_i       = '0;
        spin_baseline_i         = '0;
    end

    // ========================================================================
    // Simulation timeout / dump control
    // ========================================================================
    initial begin
        $timeformat(-9, 1, " ns", 9);
        if (`DBG) begin
            $display("Debug mode enabled. Dumping waveforms to %s.", `VCD_FILE);
            $dumpfile(`VCD_FILE);
            $dumpvars(0, tb_flip_filter);
        end
        #(50_000 * CLKCYCLE);
        $display("Error: Testbench timeout reached before completion.");
        $finish;
    end

    // ========================================================================
    // Helper: randomize an NUM_SPIN-wide vector
    // ========================================================================
    function automatic logic [NUM_SPIN-1:0] rand_spin();
        logic [NUM_SPIN-1:0] v;
        for (int i = 0; i < NUM_SPIN; i++) begin
            v[i] = $urandom_range(0, 1);
        end
        return v;
    endfunction

    // ========================================================================
    // Generate stimulus for one transaction
    //   mode 0: random / fixed non-empty stimulus
    //   mode 1: force empty (all baselines == upstream -> XOR is zero)
    // ========================================================================
    task automatic gen_stimulus(input int mode, input int idx);
        logic [NUM_SPIN-1:0] up;
        begin
            if (RANDOM_TEST) begin
                up = rand_spin();
                for (int d = 0; d < SPIN_DEPTH; d++) begin
                    spin_baseline_i[d]   = rand_spin();
                    energy_baseline_i[d] = $urandom;
                end
            end else begin
                // deterministic pattern: walking window of set bits, distinct per baseline slice
                up = '0;
                for (int i = 0; i < NUM_SPIN; i++) begin
                    up[i] = ((i + idx) % 5 == 0);
                end
                for (int d = 0; d < SPIN_DEPTH; d++) begin
                    spin_baseline_i[d]   = {NUM_SPIN{1'b0}} | (d * 17 + idx);
                    energy_baseline_i[d] = (d + 1) * 32'h1000_0000 + idx;
                end
            end

            if (mode == 1) begin
                // all baselines identical to upstream -> selected XOR is 0 regardless of index
                for (int d = 0; d < SPIN_DEPTH; d++) begin
                    spin_baseline_i[d] = up;
                end
            end

            spin_upstream_i = up;
        end
    endtask

    // ========================================================================
    // Drive a single upstream transaction and self-check the outputs
    // ========================================================================
    task automatic run_transaction();
        int guard;
        logic [ADDR_WIDTH-1:0] blk;
        begin
            // present the request; ready is independent of valid, so this is safe
            spin_upstream_valid_i = 1'b1;

            // Wait for the handshake CYCLE. spin_upstream_ready_o = !busy & downstream_ready
            // holds for the whole cycle and drops (busy_reg registers) right after the
            // latching posedge, so we must sample on the negedge, mid handshake-cycle,
            // where every combinational output is still valid.
            do @(negedge clk_i);
            while (!spin_upstream_ready_o);

            // ---- capture the expected result during the handshake cycle ----
            cap_baseline_idx   = dut.baseline_idx;
            cap_baseline_valid = curr_baseline_valid_o;
            if (cap_baseline_valid && enable_flip_detection_i) begin
                exp_bits_flipped = spin_baseline_i[cap_baseline_idx] ^ spin_upstream_i;
            end else begin
                exp_bits_flipped = {NUM_SPIN{1'b1}};
            end
            exp_empty    = ~(|exp_bits_flipped);
            exp_num_addr = 0;
            for (int b = 0; b < NUM_BLOCK; b++) begin
                exp_block_nz[b] = |exp_bits_flipped[b*PARALLELISM +: PARALLELISM];
                if (exp_block_nz[b]) exp_num_addr++;
            end

            // ---- check combinational outputs during the handshake cycle ----
            // empty flag
            if (empty_o !== exp_empty) begin
                $display("Error [test %0d @ %t]: empty_o mismatch: expected %b, got %b",
                         test_count, $time, exp_empty, empty_o);
                error_count++;
            end
            // selected baseline outputs
            if (spin_baseline_o !== spin_baseline_i[cap_baseline_idx]) begin
                $display("Error [test %0d @ %t]: spin_baseline_o mismatch: expected 'h%h, got 'h%h",
                         test_count, $time, spin_baseline_i[cap_baseline_idx], spin_baseline_o);
                error_count++;
            end
            if (energy_baseline_o !== energy_baseline_i[cap_baseline_idx]) begin
                $display("Error [test %0d @ %t]: energy_baseline_o mismatch: expected 'h%h, got 'h%h",
                         test_count, $time, energy_baseline_i[cap_baseline_idx], energy_baseline_o);
                error_count++;
            end
            // downstream passthrough (only valid together with a non-empty transaction)
            if (!exp_empty) begin
                if (spin_downstream_valid_o !== 1'b1) begin
                    $display("Error [test %0d @ %t]: spin_downstream_valid_o expected 1, got %b",
                             test_count, $time, spin_downstream_valid_o);
                    error_count++;
                end
                if (spin_downstream_o !== spin_upstream_i) begin
                    $display("Error [test %0d @ %t]: spin_downstream_o passthrough mismatch: expected 'h%h, got 'h%h",
                             test_count, $time, spin_upstream_i, spin_downstream_o);
                    error_count++;
                end
            end else begin
                if (spin_downstream_valid_o !== 1'b0) begin
                    $display("Error [test %0d @ %t]: spin_downstream_valid_o expected 0 on empty transaction, got %b",
                             test_count, $time, spin_downstream_valid_o);
                    error_count++;
                end
                // an empty transaction produces no address and reports last-one immediately
                if (raddr_valid_o !== 1'b0) begin
                    $display("Error [test %0d @ %t]: raddr_valid_o expected 0 on empty transaction, got %b",
                             test_count, $time, raddr_valid_o);
                    error_count++;
                end
                if (raddr_last_one_o !== 1'b1) begin
                    $display("Error [test %0d @ %t]: raddr_last_one_o expected 1 on empty transaction, got %b",
                             test_count, $time, raddr_last_one_o);
                    error_count++;
                end
            end

            // latch the upstream handshake, then drop valid (one transaction at a time)
            @(posedge clk_i);
            spin_upstream_valid_i = 1'b0;

            // ---- drain and check the read-address stream ----
            // For a non-empty transaction busy_reg is now set and raddr_valid_o holds
            // high (independent of ready) for the whole drain, one block per handshake.
            seen_block_mask = '0;
            seen_addr_count = 0;

            if (!exp_empty) begin
                guard = 0;
                forever begin
                    // drive backpressure for the upcoming cycle; keep it stable across the edge
                    raddr_ready_i = RADDR_BACKPRESSURE ? $urandom_range(0, 1) : 1'b1;
                    @(negedge clk_i);

                    if (raddr_valid_o && raddr_ready_i) begin
                        // logical block index that this physical address refers to
                        blk = LITTLE_ENDIAN ? raddr_o : (NUM_BLOCK - 1 - raddr_o);

                        if (!exp_block_nz[blk]) begin
                            $display("Error [test %0d @ %t]: unexpected address 'd%0d (block 'd%0d) has no flipped bits",
                                     test_count, $time, raddr_o, blk);
                            addr_error_count++;
                        end else if (seen_block_mask[blk]) begin
                            $display("Error [test %0d @ %t]: duplicate address 'd%0d (block 'd%0d)",
                                     test_count, $time, raddr_o, blk);
                            addr_error_count++;
                        end

                        if (block_bits_flipped_o !== exp_bits_flipped[blk*PARALLELISM +: PARALLELISM]) begin
                            $display("Error [test %0d @ %t]: block_bits_flipped_o mismatch @ block 'd%0d: expected 'b%b, got 'b%b",
                                     test_count, $time, blk,
                                     exp_bits_flipped[blk*PARALLELISM +: PARALLELISM], block_bits_flipped_o);
                            addr_error_count++;
                        end

                        seen_block_mask[blk] = 1'b1;
                        seen_addr_count++;

                        if (raddr_last_one_o) begin
                            @(posedge clk_i);       // consume the last address
                            raddr_ready_i = 1'b1;
                            break;
                        end
                    end

                    @(posedge clk_i);               // consume (advance a cycle)

                    guard++;
                    if (guard > 8 * NUM_BLOCK) begin
                        $display("Error [test %0d @ %t]: address drain did not terminate (got %0d/%0d)",
                                 test_count, $time, seen_addr_count, exp_num_addr);
                        error_count++;
                        break;
                    end
                end

                // ---- confirm full and exact coverage of the flipped blocks ----
                if (seen_addr_count !== exp_num_addr) begin
                    $display("Error [test %0d @ %t]: address count mismatch: expected %0d, got %0d",
                             test_count, $time, exp_num_addr, seen_addr_count);
                    error_count++;
                end
                if (seen_block_mask !== exp_block_nz) begin
                    $display("Error [test %0d @ %t]: address coverage mismatch: expected 'h%h, got 'h%h",
                             test_count, $time, exp_block_nz, seen_block_mask);
                    error_count++;
                end
            end
        end
    endtask

    // ========================================================================
    // Main test sequence
    // ========================================================================
    initial begin
        test_count       = 0;
        error_count      = 0;
        addr_error_count = 0;

        // wait for reset release
        wait (rst_ni == 1'b1);
        @(posedge clk_i);
        @(posedge clk_i);

        // warmup: bring curr_baseline_valid high (each transaction advances the
        // baseline validity counter). These are checked as well.
        for (int t = 0; t < NUM_WARMUP_TESTS; t++) begin
            gen_stimulus(0, t);
            run_transaction();
            test_count++;
        end

        // main randomized transactions
        for (int t = 0; t < NUM_RANDOM_TESTS; t++) begin
            gen_stimulus(0, 100 + t);
            run_transaction();
            test_count++;
        end

        // empty-case transactions (upstream matches baseline)
        for (int t = 0; t < NUM_EMPTY_TESTS; t++) begin
            gen_stimulus(1, 500 + t);
            run_transaction();
            test_count++;
        end

        @(posedge clk_i);
        $display("=================================================================");
        $display("Flip filter testbench finished: %0d transactions run.", test_count);
        $display("  Interface/scoreboard errors : %0d", error_count);
        $display("  Address-stream errors        : %0d", addr_error_count);
        if (error_count == 0 && addr_error_count == 0) begin
            $display("  RESULT: PASS -- all checks passed.");
        end else begin
            $display("  RESULT: FAIL -- %0d error(s) detected.", error_count + addr_error_count);
        end
        $display("=================================================================");
        $finish;
    end

endmodule
