// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

`ifndef TB_COMMON_SVH
`define TB_COMMON_SVH

`ifndef DBG
`define DBG 0
`endif

`ifndef VCD_FILE
`define VCD_FILE "tb.vcd"
`endif

`define SETUP_DEBUG(__dbg, __vcd_file, __scope) \
    initial begin \
        if (__dbg) begin \
            $display("Debug mode enabled. Running with detailed output."); \
            $dumpfile(__vcd_file); \
            $dumpvars(0, __scope); \
        end \
    end

`endif