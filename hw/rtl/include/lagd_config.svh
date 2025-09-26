// Copyright 2025 KU Leuven.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

// User configuration for LAGD system

`ifndef LAGD_CONFIG_SVH
`define LAGD_CONFIG_SVH

    // Number of Ising cores in the system
    // Maximum is 14 (because of AXI ID width limitations)
    `ifndef NUM_ISING_CORES
        `define NUM_ISING_CORES 1
    `endif

    `ifndef IC_L1_MEM_SIZE_B
        `define IC_L1_MEM_SIZE_B 32*1024
    `endif

    `ifndef L2_MEM_SIZE_B
        `define L2_MEM_SIZE_B 64*1024
    `endif

`endif // LAGD_CONFIG_SVH
