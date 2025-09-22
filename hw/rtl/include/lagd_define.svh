// Copyright 2025 KU Leuven.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

// System-wide definitions for LAGD system

`include "lagd_config.svh"

`ifndef LAGD_DEFINE_SVH
`define LAGD_DEFINE_SVH

    // L2 memory
    `define L2_MEM_BASE_ADDR 'h8000_0000
    `define L2_MEM_ADDR_WIDTH $clog2(`L2_MEM_SIZE_B)

    // CVA6 stack memory
    `define CVA6_STACK_BASE_ADDR 'h8FFF_8000 // Top of L2 memory minus 32 kB
    `define CVA6_STACK_SIZE_B 16*1024   // Max 32 kB stack size (according to CVA6_STACK_BASE_ADDR)
    `define CVA6_STACK_ADDR_WIDTH $clog2(`CVA6_STACK_SIZE_B)
    `define CVA6_ADDR_WIDTH 48

    // Platform define
    `define LAGD_AXI_ID_WIDTH 6

    // Ising islands
    `define ISING_ISLANDS_BASE_ADDR 'h9000_0000
    `define LAGD_REGS_BASE_ADDR 'hA000_0000
    `define MAX_MEM_PER_ISLAND 'h10_0000 // 1 MB per island
    `define REGS_PER_ISLAND 'h1000    // 4 kB per island

`endif // LAGD_DEFINE_SVH