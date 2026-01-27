// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Jiacong Sun <jiacong.sun@kuleuven.be>

// Package for data loading from algorithm input files, used in digital macro testbench

package data_read_pkg;
    import config_pkg::*;

    `define MODEL_FILE "./data/model_1"
    `define FLIP_ICON_FILE_1 "./data/clusters_1"
    `define ENERGY_REF_FILE_1 "./data/energy_1"
    `define STATE_IN_FILE_1 "./data/states_in_1"
    `define STATE_OUT_FILE_1 "./data/states_out_1"
    `define FLIP_ICON_FILE_2 "./data/clusters_2"
    `define ENERGY_REF_FILE_2 "./data/energy_2"
    `define STATE_IN_FILE_2 "./data/states_in_2"
    `define STATE_OUT_FILE_2 "./data/states_out_2"
    `define ENERGY_OUTPUT_FILE "./output/ref_energy_output"
    `define STATE_OUTPUT_FILE "./output/ref_state_output"
    `define TIMING_RECORD_FILE "./output/timing_record_output"

    // ========================================================================
    // Data Reading Package
    // ========================================================================
    // Function to parse a line (max length: NUM_SPIN*BITJ) from the model file
    function automatic logic [NUM_SPIN*BITJ-1:0] parse_bit_string(string line);
        logic [NUM_SPIN*BITJ-1:0] result = 'd0;
        int bit_idx = 0;
        int i = 0;
        while (i < line.len() && bit_idx < NUM_SPIN*BITJ) begin
            if (line[i] == "0" || line[i] == "1") begin
                if (LITTLE_ENDIAN)
                    result[bit_idx] = $unsigned(line[i]);
                else
                    result[NUM_SPIN*BITJ-1-bit_idx] = $unsigned(line[i]);
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
                if (line_num > 1 && line_num <= (1 + NUM_SPIN)) begin
                    model.weights[weight_idx] = parse_bit_string(line);
                    weight_idx = weight_idx + 1;
                end
                // Read hbias (4 bits per line)
                else if (line_num > (1 + NUM_SPIN) && line_num <= (2 + 2*NUM_SPIN)) begin
                    if (LITTLE_ENDIAN)
                        model.hbias[hbias_idx * BITH +: BITH] = parse_bit_string(line)[NUM_SPIN*BITJ-1 -: BITH];
                    else
                        model.hbias[(NUM_SPIN - 1 - hbias_idx) * BITH +: BITH] = parse_bit_string(line)[NUM_SPIN*BITJ-1 -: BITH];
                    hbias_idx = hbias_idx + 1;
                end
                // Read constant as a signed integer
                else if (line_num > (2 + 2*NUM_SPIN) && line_num <= (4 + 2*NUM_SPIN)) begin
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
                    if (line_num > (4 + 2*NUM_SPIN)) begin
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
                    model.scaling_factor = scaling_int[SCALING_BIT-1:0];
                    end
                end
            end
        end
        $fclose(model_file);
        $display("[Time: %t] Model file %s is loaded successfully.", $time, `MODEL_FILE);
        return model;
    endfunction

    // Function to read flip icons from file
    function automatic logic [1024-1:0] [NUM_SPIN-1:0] load_flip_icons();
        int icon_file;
        string line;
        int line_num;
        int icon_idx;
        logic [1:0] [512-1:0] [NUM_SPIN-1:0] flip_icons_in_mem_txt;
        logic [1024-1:0] [NUM_SPIN-1:0] flip_icons_in_mem;

        for (int i = 0; i < 2; i = i + 1) begin
            icon_idx = 0;
            line_num = 0;
            // Open the appropriate file
            if (i == 0)
                icon_file = $fopen(`FLIP_ICON_FILE_1, "r");
            else
                icon_file = $fopen(`FLIP_ICON_FILE_2, "r");
            if (icon_file == 0) begin
                $display("Error: Could not open cluster file %s", `FLIP_ICON_FILE_1);
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
                    flip_icons_in_mem_txt[i][icon_idx] = parse_bit_string(line)[NUM_SPIN*BITJ-1 -: NUM_SPIN];
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
    function automatic logic [1:0] [NUM_SPIN-1:0] load_initial_states();
        int state_file;
        string line;
        int line_num;
        logic [1:0] [NUM_SPIN-1:0] states_in_txt;

        for (int i = 0; i < 2; i = i + 1) begin
            line_num = 0;
            // Open the appropriate file
            if (i == 0)
                state_file = $fopen(`STATE_IN_FILE_1, "r");
            else
                state_file = $fopen(`STATE_IN_FILE_2, "r");
            if (state_file == 0) begin
                $display("Error: Could not open state input file %s", `STATE_IN_FILE_1);
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
                    states_in_txt[i] = parse_bit_string(line)[NUM_SPIN*BITJ-1 -: NUM_SPIN];
                end
            end
            $fclose(state_file);
            // $display("Loaded initial states from file %s: %b", (i == 0) ? `STATE_IN_FILE_1 : `STATE_IN_FILE_2, states_in_txt[i]);
        end
        $display("[Time: %t] Initial state file %s and %s are loaded successfully.", $time, `STATE_IN_FILE_1, `STATE_IN_FILE_2);
        return states_in_txt;
    endfunction

    // Function to load state out of the analog macro from files
    function automatic logic [1023:0] [NUM_SPIN-1:0] load_state_out_ref();
        int state_file;
        string line;
        int line_num;
        int state_idx;
        logic [1:0] [1024-1:0] [NUM_SPIN-1:0] states_out_in_txt;
        logic [1023:0] [NUM_SPIN-1:0] states_out_ref;

        for (int i = 0; i < 2; i = i + 1) begin
            state_idx = 0;
            line_num = 0;
            // Open the appropriate file
            if (i == 0)
                state_file = $fopen(`STATE_OUT_FILE_1, "r");
            else
                state_file = $fopen(`STATE_OUT_FILE_2, "r");
            if (state_file == 0) begin
                $display("Error: Could not open state output file %s", `STATE_OUT_FILE_1);
                $finish;
            end

            // Read the file line by line
            while (!$feof(state_file)) begin
                if ($fgets(line, state_file) != 0) begin
                    // Skip comment lines and header lines
                    if (line[0] == "#" || line[0] == "\n") begin
                        continue;
                    end
                    if (line_num == 0) begin
                        line_num = line_num + 1;
                        continue;
                    end
                    if (line_num >= 513) begin
                        $fatal(1, "Error: More than 512 effective lines of states found in file %s", (i == 0) ? `STATE_OUT_FILE_1 : `STATE_OUT_FILE_2);
                    end
                    line_num = line_num + 1;
                    states_out_in_txt[i][state_idx] = parse_bit_string(line)[NUM_SPIN*BITJ-1 -: NUM_SPIN];
                    state_idx = state_idx + 1;
                end
            end
            $fclose(state_file);
        end
        // shuffle two sets of states into one memory
        for (int j = 0; j < 512; j = j + 1) begin
                states_out_ref[2*j] = states_out_in_txt[0][j];
                states_out_ref[2*j+1] = states_out_in_txt[1][j];
            end
        $display("[Time: %t] State output file %s and %s are loaded successfully.", $time, `STATE_OUT_FILE_1, `STATE_OUT_FILE_2);
        return states_out_ref;
    endfunction

    // Function to output energies to files
    function automatic void output_energies_to_file(
        input logic signed [IconLastAddrPlusOne-1+1:0] [SPIN_DEPTH-1:0] [ENERGY_TOTAL_BIT-1:0] energy_values,
        input int constant
    );
        int energy_file;
        string file_name_with_depth;
        int updating_idx;
        for (int i = 0; i < SPIN_DEPTH; i = i + 1) begin
            updating_idx = 0;
            // Open the file corresponding to the current depth
            file_name_with_depth = {`ENERGY_OUTPUT_FILE, "_depth_", $sformatf("%0d", i), ".txt"};
            energy_file = $fopen(file_name_with_depth, "w");
            if (energy_file == 0) begin
                $display("Error: Could not open energy output file %s", file_name_with_depth);
                $finish;
            end
            // Write energies to the file
            for (int j = 0; j <= IconLastAddrPlusOne; j = j + 1) begin
                if (j == 0) begin
                    updating_idx = - 1;
                    $fwrite(energy_file, "%b\n", $signed(energy_values[j][i]));
                end
                if (updating_idx == i)
                    begin
                        $fwrite(energy_file, "%b\n", $signed(energy_values[j][i]) + constant);
                    end
                updating_idx = (updating_idx + 1) % SPIN_DEPTH;
            end
            $fclose(energy_file);
            $display("[Time: %t] Energy output file %s is written successfully.", $time, file_name_with_depth);
        end
    endfunction

    // Function to output spins to files
    function automatic void output_spins_to_file(
        input logic [IconLastAddrPlusOne-1+1:0] [SPIN_DEPTH-1:0] [NUM_SPIN-1:0] spin_values
    );
        int state_file;
        string file_name_with_depth;
        int updating_idx;
        for (int i = 0; i < SPIN_DEPTH; i = i + 1) begin
            updating_idx = 0;
            // Open the file corresponding to the current depth
            file_name_with_depth = {`STATE_OUTPUT_FILE, "_depth_", $sformatf("%0d", i), ".txt"};
            state_file = $fopen(file_name_with_depth, "w");
            if (state_file == 0) begin
                $display("Error: Could not open state output file %s", file_name_with_depth);
                $finish;
            end
            // Write spins to the file
            for (int j = 0; j <= IconLastAddrPlusOne; j = j + 1) begin
                if (j == 0) begin
                    updating_idx = - 1;
                    $fwrite(state_file, "%b\n", spin_values[j][i]);
                end
                if (updating_idx == i)
                    $fwrite(state_file, "%b\n", spin_values[j][i]);
                updating_idx = (updating_idx + 1) % SPIN_DEPTH;
            end
            $fclose(state_file);
            $display("[Time: %t] State output file %s is written successfully.", $time, file_name_with_depth);
        end
    endfunction

    // Function to output timing record to a file
    function automatic void output_timing_record_to_file(
        input logic [IconLastAddrPlusOne-1:0] [31:0] timing_record
    );
        int state_file;
        string file_name_with_depth;

        // Open the timing record file
        file_name_with_depth = {`TIMING_RECORD_FILE, ".txt"};
        state_file = $fopen(file_name_with_depth, "w");
        if (state_file == 0) begin
            $display("Error: Could not open timing record output file %s", file_name_with_depth);
            $finish;
        end
        for (int i = 0; i < IconLastAddrPlusOne; i = i + 1) begin
            $fwrite(state_file, "%0d\n", timing_record[i]);
        end
        $fclose(state_file);
        $display("[Time: %t] Timing record output file %s is written successfully.", $time, file_name_with_depth);

    endfunction
endpackage