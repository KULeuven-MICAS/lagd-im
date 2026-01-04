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

`define SETUP_DEBUG \
    if (`DBG) begin \
        $display("Debug mode enabled. Running with detailed output."); \
        $dumpfile(`VCD_FILE); \
        $dumpvars(0, $root); \
    end
`endif

`define TA 2 // Stimuli application time
`define TC 10 // Clock period
`define TT 9 // Test time