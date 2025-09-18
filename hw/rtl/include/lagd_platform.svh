// Copyright 2025 KU Leuven.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

// System-wide platform definitions and macros for LAGD system

`ifndef LAGD_PLATFORM_SVH
`define LAGD_PLATFORM_SVH

`define PACKAGE_ASSERT(cond) \
    /* verilator lint_on UNUSED */ \
    typedef bit [((cond) ? 0 : -1) : 0] static_assertion_at_line_`__LINE__; \
    /* verilator lint_off UNUSED */

`endif // LAGD_PLATFORM_SVH
