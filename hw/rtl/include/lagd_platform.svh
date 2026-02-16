// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

// System-wide platform definitions and macros for LAGD system

`ifndef LAGD_PLATFORM_SVH
`define LAGD_PLATFORM_SVH

`ifndef TARGET_SYN
`define PACKAGE_ASSERT(cond) \
    /* verilator lint_on UNUSED */ \
    typedef bit [((cond) ? 0 : -1) : 0] static_assertion_at_line_`__LINE__; \
    /* verilator lint_off UNUSED */

`define STATIC_ASSERT(cond, msg) \
    /* verilator lint_off GENUNNAMED */ \
    initial if (!(cond)) begin \
        $error(msg); \
    end \
    /* verilator lint_on GENUNNAMED */

`define ASSERT(cond, msg) \
    assert (cond) else $error("Time %0t: %s", $time, msg)

`define SYNC_RUNTIME_ASSERT(cond, msg, clk, rst_n) \
    always @(posedge clk) begin   \
        if (rst_n) begin         \
            `ASSERT(cond, msg);   \
        end                       \
    end

`define RUNTIME_ASSERT(cond, msg) \
    always_comb begin           \
        `ASSERT(cond, msg);   \
    end

`else // TARGET_SYN

`define PACKAGE_ASSERT(cond)
`define STATIC_ASSERT(cond, msg)
`define ASSERT(cond, msg)
`define SYNC_RUNTIME_ASSERT(cond, msg, clk, rst_n)
`define RUNTIME_ASSERT(cond, msg)
`endif // TARGET_SYN

`define ZWIDTH_SAFE(width) ((width) == 0 ? 1 : (width))

`endif // LAGD_PLATFORM_SVH