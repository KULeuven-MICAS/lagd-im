// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Jiacong Sun <jiacong.sun@kuleuven.be>

`timescale 1ns / 1ps

`ifndef DBG
`define DBG 0
`endif

`ifndef VCD_FILE
`define VCD_FILE "tb_ising_core_wrap.vcd"
`endif

`ifndef MODEL_FILE
`define MODEL_FILE "../digital_macro/data/model_1"
`endif

`ifndef FLIP_ICON_FILE_1
`define FLIP_ICON_FILE_1 "../digital_macro/data/clusters_1"
`endif

`ifndef FLIP_ICON_FILE_2
`define FLIP_ICON_FILE_2 "../digital_macro/data/clusters_2"
`endif

`ifndef STATE_IN_FILE_1
`define STATE_IN_FILE_1 "../digital_macro/data/states_in_1"
`endif

`ifndef STATE_IN_FILE_2
`define STATE_IN_FILE_2 "../digital_macro/data/states_in_2"
`endif

// Project-wide includes
`include "lagd_config.svh"
`include "lagd_define.svh"
`include "lagd_platform.svh"
`include "lagd_typedef.svh"

module tb_ising_core_wrap;
    import lagd_mem_cfg_pkg::*;
    import ising_logic_pkg::*;
    import lagd_pkg::*;
    import lagd_core_reg_pkg::*;

    localparam int CLKCYCLE = 2;

    // model type definition
    typedef struct {
        logic [`NUM_SPIN-1:0][`NUM_SPIN*`BIT_J-1:0] weights;
        logic [`NUM_SPIN*`BIT_H-1:0] hbias;
        logic [`SCALING_BIT-1:0] scaling_factor;
        int signed constant;
    } model_t;

    // defines axi and register interface types
    `LAGD_TYPEDEF_ALL(lagd_, `IC_L1_J_MEM_DATA_WIDTH, `IC_L1_FLIP_MEM_DATA_WIDTH, CheshireCfg)

    // Testbench signals
    logic clk_i;
    logic rst_ni;
    logic reg_config_done;
    logic flush_en, en_aw, en_em, en_fm, en_ff, en_ef, en_analog_loop, en_comparison;
    logic cmpt_en, config_valid_aw, config_valid_em, config_valid_fm;
    logic debug_dt_configure_enable, debug_spin_configure_enable, en_perf_counter, config_spin_initial_skip_0, config_spin_initial_skip_1;
    logic bypass_data_conversion, dt_cfg_enable, host_readout, flip_disable;
    logic enable_flip_detection, debug_j_write_en, debug_j_read_en, debug_spin_write_en, debug_spin_compute_en, debug_spin_read_en;
    logic [$clog2(`NUM_SPIN)-1:0] config_counter;
    logic wwl_vdd_cfg_256, wwl_vread_cfg_256;
    logic [$clog2(`SYNCH_PIPE_DEPTH)-1:0] synchronizer_pipe_num, synchronizer_wbl_pipe_num;
    logic debug_h_wwl;
    logic [`IC_L1_J_MEM_ADDR_WIDTH-1:0] dgt_addr_upper_bound;
    logic ctnus_fifo_read, ctnus_dgt_debug, infinite_icon_loop_en, multi_cmpt_mode_en;
    logic [`LAGD_REG_DATA_WIDTH-1:0] global_cfg_reg_1, global_cfg_reg_2;
    logic [(`NUM_SPIN*`BIT_J)-1:0] h_rdata, wbl_floating;
    logic [`CC_COUNTER_BITWIDTH-1:0] cmpt_max_num;
    logic axi_test_done;
    model_t model;
    logic [`CVA6_ADDR_WIDTH-1:0] axi_write_addr;
    logic [`LAGD_AXI_DATA_WIDTH-1:0] axi_write_data;
    logic [1024-1:0] [`NUM_SPIN-1:0] flip_icon;

    // External AXI interconnect
    lagd_axi_slv_req_t axi_ext_slv_req_0 = 'd0;
    lagd_axi_slv_rsp_t axi_ext_slv_rsp_0;
    lagd_axi_slv_req_t axi_ext_slv_req_1 = 'd0;
    lagd_axi_slv_rsp_t axi_ext_slv_rsp_1;
    // Register interface
    lagd_reg_req_t reg_ext_req;
    lagd_reg_rsp_t reg_ext_rsp;
    logic [`LAGD_REG_DATA_WIDTH-1:0] reg_rsp_rdata;
    logic reg_rsp_ready;

    // Galena wires
    wire galena_j_iref_i;
    wire galena_j_vup_i;
    wire galena_j_vdn_i;
    wire galena_h_iref_i;
    wire galena_h_vdn_i;
    wire galena_h_vup_i;
    wire galena_vread_i;

    assign global_cfg_reg_1 = {synchronizer_wbl_pipe_num,
                            wwl_vread_cfg_256, wwl_vdd_cfg_256, config_counter,
                            debug_spin_read_en, debug_spin_compute_en, debug_spin_write_en,
                            debug_j_read_en, debug_j_write_en, enable_flip_detection,
                            flip_disable, host_readout, bypass_data_conversion,
                            en_perf_counter, debug_spin_configure_enable,
                            debug_dt_configure_enable, en_comparison, en_analog_loop,
                            en_ef, en_ff, en_fm, en_em, en_aw, flush_en};

    assign global_cfg_reg_2 = {12'd0, config_spin_initial_skip_1, config_spin_initial_skip_0, multi_cmpt_mode_en, infinite_icon_loop_en, ctnus_dgt_debug, ctnus_fifo_read, dgt_addr_upper_bound,
                            debug_h_wwl, synchronizer_pipe_num,
                            dt_cfg_enable, config_valid_fm, config_valid_em,
                            config_valid_aw, cmpt_en};

    assign reg_rsp_ready = reg_ext_rsp.ready;
    assign reg_rsp_rdata = reg_ext_rsp.rdata;

    // Module instantiation
    ising_core_wrap #(
        .l1_mem_cfg_j      (lagd_mem_cfg_pkg::IsingCoreL1MemCfgJ    ),
        .l1_mem_cfg_flip   (lagd_mem_cfg_pkg::IsingCoreL1MemCfgFlip ),
        .logic_cfg         (ising_logic_pkg::IsingLogicCfg          ),
        .axi_slv_req_t     (lagd_axi_slv_req_t                      ),
        .axi_slv_rsp_t     (lagd_axi_slv_rsp_t                      ),
        .axi_narrow_req_t  (lagd_axi_slv_req_t                      ),
        .axi_narrow_rsp_t  (lagd_axi_slv_rsp_t                      ),
        .axi_wide_req_t    (lagd_axi_wide_slv_req_t                 ),
        .axi_wide_rsp_t    (lagd_axi_wide_slv_rsp_t                 ),
        .mem_narrow_req_t  (lagd_mem_narr_req_t                     ),
        .mem_narrow_rsp_t  (lagd_mem_narr_rsp_t                     ),
        .mem_j_req_t       (lagd_mem_j_req_t                        ),
        .mem_j_rsp_t       (lagd_mem_j_rsp_t                        ),
        .mem_f_req_t       (lagd_mem_f_req_t                        ),
        .mem_f_rsp_t       (lagd_mem_f_rsp_t                        ),
        .axi_slv_aw_chan_t (lagd_axi_slv_aw_chan_t                  ),
        .axi_slv_w_chan_t  (lagd_axi_slv_w_chan_t                   ),
        .axi_slv_b_chan_t  (lagd_axi_slv_b_chan_t                   ),
        .axi_slv_ar_chan_t (lagd_axi_slv_ar_chan_t                  ),
        .axi_slv_r_chan_t  (lagd_axi_slv_r_chan_t                   ),
        .reg_req_t         (lagd_reg_req_t                          ),
        .reg_rsp_t         (lagd_reg_rsp_t                          )
    ) dut (
        .clk_i             (clk_i                                   ),
        .rst_ni            (rst_ni                                  ),
        // AXI slave interface
        .axi_s_req_0_i       (axi_ext_slv_req_0                     ),
        .axi_s_rsp_0_o       (axi_ext_slv_rsp_0                     ),
        .axi_s_req_1_i       (axi_ext_slv_req_1                     ),
        .axi_s_rsp_1_o       (axi_ext_slv_rsp_1                     ),
        // Register interface
        .reg_s_req_i       (reg_ext_req                             ),
        .reg_s_rsp_o       (reg_ext_rsp                             ),
        // Galena wires
        .galena_j_iref_i   (galena_j_iref_i                         ),
        .galena_j_vup_i    (galena_j_vup_i                          ),
        .galena_j_vdn_i    (galena_j_vdn_i                          ),
        .galena_h_iref_i   (galena_h_iref_i                         ),
        .galena_h_vup_i    (galena_h_vup_i                          ),
        .galena_h_vdn_i    (galena_h_vdn_i                          ),
        .galena_vread_i    (galena_vread_i                          )
    );

    // Run tests
    initial begin
        if (`DBG) begin
            $display("Debug mode enabled. Running with detailed output.");
            $dumpfile(`VCD_FILE);
            $dumpvars(2, tb_ising_core_wrap); // Dump all variables in testbench module
            $timeformat(-9, 1, " ns", 9);
            #(10_000 * CLKCYCLE); // To avoid generating huge VCD files
            $display("Testbench timeout reached. Ending simulation.");
            $finish;
        end
        else begin
            $timeformat(-9, 1, " ns", 9);
            #(1_000_000_000 * CLKCYCLE);
            $display("Testbench timeout reached. Ending simulation.");
            $finish;
        end
    end


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
    end

    // ========================================================================
    // Model reading function (copied from digital macro)
    // ========================================================================
    // Function to parse a line (max length: NUM_SPIN*BITJ) from the model file
    function automatic logic [`NUM_SPIN*`BIT_J-1:0] parse_bit_string(string line);
        logic [`NUM_SPIN*`BIT_J-1:0] result = 'd0;
        int bit_idx = 0;
        int i = 0;
        while (i < line.len() && bit_idx < `NUM_SPIN*`BIT_J) begin
            if (line[i] == "0" || line[i] == "1") begin
                result[`NUM_SPIN*`BIT_J-1-bit_idx] = $unsigned(line[i]);
                bit_idx = bit_idx + 1;
            end
            i = i + 1;
        end
        return result;
    endfunction

    // Function to read weight model from file
    function automatic model_t load_model();
        int model_file;
        string line;
        int line_num = 0;
        int weight_idx = 0;
        int hbias_idx = 0;
        model_t model;
        real const_real;
        int const_round;
        real scaling_real;
        int scaling_int;

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
                if (line_num > 1 && line_num <= (1 + `NUM_SPIN)) begin
                    model.weights[weight_idx] = parse_bit_string(line);
                    weight_idx = weight_idx + 1;
                end
                // Read hbias (4 bits per line)
                else if (line_num > (1 + `NUM_SPIN) && line_num <= (2 + 2*`NUM_SPIN)) begin
                    model.hbias[(`NUM_SPIN - 1 - hbias_idx) * `BIT_H +: `BIT_H] = parse_bit_string(line)[`NUM_SPIN*`BIT_J-1 -: `BIT_H];
                    hbias_idx = hbias_idx + 1;
                end
                // Read constant as a signed integer
                else if (line_num > (2 + 2*`NUM_SPIN) && line_num <= (4 + 2*`NUM_SPIN)) begin
                    if ($sscanf(line, "%f", const_real) != 1) begin
                        $display("Error: Failed to parse constant from line: %s (@ line %0d)", line, line_num);
                        $finish;
                    end
                    if (const_real >= 0)
                        const_round = $rtoi(const_real + 0.5);
                    else
                        const_round = $rtoi(const_real - 0.5);
                    model.constant = const_round;
                end else begin
                    if (line_num > (4 + 2*`NUM_SPIN)) begin
                        if ($sscanf(line, "%f", scaling_real) != 1) begin
                        $display("Error: Failed to parse the scaling factor from line: %s (@ line %0d)", line, line_num);
                        $finish;
                        end
                    scaling_int = $rtoi(scaling_real + 0.5);
                    // check if scaling_int is in the legal range [1, 16]
                    if (scaling_int <= 0 || scaling_int > 16) begin
                        $fatal(1, "The scaling_int 'd%d is beyond the range of [1, 16]", scaling_int);
                        end
                    // check if scaling_int is in the power of 2
                    if ((scaling_int & (scaling_int-1)) != 0) begin
                        $fatal(1, "The scaling_int 'd%d is not in the power of 2", scaling_int);
                        end
                    model.scaling_factor = scaling_int[`SCALING_BIT-1:0];
                    end
                end
            end
        end
        $fclose(model_file);
        $display("[Time: %t] Model file %s is loaded successfully.", $time, `MODEL_FILE);
        return model;
    endfunction

    // Function to read flip icons from file
    function automatic logic [1024-1:0] [`NUM_SPIN-1:0] load_flip_icons();
        int icon_file;
        string line;
        int line_num;
        int icon_idx;
        string file_name;
        logic [1:0] [512-1:0] [`NUM_SPIN-1:0] flip_icons_in_mem_txt;
        logic [1024-1:0] [`NUM_SPIN-1:0] flip_icons_in_mem;

        for (int i = 0; i < 2; i = i + 1) begin
            icon_idx = 0;
            line_num = 0;
            // Open the appropriate file
            if (i == 0)
                file_name = `FLIP_ICON_FILE_1;
            else
                file_name = `FLIP_ICON_FILE_2;
            icon_file = $fopen(file_name, "r");
            if (icon_file == 0) begin
                $display("Error: Could not open cluster file %s", file_name);
                $finish;
            end

            // Read the file line by line
            while (!$feof(icon_file)) begin
                if ($fgets(line, icon_file) != 0) begin
                    line_num = line_num + 1;
                    // Skip comment lines and header lines
                    if (line[0] == "#" || line[0] == "\n") begin
                        continue;
                    end
                    flip_icons_in_mem_txt[i][icon_idx] = parse_bit_string(line)[`NUM_SPIN*`BIT_J-1 -: `NUM_SPIN];
                    icon_idx = icon_idx + 1;
                end
            end
            $fclose(icon_file);
        end
        // shuffle two sets of icons into one memory
        for (int j = 0; j < 512; j = j + 1) begin
            flip_icons_in_mem[j*2] = flip_icons_in_mem_txt[0][j];
            flip_icons_in_mem[j*2+1] = flip_icons_in_mem_txt[1][j];
        end
        $display("[Time: %t] Flip icon file %s and %s are loaded successfully.", $time, `FLIP_ICON_FILE_1, `FLIP_ICON_FILE_2);
        return flip_icons_in_mem;
    endfunction

    // Function to load initial spin states from file
    function automatic logic [1:0] [`NUM_SPIN-1:0] load_initial_states();
        int state_file;
        string line;
        int line_num;
        string file_name;
        logic [1:0] [`NUM_SPIN-1:0] states_in_txt;

        for (int i = 0; i < 2; i = i + 1) begin
            line_num = 0;
            // Open the appropriate file
            if (i == 0)
                file_name = `STATE_IN_FILE_1;
            else
                file_name = `STATE_IN_FILE_2;
            state_file = $fopen(file_name, "r");
            if (state_file == 0) begin
                $display("Error: Could not open state input file %s", file_name);
                $finish;
            end

            // Read the file line by line
            while (line_num == 0) begin
                if ($fgets(line, state_file) != 0) begin
                    // Skip comment lines and header lines
                    if (line[0] == "#" || line[0] == "\n") begin
                        continue;
                    end
                    line_num = line_num + 1;
                    states_in_txt[i] = parse_bit_string(line)[`NUM_SPIN*`BIT_J-1 -: `NUM_SPIN];
                end
            end
            $fclose(state_file);
        end
        $display("[Time: %t] Initial state file %s and %s are loaded successfully.", $time, `STATE_IN_FILE_1, `STATE_IN_FILE_2);
        return states_in_txt;
    endfunction

    // ========================================================================
    // AXI Test
    // ========================================================================

    function automatic lagd_axi_slv_req_t axi_write_slv (
        input logic [`CVA6_ADDR_WIDTH-1:0] addr,
        input logic [`LAGD_AXI_DATA_WIDTH-1:0] data
    );
        lagd_axi_slv_req_t axi_ext_slv_req_tmp;
        axi_ext_slv_req_tmp.aw_valid = 1'b1;
        axi_ext_slv_req_tmp.aw.id = 6'h0;
        axi_ext_slv_req_tmp.aw.addr = addr;
        axi_ext_slv_req_tmp.aw.len = 8'h0; // single beat
        axi_ext_slv_req_tmp.aw.size = 3'h3; // 8 bytes
        axi_ext_slv_req_tmp.aw.burst = 2'b01;
        axi_ext_slv_req_tmp.aw.lock = 1'b0;
        axi_ext_slv_req_tmp.aw.cache = 4'b0000;
        axi_ext_slv_req_tmp.aw.prot = 3'b000;
        axi_ext_slv_req_tmp.aw.qos = 4'b0000;
        axi_ext_slv_req_tmp.aw.region = 4'b0000;
        axi_ext_slv_req_tmp.aw.user = 2'b00;
        axi_ext_slv_req_tmp.aw.atop = 6'h00;
        axi_ext_slv_req_tmp.w_valid = 1'b1;
        axi_ext_slv_req_tmp.w.data = data;
        axi_ext_slv_req_tmp.w.strb = 8'hFF; // All byte lanes enabled (for 64-bit = 8 bytes)
        axi_ext_slv_req_tmp.w.last = 1'b1; // Last beat (since len=0, single beat)
        axi_ext_slv_req_tmp.w.user = 2'b00;
        axi_ext_slv_req_tmp.b_ready = 1'b0; // Initially not ready to accept response
        axi_ext_slv_req_tmp.r_ready = 1'b0; // Not a read request
        axi_ext_slv_req_tmp.ar_valid = 1'b0; // Not a read request
        axi_ext_slv_req_tmp.ar.id = 6'h0;
        axi_ext_slv_req_tmp.ar.addr = 'd0;
        axi_ext_slv_req_tmp.ar.len = 8'h0;
        axi_ext_slv_req_tmp.ar.size = 3'h0;
        axi_ext_slv_req_tmp.ar.burst = 2'b00;
        axi_ext_slv_req_tmp.ar.lock = 1'b0;
        axi_ext_slv_req_tmp.ar.cache = 4'b0000;
        axi_ext_slv_req_tmp.ar.prot = 3'b000;
        axi_ext_slv_req_tmp.ar.qos = 4'b0000;
        axi_ext_slv_req_tmp.ar.region = 4'b0000;
        axi_ext_slv_req_tmp.ar.user = 2'b00;
        return axi_ext_slv_req_tmp;
    endfunction

    initial begin
        axi_test_done = 1'b0;
        model = load_model();
        flip_icon = load_flip_icons();
        wait (rst_ni == 1);
        @(posedge clk_i);
        $display("Starting AXI test...");
        // axi0 test
        for (int i = 0; i < `NUM_SPIN; i++) begin
            for (int j = 0; j < `NUM_SPIN*`BIT_J/`LAGD_AXI_DATA_WIDTH; j++) begin
                axi_write_addr = (i*(`NUM_SPIN*`BIT_J/`LAGD_AXI_DATA_WIDTH) + j)*8; // byte address
                axi_write_data = model.weights[i][j*`LAGD_AXI_DATA_WIDTH +: `LAGD_AXI_DATA_WIDTH];
                @ (posedge clk_i);
                axi_ext_slv_req_0 = axi_write_slv(axi_write_addr, axi_write_data);
                wait(axi_ext_slv_rsp_0.b_valid);
                axi_ext_slv_req_0.b_ready = 1'b1;
                if (axi_ext_slv_rsp_0.b.resp != 2'b00) // Check for OKAY response
                    $error("Write failed with response: %0d", axi_ext_slv_rsp_0.b.resp);
            end
        end
        axi_ext_slv_req_0 = 'd0; // Deassert after use

        // axi1 test
        for (int i = 0; i < 1024; i++) begin
            for (int j = 0; j < `NUM_SPIN / `LAGD_AXI_DATA_WIDTH; j++) begin
                axi_write_addr = (i*(`NUM_SPIN/`LAGD_AXI_DATA_WIDTH) + j)*8; // byte address
                axi_write_data = flip_icon[i][j*`LAGD_AXI_DATA_WIDTH +: `LAGD_AXI_DATA_WIDTH];
                @ (posedge clk_i);
                axi_ext_slv_req_1 = axi_write_slv(axi_write_addr, axi_write_data);
                wait(axi_ext_slv_rsp_1.b_valid);
                axi_ext_slv_req_1.b_ready = 1'b1;
                if (axi_ext_slv_rsp_1.b.resp != 2'b00) // Check for OKAY response
                    $error("Write failed with response: %0d", axi_ext_slv_rsp_1.b.resp);
            end
        end
        axi_ext_slv_req_1 = 'd0; // Deassert after use
        $display("AXI test completed successfully.");
        axi_test_done = 1'b1;
    end

    // ========================================================================
    // Register Test
    // ========================================================================

    // Reg configuration process
    initial begin
        reg_config_done = 0;
        reg_ext_req = gen_reg_req('h0, 1'b0, 'd0, 1'b0);
        wait (rst_ni == 1);
        wait (axi_test_done == 1);
        // Initialize reg interfaces
        reg_config();
    end

function automatic lagd_reg_req_t gen_reg_req(
    input logic [`CVA6_ADDR_WIDTH-1:0] addr,
    input logic write,
    input logic [`LAGD_REG_DATA_WIDTH-1:0] wdata,
    input logic valid
);
    lagd_reg_req_t req;
    req.addr  = addr;
    req.write = write;
    req.wdata = wdata;
    req.wstrb = {(`LAGD_REG_DATA_WIDTH/8){1'b1}}; // default all byte lanes enabled
    req.valid = valid;
    return req;
endfunction

task automatic reg_config();
    integer i;
    logic [`LAGD_REG_DATA_WIDTH-1:0] reg_data;

    logic [`NUM_SPIN-1:0] config_spin_initial_0, config_spin_initial_1;
    logic [`COUNTER_BITWIDTH-1:0] cycle_per_spin_write, cycle_per_wwl_low, cycle_per_wwl_high, cfg_trans_num;
    logic [`SCALING_BIT-1:0] dgt_hscaling;
    logic [$clog2(`FLIP_ICON_DEPTH):0] icon_last_raddr_plus_one;
    logic [`COUNTER_BITWIDTH-1:0] debug_spin_read_num, debug_cycle_per_spin_read, cycle_per_spin_compute;
    logic [`NUM_SPIN-1:0] wwl_vdd_cfg, wwl_vread_cfg, spin_wwl_strobe, spin_feedback, debug_j_one_hot_wwl;

    // Prepare configuration values
    flush_en = 1'b0;
    en_aw = 1'b1;
    en_em = 1'b1;
    en_fm = 1'b1;
    en_ff = 1'b1;
    en_ef = 1'b0;
    en_analog_loop = 1'b1;
    en_comparison = 1'b1;
    cmpt_en = 1'b0;
    config_valid_aw = 1'b0;
    config_valid_em = 1'b0;
    config_valid_fm = 1'b0;
    debug_dt_configure_enable = 1'b0;
    debug_spin_configure_enable = 1'b0;
    en_perf_counter = 1'b1;
    bypass_data_conversion = 1'b0;
    dt_cfg_enable = 1'b0;
    host_readout = 1'b0;
    flip_disable = 1'b0;
    enable_flip_detection = 1'b1;
    debug_j_write_en = 1'b0;
    debug_j_read_en = 1'b0;
    debug_spin_write_en = 1'b0;
    debug_spin_compute_en = 1'b0;
    debug_spin_read_en = 1'b0;
    config_counter = `NUM_SPIN-1;
    wwl_vdd_cfg_256 = 1'b1;
    wwl_vread_cfg_256 = 1'b0;
    synchronizer_pipe_num = 'd3;
    synchronizer_wbl_pipe_num = 'd3;
    debug_h_wwl = 1'b0;
    dgt_addr_upper_bound = `NUM_SPIN/`PARALLELISM-1;
    ctnus_fifo_read = 1'b0;
    ctnus_dgt_debug = 1'b0;
    infinite_icon_loop_en = 1'b0;
    multi_cmpt_mode_en = 1'b0;
    config_spin_initial_skip_0 = 1'b0;
    config_spin_initial_skip_1 = 1'b0;

    cmpt_max_num = 'hffffffff; // set to max

    {config_spin_initial_1, config_spin_initial_0} = load_initial_states;

    cycle_per_spin_write = 'd1;
    cycle_per_wwl_low = 'd1;
    cycle_per_wwl_high = 'd1;
    cfg_trans_num = `NUM_SPIN/`PARALLELISM;

    dgt_hscaling = model.scaling_factor;
    icon_last_raddr_plus_one = `FLIP_ICON_DEPTH;
    debug_spin_read_num = `FLIP_ICON_DEPTH;
    debug_cycle_per_spin_read = 'd2;
    cycle_per_spin_compute = 'd2;

    wwl_vdd_cfg     = {`NUM_SPIN{1'b1}}; // all high
    wwl_vread_cfg   = {`NUM_SPIN{1'b0}}; // all low
    spin_wwl_strobe = {`NUM_SPIN{1'b1}}; // all high
    spin_feedback   = {`NUM_SPIN{1'b1}}; // all high

    h_rdata = {`NUM_SPIN{4'b1010}}; // alternating 1010
    wbl_floating = {`NUM_SPIN{4'b0000}};
    debug_j_one_hot_wwl = 'd0;

    // Write configuration registers
    // max num of cmpt
    reg_data = cmpt_max_num;
    @ (posedge clk_i);
    reg_ext_req = gen_reg_req(LAGD_CORE_CMPT_MAX_NUM_OFFSET, 1'b1, reg_data, 1'b1);

    // Spin initial configuration, set 0
    for (i = 0; i < `NUM_SPIN/`LAGD_REG_DATA_WIDTH; i = i + 1) begin
        reg_data = config_spin_initial_0[i*`LAGD_REG_DATA_WIDTH +: `LAGD_REG_DATA_WIDTH];
        @ (posedge clk_i);
        reg_ext_req = gen_reg_req(LAGD_CORE_CONFIG_SPIN_INITIAL_0_0_OFFSET + (i * `LAGD_REG_DATA_WIDTH/8), 1'b1, reg_data, 1'b1);
    end

    // Spin initial configuration, set 1
    for (i = 0; i < `NUM_SPIN/`LAGD_REG_DATA_WIDTH; i = i + 1) begin
        reg_data = config_spin_initial_1[i*`LAGD_REG_DATA_WIDTH +: `LAGD_REG_DATA_WIDTH];
        @ (posedge clk_i);
        reg_ext_req = gen_reg_req(LAGD_CORE_CONFIG_SPIN_INITIAL_1_0_OFFSET + (i * `LAGD_REG_DATA_WIDTH/8), 1'b1, reg_data, 1'b1);
    end

    // Counters, set 1
    reg_data = {cycle_per_wwl_high, cfg_trans_num};
    @ (posedge clk_i);
    reg_ext_req = gen_reg_req(LAGD_CORE_COUNTER_CFG_1_OFFSET, 1'b1, reg_data, 1'b1);
    // Counters, set 2
    reg_data = {cycle_per_spin_write, cycle_per_wwl_low};
    @ (posedge clk_i);
    reg_ext_req = gen_reg_req(LAGD_CORE_COUNTER_CFG_2_OFFSET, 1'b1, reg_data, 1'b1);
    // Counters, set 3
    reg_data = {debug_cycle_per_spin_read, cycle_per_spin_compute};
    @ (posedge clk_i);
    reg_ext_req = gen_reg_req(LAGD_CORE_COUNTER_CFG_3_OFFSET, 1'b1, reg_data, 1'b1);
    // Counters, set 4
    reg_data = {dgt_hscaling, icon_last_raddr_plus_one, debug_spin_read_num};
    @ (posedge clk_i);
    reg_ext_req = gen_reg_req(LAGD_CORE_COUNTER_CFG_4_OFFSET, 1'b1, reg_data, 1'b1);
    // WWL VDD
    for (i = 0; i < `NUM_SPIN/`LAGD_REG_DATA_WIDTH; i = i + 1) begin
        reg_data = wwl_vdd_cfg[i*`LAGD_REG_DATA_WIDTH +: `LAGD_REG_DATA_WIDTH];
        @ (posedge clk_i);
        reg_ext_req = gen_reg_req(LAGD_CORE_WWL_VDD_CFG_0_OFFSET + (i * `LAGD_REG_DATA_WIDTH/8), 1'b1, reg_data, 1'b1);
    end
    // WWL VREAD
    for (i = 0; i < `NUM_SPIN/`LAGD_REG_DATA_WIDTH; i = i + 1) begin
        reg_data = wwl_vread_cfg[i*`LAGD_REG_DATA_WIDTH +: `LAGD_REG_DATA_WIDTH];
        @ (posedge clk_i);
        reg_ext_req = gen_reg_req(LAGD_CORE_WWL_VREAD_CFG_0_OFFSET + (i * `LAGD_REG_DATA_WIDTH/8), 1'b1, reg_data, 1'b1);
    end
    // Spin WWL strobe
    for (i = 0; i < `NUM_SPIN/`LAGD_REG_DATA_WIDTH; i = i + 1) begin
        reg_data = spin_wwl_strobe[i*`LAGD_REG_DATA_WIDTH +: `LAGD_REG_DATA_WIDTH];
        @ (posedge clk_i);
        reg_ext_req = gen_reg_req(LAGD_CORE_SPIN_WWL_STROBE_0_OFFSET + (i * `LAGD_REG_DATA_WIDTH/8), 1'b1, reg_data, 1'b1);
    end
    // Spin feedback
    for (i = 0; i < `NUM_SPIN/`LAGD_REG_DATA_WIDTH; i = i + 1) begin
        reg_data = spin_feedback[i*`LAGD_REG_DATA_WIDTH +: `LAGD_REG_DATA_WIDTH];
        @ (posedge clk_i);
        reg_ext_req = gen_reg_req(LAGD_CORE_SPIN_FEEDBACK_CFG_0_OFFSET + (i * `LAGD_REG_DATA_WIDTH/8), 1'b1, reg_data, 1'b1);
    end
    // h_rdata
    for (i = 0; i < `NUM_SPIN*`BIT_J/`LAGD_REG_DATA_WIDTH; i = i + 1) begin
        reg_data = h_rdata[i*`LAGD_REG_DATA_WIDTH +: `LAGD_REG_DATA_WIDTH];
        @ (posedge clk_i);
        reg_ext_req = gen_reg_req(LAGD_CORE_H_RDATA_0_OFFSET + (i * `LAGD_REG_DATA_WIDTH/8), 1'b1, reg_data, 1'b1);
    end
    // wbl_floating
    for (i = 0; i < `NUM_SPIN*`BIT_J/`LAGD_REG_DATA_WIDTH; i = i + 1) begin
        reg_data = wbl_floating[i*`LAGD_REG_DATA_WIDTH +: `LAGD_REG_DATA_WIDTH];
        @ (posedge clk_i);
        reg_ext_req = gen_reg_req(LAGD_CORE_WBL_FLOATING_0_OFFSET + (i * `LAGD_REG_DATA_WIDTH/8), 1'b1, reg_data, 1'b1);
    end
    // debug_j_one_hot_wwl
    for (i = 0; i < `NUM_SPIN/`LAGD_REG_DATA_WIDTH; i = i + 1) begin
        reg_data = debug_j_one_hot_wwl[i*`LAGD_REG_DATA_WIDTH +: `LAGD_REG_DATA_WIDTH];
        @ (posedge clk_i);
        reg_ext_req = gen_reg_req(LAGD_CORE_DEBUG_J_ONE_HOT_WWL_0_OFFSET + (i * `LAGD_REG_DATA_WIDTH/8), 1'b1, reg_data, 1'b1);
    end
    // load all configurations into the core
    config_valid_aw = 1'b1;
    config_valid_em = 1'b1;
    config_valid_fm = 1'b1;
    debug_dt_configure_enable = 1'b1;
    debug_spin_configure_enable = 1'b1;
    @ (posedge clk_i);
    reg_ext_req = gen_reg_req(LAGD_CORE_GLOBAL_CFG_1_OFFSET, 1'b1, global_cfg_reg_1, 1'b1);
    @ (posedge clk_i);
    reg_ext_req = gen_reg_req(LAGD_CORE_GLOBAL_CFG_2_OFFSET, 1'b1, global_cfg_reg_2, 1'b1);
    config_valid_aw = 1'b0;
    config_valid_em = 1'b0;
    config_valid_fm = 1'b0;
    debug_dt_configure_enable = 1'b0;
    debug_spin_configure_enable = 1'b0;
    @ (posedge clk_i);
    reg_ext_req = gen_reg_req(LAGD_CORE_GLOBAL_CFG_1_OFFSET, 1'b1, global_cfg_reg_1, 1'b1);
    @ (posedge clk_i);
    reg_ext_req = gen_reg_req(LAGD_CORE_GLOBAL_CFG_2_OFFSET, 1'b1, global_cfg_reg_2, 1'b1);
    @ (posedge clk_i);
    // Deassert write valid signals
    reg_ext_req = gen_reg_req(LAGD_CORE_GLOBAL_CFG_2_OFFSET, 1'b1, global_cfg_reg_2, 1'b0);
    @ (posedge clk_i);
    // Start dt config
    dt_cfg_enable = 1'b1;
    @ (posedge clk_i);
    reg_ext_req = gen_reg_req(LAGD_CORE_GLOBAL_CFG_2_OFFSET, 1'b1, global_cfg_reg_2, 1'b1);
    dt_cfg_enable = 1'b0;
    @ (posedge clk_i);
    reg_ext_req = gen_reg_req(LAGD_CORE_GLOBAL_CFG_2_OFFSET, 1'b1, global_cfg_reg_2, 1'b1);
    // switch to output regsiter
    @ (posedge clk_i);
    reg_ext_req = gen_reg_req(LAGD_CORE_OUTPUT_STATUS_OFFSET, 1'b0, 'd0, 1'b1);
    repeat (5) @ (posedge clk_i);
    wait (reg_ext_rsp.rdata[0] == 1'b1); // wait for dt configuration done
    // Start computation
    en_ef = 1'b1;
    @ (posedge clk_i);
    reg_ext_req = gen_reg_req(LAGD_CORE_GLOBAL_CFG_1_OFFSET, 1'b1, global_cfg_reg_1, 1'b1);
    cmpt_en = 1'b1;
    @ (posedge clk_i);
    reg_ext_req = gen_reg_req(LAGD_CORE_GLOBAL_CFG_2_OFFSET, 1'b1, global_cfg_reg_2, 1'b1);
    cmpt_en = 1'b0;
    @ (posedge clk_i);
    reg_ext_req = gen_reg_req(LAGD_CORE_GLOBAL_CFG_2_OFFSET, 1'b1, global_cfg_reg_2, 1'b0);
    // switch to output register
    @ (posedge clk_i);
    reg_ext_req = gen_reg_req(LAGD_CORE_OUTPUT_STATUS_OFFSET, 1'b0, 'd0, 1'b1);
    repeat (2) @ (posedge clk_i);
    wait (dut.debug_fm_downstream_handshake == 1'b1); // wait for the first handshake indicating the first output is ready
    $display("Ending simulation.");
    @ (posedge clk_i);
    $finish;
endtask

endmodule
