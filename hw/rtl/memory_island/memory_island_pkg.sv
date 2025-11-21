// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

// Package for memory configuration and definitions

`include "lagd_config.svh"
`include "lagd_platform.svh"
`include "lagd_define.svh"

`define MAX_NUM_NARROW_REQ 32
`define MAX_NUM_WIDE_REQ   16

package memory_island_pkg;

    typedef struct packed {
        /// Address Width
        int unsigned AddrWidth;
        /// Data Width for the Narrow Ports
        int unsigned NarrowDataWidth;
        /// Data Width for the Wide Ports
        int unsigned WideDataWidth;

        int unsigned AxiNarrowIdWidth;
        int unsigned AxiWideIdWidth;

        /// Number of Narrow Ports
        int unsigned NumAxiNarrowReq;
        int unsigned NumDirectNarrowReq;
        /// Number of Wide Ports
        int unsigned NumAxiWideReq;
        int unsigned NumDirectWideReq;

        /// Indicates corresponding narrow requestor supports read/write (0 for read-only/write-only)
        bit [`MAX_NUM_NARROW_REQ-1:0] AxiNarrowRW;
        /// Indicates corresponding narrow requestor supports read/write (0 for read-only/write-only)
        bit [`MAX_NUM_WIDE_REQ-1:0] AxiWideRW;

        /// Spill Narrow
        int unsigned SpillAxiNarrowReqEntry;
        int unsigned SpillAxiNarrowRspEntry;
        int unsigned SpillNarrowReqRouted;
        int unsigned SpillNarrowRspRouted;
        /// Spill Wide
        int unsigned SpillAxiWideReqEntry;
        int unsigned SpillAxiWideRspEntry;
        int unsigned SpillWideReqRouted;
        int unsigned SpillWideRspRouted;

        /// Spill at Bank
        int unsigned SpillReqBank;
        int unsigned SpillRspBank;

        /// Banking Factor for the Wide Ports (power of 2)
        int unsigned NumNarrowBanks;
        int unsigned WordsPerBank;
        int unsigned BankAccessLatency;
    } mem_cfg_t;

function mem_cfg_t default_mem_cfg();
    mem_cfg_t cfg;
    cfg.AddrWidth = 32;
    cfg.NarrowDataWidth = 32;
    cfg.WideDataWidth = 32;
    cfg.AxiNarrowIdWidth = 4;
    cfg.AxiWideIdWidth = 4;
    cfg.NumAxiNarrowReq = 0;
    cfg.NumDirectNarrowReq = 0;
    cfg.NumAxiWideReq = 0;
    cfg.NumDirectWideReq = 0;
    cfg.AxiNarrowRW = '0;
    cfg.AxiWideRW = '0;
    cfg.SpillAxiNarrowReqEntry = 0;
    cfg.SpillAxiNarrowRspEntry = 0;
    cfg.SpillNarrowReqRouted = 0;
    cfg.SpillNarrowRspRouted = 0;
    cfg.SpillAxiWideReqEntry = 0;
    cfg.SpillAxiWideRspEntry = 0;
    cfg.SpillWideReqRouted = 0;
    cfg.SpillWideRspRouted = 0;
    cfg.SpillReqBank = 0;
    cfg.SpillRspBank = 0;
    cfg.NumNarrowBanks = 1;
    cfg.WordsPerBank = 1024;
    cfg.BankAccessLatency = 1;
    return cfg;
endfunction : default_mem_cfg

endpackage : memory_island_pkg