// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

// System-wide definitions for LAGD system.

`include "lagd_config.svh"

`ifndef LAGD_DEFINE_SVH
`define LAGD_DEFINE_SVH

    // Platform define
    `define LAGD_NUM_AXI_SLV `NUM_ISING_CORES + 2 // +2 for L2 memory and stack memory
    `define LAGD_NUM_REG_SLV `NUM_ISING_CORES
    `define CVA6_ADDR_WIDTH 48

    // AXI
    `define LAGD_AXI_DATA_WIDTH 64
    `define LAGD_AXI_ID_WIDTH 6

    // L2 memory
    `define L2_MEM_BASE_ADDR 'h8000_0000
    `define L2_MEM_ADDR_WIDTH $clog2(`L2_MEM_SIZE_B)
    `define L2_WORDS_PER_BANK 2048
    `define L2_BANKING_FACTOR `L2_MEM_SIZE_B / (`LAGD_AXI_DATA_WIDTH/8) / `L2_WORDS_PER_BANK

    // CVA6 stack memory
    `define STACK_BASE_ADDR 'h8FFF_8000 // Top of L2 memory minus 32 kB
    `define STACK_SIZE_B 16*1024   // Max 32 kB stack size (according to STACK_BASE_ADDR)
    `define STACK_ADDR_WIDTH $clog2(`STACK_SIZE_B)
    `define STACK_WORDS_PER_BANK 2048
    `define STACK_BANKING_FACTOR `STACK_SIZE_B / (`LAGD_AXI_DATA_WIDTH/8) / `STACK_WORDS_PER_BANK

    // Ising cores
    `define IC_MEM_BASE_ADDR 'h9000_0000
    `define IC_J_MEM_END_ADDR 'h9000_8000    // J Mem Addr Space    32KB
    `define IC_FLIP_MEM_END_ADDR 'h9001_0000 // Flip Mem Addr Space 32KB
    `define IC_REGS_BASE_ADDR 'hA000_0000
    // L1 memory per core (j)
    `define IC_L1_MEM_LIMIT 'h10_0000 // 1 MB per core
    `define IC_L1_WORDS_PER_BANK 2048
    `define IC_L1_BANKING_FACTOR `L1_J_MEM_SIZE_B/(`LAGD_AXI_DATA_WIDTH/8)/`IC_L1_WORDS_PER_BANK
    // L1 memory port width
    `define IC_L1_DATA_WIDTH 4096
    `define IC_L1_FLIP_MEM_DATA_WIDTH 256
    `define IC_L1_FLIP_MEM_ADDR_WIDTH 16
    // Registers per core
    `define IC_NUM_REGS 'h1000    // 4 kB per core
    // Ising macro
    `define NUM_SPIN 256
    `define BIT_J 4
    `define BIT_H 4
    `define SCALING_BIT 4
    `define PARALLELISM 4
    `define ENERGY_TOTAL_BIT 32
    `define SYNCH_PIPE_DEPTH 3
    `define FLIP_ICON_DEPTH (`IC_FLIP_MEM_END_ADDR - `IC_J_MEM_END_ADDR)/(`NUM_SPIN)*8

`endif // LAGD_DEFINE_SVH