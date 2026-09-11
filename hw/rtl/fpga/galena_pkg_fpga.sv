// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Jiacong Sun <jiacong.sun@esat.kuleuven.be>
//
// FPGA twin of galena_pkg: parameters ONLY (synthesizable).
//
// The real hw/tb/models/galena/galena_pkg.sv carries non-synthesizable helper
// functions (string parsing, $fopen/$fgets) that Vivado's front-end rejects.
// On FPGA we only need the port widths for `galena_fpga_stub`, so this provides
// the same package name and identical parameter values, with no functions.
//
// The parameter section MUST stay in sync with galena_pkg.sv (same `NUM_SPIN`,
// `BIT_J` defines from lagd_define.svh -> identical widths).

`ifndef SPIN_ICON_DEPTH
`define SPIN_ICON_DEPTH 1024
`endif

`ifndef NUM_SPIN
`define NUM_SPIN 256
`endif

`ifndef BIT_J
`define BIT_J 4
`endif

`ifndef SPIN_WBL_OFFSET
`define SPIN_WBL_OFFSET 0
`endif

`ifndef DATA_FROM_FILE
`define DATA_FROM_FILE 1
`endif

package galena_pkg;

    // Parameters (mirrors galena_pkg.sv:32-42)
    parameter SPIN_DELAY_MAX  = 10; // ns
    parameter SPIN_DELAY_MIN  = 1;  // ns

    parameter NUM_SPIN        = `NUM_SPIN;
    parameter BIT_DATA        = `BIT_J;
    parameter SPIN_WBL_OFFSET = `SPIN_WBL_OFFSET;
    parameter SPIN_ICON_DEPTH = `SPIN_ICON_DEPTH;
    parameter DATA_FROM_FILE  = `DATA_FROM_FILE;
    parameter WWL_WIDTH       = NUM_SPIN + 1;       // +1 for h
    parameter WBL_WIDTH       = NUM_SPIN * BIT_DATA;

endpackage : galena_pkg
