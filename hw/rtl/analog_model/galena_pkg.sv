// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Jiacong Sun <jiacong.sun@kuleuven.be>

// Package for galena behavior model

`ifndef SPIN_ICON_DEPTH
`define SPIN_ICON_DEPTH 2
`endif

`ifndef NUM_SPIN
`define NUM_SPIN 256
`endif

`ifndef BIT_J
`define BIT_J 4
`endif

`ifndef SPIN_IDX
`define SPIN_IDX 0
`endif

`ifndef DATA_FROM_FILE
`define DATA_FROM_FILE 0
`endif

package galena_pkg;

    // Parameters
    parameter SPIN_DELAY_MAX = 10; // ns
    parameter SPIN_DELAY_MIN = 1; // ns

    // Derived parameters
    parameter NUM_SPIN = `NUM_SPIN;
    parameter BIT_DATA = `BIT_J;
    parameter SPIN_IDX = `SPIN_IDX;
    parameter SPIN_ICON_DEPTH = `SPIN_ICON_DEPTH;
    parameter DATA_FROM_FILE = `DATA_FROM_FILE;
    parameter WWL_WIDTH = NUM_SPIN+1; // +1 for h
    parameter WBL_WIDTH = NUM_SPIN*BIT_DATA;

    // Function to parse a line from a file
    function automatic logic [NUM_SPIN*BIT_DATA-1:0] parse_bit_string(string line);
        logic [NUM_SPIN*BIT_DATA-1:0] result = 'd0;
        int bit_idx = 0;
        int i = 0;
        while (i < line.len() && bit_idx < NUM_SPIN*BIT_DATA) begin
            if (line[i] == "0" || line[i] == "1") begin
                result[NUM_SPIN*BIT_DATA-1-bit_idx] = $unsigned(line[i]);
                bit_idx = bit_idx + 1;
            end
            i = i + 1;
        end
        return result;
    endfunction

    // Function to load state out of the analog macro from files
    function automatic logic [SPIN_ICON_DEPTH-1:0] [NUM_SPIN-1:0] load_state_out_ref(
        string state_out_file_1,
        string state_out_file_2
    );
        int state_file;
        string line;
        string file_name;
        int line_num;
        int state_idx;
        logic [1:0] [SPIN_ICON_DEPTH-1:0] [NUM_SPIN-1:0] states_out_in_txt;
        logic [SPIN_ICON_DEPTH-1:0] [NUM_SPIN-1:0] states_out_ref;

        for (int i = 0; i < 2; i = i + 1) begin
            state_idx = 0;
            line_num = 0;
            // Open the appropriate file
            if (i == 0)
                file_name = state_out_file_1;
            else
                file_name = state_out_file_2;
            state_file = $fopen(file_name, "r");
            if (state_file == 0) begin
                $display("Error: Could not open state output file %s", file_name);
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
                    if (line_num >= SPIN_ICON_DEPTH/2+1) begin
                        break;
                    end
                    line_num = line_num + 1;
                    states_out_in_txt[i][state_idx] = parse_bit_string(line)[NUM_SPIN*BIT_DATA-1 -: NUM_SPIN];
                    state_idx = state_idx + 1;
                end
            end
            $fclose(state_file);
        end
        // shuffle two sets of states into one memory
        for (int j = 0; j < SPIN_ICON_DEPTH/2; j = j + 1) begin
                states_out_ref[2*j] = states_out_in_txt[0][j];
                states_out_ref[2*j+1] = states_out_in_txt[1][j];
            end
        $display("[Time: %t] State output file %s and %s are loaded successfully.", $time, state_out_file_1, state_out_file_2);
        return states_out_ref;
    endfunction

endpackage: galena_pkg