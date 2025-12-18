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

    // testbench parameters
    localparam int CLKCYCLE = 2;
    localparam int IterationNum = 150;

    // dut run-time configuration
    localparam int CyclePerDtWrite = 20;
    localparam int CyclePerSpinWrite = 10;
    localparam int CyclePerSpinCompute = 30;
    localparam int SynchronizerPipeNum = 2;
    localparam int SynchronizerMode = 0; // 0: one-shot; 1: continuous
    localparam int SpinWwlStrobe = {256{1'b1}}; // all spins enabled??
    localparam int SpinMode = {256{1'b1}}; // all spins in compute mode
    localparam int Flush = `False;
    localparam int EnComparison = `True;
    localparam int FlipDisable = `False;
    localparam int EmCfgCounter = 255;

    // dut compile-time configuration
    localparam int BitJ = 4;
    localparam int BitH = 4;
    localparam int NumSpin = 256;
    localparam int ScalingBit = 5;
    localparam int Parallelism = 4;
    localparam int LocalEnergyBit = 16;
    localparam int EnergyTotalBit = 32;
    localparam int LittleEndian = `False;
    localparam int PipesIntf = 1;
    localparam int PipesMid = 1;
    localparam int SpinDepth = 1; // unused in this testbench
    localparam int FlipIconDepth = 1024;
    localparam int CounterBitWidth = 16;
    localparam int SynchronizerPipeDepth = 3;

    // dut signals
    logic clk_i;
    logic rst_ni;
    logic en_i;
    logic config_valid_em_i, config_em_done;
    logic config_valid_fm_i, config_fm_done;
    logic config_valid_aw_i, config_aw_done;
    logic config_dut_done;
    logic [ $clog2(NumSpin)-1 : 0 ] config_counter_i;
    logic [ NumSpin-1 : 0 ] config_spin_initial_i;
    logic config_spin_initial_skip_i;
    logic [ CounterBitWidth-1 : 0] cfg_trans_num_i;
    logic [ CounterBitWidth-1 : 0] cycle_per_dt_write_i;
    logic [ CounterBitWidth-1 : 0] cycle_per_spin_write_i;
    logic [ CounterBitWidth-1 : 0] cycle_per_spin_compute_i;
    logic [ NumSpin-1 : 0 ] spin_wwl_strobe_i;
    logic [ NumSpin-1 : 0 ] spin_mode_i;
    logic [ $clog2(SynchronizerPipeDepth)-1 : 0 ] synchronizer_pipe_num_i;
    logic synchronizer_mode_i;
    logic dt_cfg_enable_i;
    logic j_mem_ren_o;
    logic [ $clog2(NumSpin / Parallelism)-1 : 0 ] j_raddr_o, weight_raddr_o;
    logic [ $clog2(NumSpin / Parallelism)-1 : 0 ] j_raddr_ref, weight_raddr_ref;
    logic [ NumSpin*BitJ*Parallelism-1 : 0 ] j_rdata_i, weight_i;
    logic [ NumSpin*BitJ*Parallelism-1 : 0 ] j_rdata_latched, weight_latched;
    logic h_ren_o;
    logic [ BitH*NumSpin-1 : 0 ] h_rdata_i;
    logic flush_i;
    logic en_comparison_i;
    logic cmpt_en_i;
    logic cmpt_idle_o;
    logic host_readout_i;
    logic flip_ren_o;
    logic [ $clog2(FlipIconDepth)+1-1 : 0 ] flip_raddr_o, flip_raddr_ref;
    logic [ $clog2(FlipIconDepth)+1-1 : 0 ] icon_last_raddr_plus_one_i;
    logic [ NumSpin-1 : 0 ] flip_rdata_i, flip_rdata_latched;
    logic flip_disable_i;
    logic weight_ren_o;
    logic [ BitH*NumSpin-1 : 0 ] hbias_i;
    logic [ ScalingBit-1 : 0 ] hscaling_i;
    logic [ NumSpin-1 : 0 ] j_one_hot_wwl_o;
    logic h_wwl_o;
    logic [NumSpin*BitJ-1 : 0 ] wbl_o;
    logic [ NumSpin-1 : 0 ] spin_wwl_o;
    logic [NumSpin-1 : 0 ] spin_compute_en_o;
    logic [ NumSpin-1 : 0 ] analog_spin_i;

    // testbench signals
    logic [NumSpin-1:0][NumSpin*BitJ-1:0] weights_in_mem, weights_analog;
    logic [NumSpin*BitH-1:0] hbias_in_reg, hbias_analog;
    logic [ScalingBit-1:0] hscaling_in_reg;
    int signed constant;
    logic [FlipIconDepth-1:0] [NumSpin-1:0] flip_icons_in_mem;
    logic [FlipIconDepth-1:0] [EnergyTotalBit-1:0] energy_ref;
    logic [FlipIconDepth-1+1:0] [NumSpin-1:0] state_in_analog_ref;
    logic [FlipIconDepth-1:0] [NumSpin-1:0] state_out_analog_ref;
    int unsigned total_cycles, transaction_cycles, total_time, transaction_time, start_time, end_time;

    initial begin
        en_i = 1;
    end

    // module instantiation
    digital_macro #(
        .bit_j(BitJ),
        .bit_h(BitH),
        .num_spin(NumSpin),
        .scaling_bit(ScalingBit),
        .parallelism(Parallelism),
        .energy_total_bit(EnergyTotalBit),
        .little_endian(LittleEndian),
        .pipesintf(PipesIntf),
        .pipesmid(PipesMid),
        .spin_depth(SpinDepth),
        .flip_icon_depth(FlipIconDepth),
        .counter_bitwidth(CounterBitWidth),
        .synchronizer_pipe_depth(SynchronizerPipeDepth)
    ) dut (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .en_i(en_i),
        .config_valid_em_i(config_valid_em_i),
        .config_valid_fm_i(config_valid_fm_i),
        .config_valid_aw_i(config_valid_aw_i),
        .config_counter_i(config_counter_i),
        .config_spin_initial_i(config_spin_initial_i),
        .config_spin_initial_skip_i(config_spin_initial_skip_i),
        .cfg_trans_num_i(cfg_trans_num_i),
        .cycle_per_dt_write_i(cycle_per_dt_write_i),
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
        .flush_i(flush_i),
        .en_comparison_i(en_comparison_i),
        .cmpt_en_i(cmpt_en_i),
        .cmpt_idle_o(cmpt_idle_o),
        .host_readout_i(host_readout_i),
        .flip_ren_o(flip_ren_o),
        .flip_raddr_o(flip_raddr_o),
        .icon_last_raddr_plus_one_i(icon_last_raddr_plus_one_i),
        .flip_rdata_i(flip_rdata_i),
        .flip_disable_i(flip_disable_i),
        .weight_ren_o(weight_ren_o),
        .weight_raddr_o(weight_raddr_o),
        .weight_i(weight_i),
        .hbias_i(hbias_i),
        .hscaling_i(hscaling_i),
        .j_one_hot_wwl_o(j_one_hot_wwl_o),
        .h_wwl_o(h_wwl_o),
        .wbl_o(wbl_o),
        .spin_wwl_o(spin_wwl_o),
        .spin_compute_en_o(spin_compute_en_o),
        .analog_spin_i(analog_spin_i)
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
            $dumpvars(4, tb_digital_macro); // Dump all variables in testbench module
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
    // Always blocks
    // ========================================================================
    // pipe j_rdata_i, weight_i, flip_rdata_i
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            j_rdata_i <= 'd0;
            weight_i <= 'd0;
            flip_rdata_i <= 'd0;
        end else begin
            j_rdata_i <= j_rdata_latched;
            weight_i <= weight_latched;
            flip_rdata_i <= flip_rdata_latched;
        end
    end

    // ========================================================================
    // Functions
    // ========================================================================
    // Function to parse a line (max length: NumSpin*BitJ) from the model file
    function automatic logic [NumSpin*BitJ-1:0] parse_bit_string(string line);
        // Large endian assumed for data layout
        logic [NumSpin*BitJ-1:0] result = 'd0;
        int bit_idx = 0;
        int i = 0;
        while (i < line.len() && bit_idx < NumSpin*BitJ) begin
            if (line[i] == "0" || line[i] == "1") begin
                result[NumSpin*BitJ-1-bit_idx] = $unsigned(line[i]);
                bit_idx = bit_idx + 1;
            end
            i = i + 1;
        end
        return result;
    endfunction

    // ========================================================================
    // Sub-tasks
    // ========================================================================
    // Sub-task to read weight model from file
    task automatic load_model();
        int model_file;
        string line;
        int line_num = 0;
        int weight_idx = 0;
        int hbias_idx = 0;
        real const_real;

        model_file = $fopen(`MODEL_FILE, "r");
        if (model_file == 0) begin
            $display("Error: Could not open model file %s", `MODEL_FILE);
            $finish;
        end

        // Read the file line by line
        while (!$feof(model_file)) begin
            line = "";
            if ($fgets(line, model_file) != 0) begin
                line_num = line_num + 1;
                // Skip comment lines and header lines
                if (line[0] == "#" || line[0] == "\n") begin
                    continue;
                end
                // Read weights into memory (1024 bits per line)
                if (line_num > 1 && line_num <= (1 + NumSpin)) begin
                    weights_in_mem[weight_idx] = parse_bit_string(line);
                    weight_idx = weight_idx + 1;
                end
                // Read hbias (4 bits per line)
                else if (line_num > (1 + NumSpin) && line_num <= (2 + 2*NumSpin)) begin
                    hbias_in_reg[hbias_idx +: BitH] = parse_bit_string(line)[NumSpin*BitJ-1 -: BitH];
                    hbias_idx = hbias_idx + BitH;
                end
                // Read constant as a signed integer
                else if (line_num > (2 + 2*NumSpin)) begin
                    if ($sscanf(line, "%f", const_real) != 1) begin
                        $display("Error: Failed to parse constant from model file");
                        $finish;
                    end
                    constant = $rtoi(const_real);
                    break;
                end
            end
        end
        $fclose(model_file);
        hscaling_in_reg = 1; // fixed to 1 based on the algorithm
        $display("[Time: %t] Model file %s is loaded successfully.", $time, `MODEL_FILE);
    endtask

    // Sub-task to read flip icons from file
    task automatic load_flip_icons();
        int icon_file;
        string line;
        int line_num = 0;
        int icon_idx = 0;

        icon_file = $fopen(`FLIP_ICON_FILE, "r");
        if (icon_file == 0) begin
            $display("Error: Could not open cluster file %s", `FLIP_ICON_FILE);
            $finish;
        end

        // Read the file line by line
        while (!$feof(icon_file)) begin
            line = "";
            if ($fgets(line, icon_file) != 0) begin
                line_num = line_num + 1;
                // Skip comment lines and header lines
                if (line[0] == "#" || line[0] == "\n") begin
                    continue;
                end
                flip_icons_in_mem[icon_idx] = parse_bit_string(line)[NumSpin*BitJ-1 -: NumSpin];
                icon_idx = icon_idx + 1;
            end
        end
        $fclose(icon_file);
        $display("[Time: %t] Flip icon file %s is loaded successfully.", $time, `FLIP_ICON_FILE);
    endtask

    // Sub-task to read energy reference from file
    task automatic load_energy_reference();
        int energy_file;
        string line;
        int line_num = 0;
        int energy_idx = 0;

        energy_file = $fopen(`ENERGY_REF_FILE, "r");
        if (energy_file == 0) begin
            $display("Error: Could not open energy reference file %s", `ENERGY_REF_FILE);
            $finish;
        end

        // Read the file line by line
        while (!$feof(energy_file)) begin
            line = "";
            if ($fgets(line, energy_file) != 0) begin
                line_num = line_num + 1;
                // Skip comment lines and header lines
                if (line[0] == "#" || line[0] == "\n") begin
                    continue;
                end
                // Skip the first line as it is not a valid icon
                if (line_num == 1) begin
                    continue;
                end
                energy_ref[energy_idx] = parse_bit_string(line)[NumSpin*BitJ-1 -: EnergyTotalBit];
                energy_idx = energy_idx + 1;
            end
        end
        $fclose(energy_file);
        $display("[Time: %t] Energy reference file %s is loaded successfully.", $time, `ENERGY_REF_FILE);
    endtask

    // Sub-task to read state in analog (without flips applied) from file
    task automatic load_state_in_analog();
        int state_in_file;
        string line;
        int line_num = 0;
        int state_in_idx = 0;

        state_in_file = $fopen(`STATE_IN_FILE, "r");
        if (state_in_file == 0) begin
            $display("Error: Could not open state in file %s", `STATE_IN_FILE);
            $finish;
        end

        // Read the file line by line
        while (!$feof(state_in_file)) begin
            line = "";
            if ($fgets(line, state_in_file) != 0) begin
                line_num = line_num + 1;
                // Skip comment lines and header lines
                if (line[0] == "#" || line[0] == "\n") begin
                    continue;
                end
                state_out_analog_ref[state_in_idx] = parse_bit_string(line)[NumSpin*BitJ-1 -: NumSpin];
                state_in_idx = state_in_idx + 1;
            end
        end
        $fclose(state_in_file);
        $display("[Time: %t] State in file %s is loaded successfully.", $time, `STATE_IN_FILE);
    endtask

    // Sub-task to read state out analog from file
    task automatic load_state_out_analog();
        int state_out_file;
        string line;
        int line_num = 0;
        int state_out_idx = 0;

        state_out_file = $fopen(`STATE_OUT_FILE, "r");
        if (state_out_file == 0) begin
            $display("Error: Could not open state out file %s", `STATE_OUT_FILE);
            $finish;
        end

        // Read the file line by line
        while (!$feof(state_out_file)) begin
            line = "";
            if ($fgets(line, state_out_file) != 0) begin
                line_num = line_num + 1;
                // Skip comment lines and header lines
                if (line[0] == "#" || line[0] == "\n") begin
                    continue;
                end
                // Skip the first line as it is not a valid out
                if (line_num == 1) begin
                    continue;
                end
                state_out_analog_ref[state_out_idx] = parse_bit_string(line)[NumSpin*BitJ-1 -: NumSpin];
                state_out_idx = state_out_idx + 1;
            end
        end
        $fclose(state_out_file);
        $display("[Time: %t] State out file %s is loaded successfully.", $time, `STATE_OUT_FILE);
    endtask

    // Sub-task for analog galena interface: config data check
    task automatic analog_interface_config_check();
        integer galena_addr_idx;
        integer dt_write_cycle_cnt;
        galena_addr_idx = 0;
        dt_write_cycle_cnt = 0;
        wait (rst_ni == 1 && en_i == 1 && dt_cfg_enable_i == 1);
        @(negedge clk_i);
        // check if j and h are loaded correctly
        while (galena_addr_idx < (NumSpin + 1)) begin
            while (dt_write_cycle_cnt < cycle_per_dt_write_i) begin
                @(negedge clk_i);
                // monitor if j_one_hot_wwl_o remains valid for the dedefined cycles
                if (j_one_hot_wwl_o == 0 && dt_write_cycle_cnt != 0) begin
                    $fatal(1, "[Time: %t] Warning: j_one_hot_wwl_o switches to zero during dt write cycle %0d for galena_addr_idx %0d",
                        $time, dt_write_cycle_cnt, galena_addr_idx);
                end
                if (|j_one_hot_wwl_o) begin
                    // check if one-hot encoded and matches galena_addr_idx
                    if ($countbits(j_one_hot_wwl_o, '1) != 1)
                        $fatal(1, "[Time: %t] Error: j_one_hot_wwl_o is not one-hot encoded", $time);
                    if (j_one_hot_wwl_o[1'b1<<galena_addr_idx] != 1'b1) begin
                        $fatal(1, "[Time: %t] Error: j_one_hot_wwl_o does not match galena_addr_idx %0d", $time, galena_addr_idx);
                    end
                    dt_write_cycle_cnt = dt_write_cycle_cnt + 1;
                end
                if (galena_addr_idx == (NumSpin)) begin: load_hbias
                    if (dt_write_cycle_cnt == (cycle_per_dt_write_i - 1))
                        hbias_analog = wbl_o;
                    // compare data to reference
                    if (hbias_analog != hbias_in_reg) begin
                        $fatal(1, "[Time: %t] Error: Hbias mismatch. Expected: 'h%h, Got: 'h%h",
                            $time, hbias_in_reg, hbias_analog);
                    end
                end else begin: load_j
                    if (dt_write_cycle_cnt == (cycle_per_dt_write_i - 1))
                        weights_analog[galena_addr_idx] = wbl_o;
                    // compare data to reference
                    if (weights_analog[galena_addr_idx] != weights_in_mem[galena_addr_idx]) begin
                        $fatal(1, "[Time: %t] Error: Weights mismatch at galena_addr_idx %0d. Expected: 'h%h, Got: 'h%h",
                            $time, galena_addr_idx, weights_in_mem[galena_addr_idx], weights_analog[galena_addr_idx]);
                    end
                end
            end
            dt_write_cycle_cnt = 0;
            galena_addr_idx = galena_addr_idx + 1;
        end
    endtask

    // Sub-task for AW config interface
    task automatic aw_config_interface();
        wait (rst_ni == 0);
        @(negedge clk_i);
        config_aw_done = 0;
        config_valid_aw_i = 0;
        cfg_trans_num_i = 'd0;
        cycle_per_dt_write_i = 'd0;
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
        config_valid_aw_i = 1;
        cfg_trans_num_i = NumSpin-1;
        cycle_per_dt_write_i = CyclePerDtWrite;
        cycle_per_spin_write_i = CyclePerSpinWrite;
        cycle_per_spin_compute_i = CyclePerSpinCompute;
        synchronizer_pipe_num_i = SynchronizerPipeNum;;
        synchronizer_mode_i = SynchronizerMode;
        spin_wwl_strobe_i = SpinWwlStrobe;
        spin_mode_i = SpinMode;
        @(negedge clk_i);
        config_valid_aw_i = 0;
        config_aw_done = 1;
        $display("[Time: %t] AW configuration finished.", $time);
    endtask

    // Sub-task for EM config interface
    task automatic em_config_interface();
        wait (rst_ni == 0);
        @(negedge clk_i);
        config_em_done = 0;
        config_valid_em_i = 0;
        config_counter_i = 'd0;
        wait (rst_ni == 1 && en_i == 1 && config_aw_done == 1);
        @(negedge clk_i);
        $display("[Time: %t] EM configuration starts.", $time);
        config_valid_em_i = 1;
        config_counter_i = EmCfgCounter;;
        @(negedge clk_i);
        config_valid_em_i = 0;
        config_em_done = 1;
        $display("[Time: %t] EM configuration finished.", $time);
    endtask

    // Sub-task for FM config interface
    task automatic fm_config_interface();
        wait (rst_ni == 0);
        @(negedge clk_i);
        config_fm_done = 0;
        config_valid_fm_i = 0;
        config_spin_initial_i = 'd0;
        config_spin_initial_skip_i = `False;
        flush_i = Flush;
        en_comparison_i = EnComparison;
        icon_last_raddr_plus_one_i = IterationNum;
        flip_disable_i = FlipDisable;
        wait (rst_ni == 1 && en_i == 1 && config_em_done == 1);
        @(negedge clk_i);
        $display("[Time: %t] FM configuration starts.", $time);
        config_valid_fm_i = 1;
        config_spin_initial_i = state_out_analog_ref[0];
        config_spin_initial_skip_i = `False;
        @(negedge clk_i);
        config_valid_fm_i = 0;
        config_fm_done = 1;
        $display("[Time: %t] FM configuration finished.", $time);
    endtask

    // Sub-task for monitoring config done
    task automatic monitor_config_done();
        wait (rst_ni == 0);
        @(negedge clk_i);
        config_dut_done = 0;
        wait (config_aw_done == 1 && config_em_done == 1 && config_fm_done == 1);
        @(negedge clk_i);
        config_dut_done = 1;
        $display("[Time: %t] DUT configuration is done.", $time);
    endtask

    // ========================================================================
    // Tasks
    // ========================================================================
    // Task to load all data references
    task automatic data_ref_loading();
        load_model();
        load_flip_icons();
        load_energy_reference();
        load_state_in_analog();
        load_state_out_analog();
    endtask

    // Analog galena interface: compute
    task automatic analog_interface_cmpt();
        integer iteration_cnt, cycle_analog_cnt;
        iteration_cnt = 0;
        wait (rst_ni == 1 && en_i == 1);
        @(negedge clk_i);
        while (iteration_cnt < IterationNum) begin
            wait (|spin_wwl_o); // wait for any spin wwl
            cycle_analog_cnt = 0;
            while (cycle_analog_cnt < cycle_per_spin_compute_i) begin
                @(negedge clk_i);
                cycle_analog_cnt = cycle_analog_cnt + 1;
            end
            // Provide analog spin output
            analog_spin_i = state_out_analog_ref[iteration_cnt];
            iteration_cnt = iteration_cnt + 1;
        end
    endtask

    // Pre-compute configuration
    task automatic pre_compute_config();
        fork
            analog_interface_config_check(); // check if j and h wwl are corretly generated
            aw_config_interface(); // configure aw module
            em_config_interface(); // configure em module
            fm_config_interface(); // configure fm module
            monitor_config_done(); // monitor if dut config is done
        join_none
    endtask

    // J mem interface
    task automatic j_mem_interface();
        wait (rst_ni == 0);
        @(negedge clk_i);
        j_rdata_latched = 'd0;
        weight_latched = 'd0;
        j_raddr_ref = 'd0;
        weight_raddr_ref = 'd0;
        wait (rst_ni == 1 && en_i == 1 && config_dut_done == 1);
        forever begin
            @(negedge clk_i);
            if (j_mem_ren_o == 1) begin
                if (j_raddr_o != j_raddr_ref) begin
                    $fatal(1, "[Time: %t] Error: J memory read address mismatch. Expected: %0d, Got: %0d",
                        $time, j_raddr_ref, j_raddr_o);
                end
                j_rdata_latched = weights_in_mem[j_raddr_o];
                j_raddr_ref = j_raddr_ref + 1;
            end
            if (weight_ren_o == 1) begin
                if (weight_raddr_o != weight_raddr_ref) begin
                    $fatal(1, "[Time: %t] Error: Weight memory read address mismatch. Expected: %0d, Got: %0d",
                        $time, weight_raddr_ref, weight_raddr_o);
                end
                weight_latched = weights_in_mem[weight_raddr_o];
                weight_raddr_ref = weight_raddr_ref + 1;
            end
        end
    endtask

    // H and scaling factor reg interface
    task automatic h_sfc_reg_interface();
        h_rdata_i = hbias_in_reg;
        hbias_i = hbias_in_reg;
        hscaling_i = hscaling_in_reg;
    endtask

    // Flip icon memory interface
    task automatic flip_mem_interface();
        wait (rst_ni == 0);
        flip_rdata_latched = 'd0;
        flip_raddr_ref = 'd0;
        wait (rst_ni == 1 && en_i == 1 && config_dut_done == 1);
        forever begin
            @(negedge clk_i);
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

    // Cmpt enable and timer
    task automatic cmpt_enable_and_timer();
        wait (rst_ni == 0);
        total_cycles = 0;
        transaction_cycles = 0;
        total_time = 0;
        transaction_time = 0;
        start_time = 0;
        end_time = 0;
        cmpt_en_i = 0;
        wait (rst_ni == 1 && en_i == 1 && config_dut_done == 1);

        // start compute
        @(negedge clk_i);
        cmpt_en_i = 1;
        start_time = $time;
        @(negedge clk_i);
        cmpt_en_i = 0;

        wait (cmpt_idle_o == 0);
        @(negedge clk_i);
        // calculate compute cycles
        end_time = $time;
        total_time = end_time - start_time;
        total_cycles = total_time / CLKCYCLE;
        transaction_cycles = total_cycles / IterationNum;
        transaction_time = transaction_cycles * CLKCYCLE;
        $display("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
        $display("Timer [Time %0d ns]: start time: %0d ns, end time: %0d ns, duration: %0d ns, transactions: %0d",
            $time, start_time, end_time, total_time, IterationNum);
        $display("Timer [Time %0d ns]: Total cycles: %0d cc [%0d ns], Cycles/transaction: %0d cc [%0d ns]",
            $time, total_cycles, total_time, transaction_cycles, transaction_time);
        $display("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
    endtask

    // ========================================================================
    // Event execution
    // ========================================================================
    initial begin
        fork
            data_ref_loading(); // load algorithm model/spin/flip/reference energy into memory
            pre_compute_config(); // configure aw, em, fm modules
            analog_interface_cmpt(); // mimic galena, provide analog spin output by analog_spin_i
            j_mem_interface(); // mimic j memory interface
            h_sfc_reg_interface(); // mimic h and scaling factor register interface
            flip_mem_interface(); // mimic flip icon memory interface
            cmpt_enable_and_timer(); // enable compute and measure time
        join_none
    end

endmodule
