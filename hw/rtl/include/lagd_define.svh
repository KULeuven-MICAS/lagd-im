// Copyright 2025 KU Leuven.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

// System-wide definitions for LAGD system

`ifndef LAGD_DEFINE_SVH
`define LAGD_DEFINE_SVH

    `define L2_MEM_BASE_ADDR 'h8000_0000
    `define ISING_ISLANDS_BASE_ADDR 'h9000_0000
    `define LAGD_REGS_BASE_ADDR 'hA000_0000
    `define MAX_MEM_PER_ISLAND 'h10_0000 // 1 MB per island
    `define REGS_PER_ISLAND 'h1000    // 4 KB per island

`endif // LAGD_DEFINE_SVH