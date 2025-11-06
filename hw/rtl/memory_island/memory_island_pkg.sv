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
        int unsigned SpillNarrowReqEntry;
        int unsigned SpillNarrowRspEntry;
        int unsigned SpillNarrowReqRouted;
        int unsigned SpillNarrowRspRouted;
        /// Spill Wide
        int unsigned SpillWideReqEntry;
        int unsigned SpillWideRspEntry;
        int unsigned SpillWideReqRouted;
        int unsigned SpillWideRspRouted;
        int unsigned SpillWideReqSplit;
        int unsigned SpillWideRspSplit;
        /// Spill at Bank
        int unsigned SpillReqBank;
        int unsigned SpillRspBank;

        /// Relinquish narrow priority after x cycles, 0 for never. Requires SpillNarrowReqRouted==0.
        int unsigned WidePriorityWait;

        /// Banking Factor for the Wide Ports (power of 2)
        int unsigned NumWideBanks;
        /// Extra multiplier for the Narrow banking factor (baseline is WideWidth/NarrowWidth) (power of 2)
        int unsigned NarrowExtraBF;
        /// Words per memory bank. (Total number of banks is (WideWidth/NarrowWidth)*NumWideBanks)
        int unsigned WordsPerBank;
        /// Number of cycles a memory macro takes to respond to a read request
        int unsigned BankAccessLatency;
    } mem_cfg_t;
endpackage : lagd_mem_pkg