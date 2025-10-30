// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

// System-wide platform definitions and macros for LAGD system

`ifndef LAGD_PLATFORM_SVH
`define LAGD_PLATFORM_SVH
`ifndef SYNTHESIS
`define PACKAGE_ASSERT(cond) \
    /* verilator lint_on UNUSED */ \
    typedef bit [((cond) ? 0 : -1) : 0] static_assertion_at_line_`__LINE__; \
    /* verilator lint_off UNUSED */
`else
`define PACKAGE_ASSERT(cond)
`endif // SYNTHESIS

`define STATIC_ASSERT(cond, msg) \
    /* verilator lint_off GENUNNAMED */ \
    initial if (!(cond)) begin \
        $error(msg); \
    end \
    /* verilator lint_on GENUNNAMED */

`endif // LAGD_PLATFORM_SVH
