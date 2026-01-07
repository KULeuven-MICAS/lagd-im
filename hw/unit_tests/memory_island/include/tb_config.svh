// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

// Test configuration and parameters for AXI-to-Memory Adapter testbench

`ifndef TB_CONFIG_SVH
`define TB_CONFIG_SVH

// ============================================================================
// TEST ENVIRONMENT PARAMETERS
// ============================================================================

// Timing parameters
localparam int unsigned TA = 3;  // Application delay
localparam int unsigned TT = 9;  // Test delay
localparam int unsigned CLK_PERIOD = 10; // Clock period in ns

// AXI test parameters
localparam int unsigned AXI_UserWidth = 2;
localparam int unsigned MAX_TXN_IN_FLIGHT = 16;

// Clock parameters
localparam int unsigned RST_CYCLES = 3;

// ============================================================================
// TEST STIMULUS PARAMETERS
// ============================================================================

// Test address region
localparam int unsigned TEST_REGION_START = 0;
localparam int unsigned TEST_REGION_END   = 16*1024 - 1;

// Transaction counts
localparam int unsigned NUM_READ_TRANSACTIONS  = 0;
localparam int unsigned NUM_WRITE_TRANSACTIONS = 200;

// ============================================================================
// SIMULATION CONTROL
// ============================================================================

// Simulation timeout (in time units)
localparam time SIM_TIMEOUT = 2000000ns;  // 2ms

// ============================================================================
// TYPEDEV SHORTHAND
// ============================================================================

localparam int unsigned dbg = `DBG;
localparam string vcd_file = `VCD_FILE;

`endif // TB_CONFIG_SVH
