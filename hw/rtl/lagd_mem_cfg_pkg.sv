// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

// Package for memory configuration and definitions

`include "lagd_config.svh"
`include "lagd_platform.svh"
`include "lagd_define.svh"

package lagd_mem_cfg_pkg;
    localparam memory_island_pkg::mem_cfg_t L2MemCfg = '{
        AddrWidth : `L2_MEM_ADDR_WIDTH,
        NarrowDataWidth : `LAGD_AXI_DATA_WIDTH,
        WideDataWidth : `LAGD_AXI_DATA_WIDTH,
        AxiNarrowIdWidth : `LAGD_AXI_ID_WIDTH,
        AxiWideIdWidth : `LAGD_AXI_ID_WIDTH,
        NumAxiNarrowReq : 1,
        NumDirectNarrowReq : 0,
        NumAxiWideReq : 0,
        NumDirectWideReq : 0,
        AxiNarrowRW : '0,
        AxiWideRW : '0,
        SpillAxiNarrowReqEntry : 0,
        SpillAxiNarrowRspEntry : 0,
        SpillNarrowReqRouted : 0,
        SpillNarrowRspRouted : 0,
        SpillAxiWideReqEntry : 0,
        SpillAxiWideRspEntry : 0,
        SpillWideReqRouted : 0,
        SpillWideRspRouted : 0,
        SpillReqBank : 0,
        SpillRspBank : 0,
        NumNarrowBanks : 1,
        WordsPerBank : 2048,
        BankAccessLatency : 1
    };

    localparam memory_island_pkg::mem_cfg_t CVA6StackMemCfg = '{
        AddrWidth : `STACK_ADDR_WIDTH,
        NarrowDataWidth : `LAGD_AXI_DATA_WIDTH,
        WideDataWidth : `LAGD_AXI_DATA_WIDTH,
        AxiNarrowIdWidth : `LAGD_AXI_ID_WIDTH,
        AxiWideIdWidth : `LAGD_AXI_ID_WIDTH,
        NumAxiNarrowReq : 1,
        NumDirectNarrowReq : 0,
        NumAxiWideReq : 0,
        NumDirectWideReq : 0,
        AxiNarrowRW : '0,
        AxiWideRW : '0,
        SpillAxiNarrowReqEntry : 0,
        SpillAxiNarrowRspEntry : 0,
        SpillNarrowReqRouted : 0,
        SpillNarrowRspRouted : 0,
        SpillAxiWideReqEntry : 0,
        SpillAxiWideRspEntry : 0,
        SpillWideReqRouted : 0,
        SpillWideRspRouted : 0,
        SpillReqBank : 0,
        SpillRspBank : 0,
        WidePriorityWait : 0,
        NumNarrowBanks : 1,
        WordsPerBank : 2048,
        BankAccessLatency : 1
    };

    localparam memory_island_pkg::mem_cfg_t IsingCoreL1MemCfg = '{
        AddrWidth : $clog2(`IC_L1_MEM_SIZE_B),
        NarrowDataWidth : `LAGD_AXI_DATA_WIDTH,
        WideDataWidth : `LAGD_AXI_DATA_WIDTH,
        AxiNarrowIdWidth : `LAGD_AXI_ID_WIDTH,
        AxiWideIdWidth : `LAGD_AXI_ID_WIDTH,
        NumAxiNarrowReq : 1,
        NumDirectNarrowReq : 0,
        NumAxiWideReq : 0,
        NumDirectWideReq : 0,
        AxiNarrowRW : '0,
        AxiWideRW : '0,
        SpillAxiNarrowReqEntry : 0,
        SpillAxiNarrowRspEntry : 0,
        SpillNarrowReqRouted : 0,
        SpillNarrowRspRouted : 0,
        SpillAxiWideReqEntry : 0,
        SpillAxiWideRspEntry : 0,
        SpillWideReqRouted : 0,
        SpillWideRspRouted : 0,
        SpillReqBank : 0,
        SpillRspBank : 0,
        NumNarrowBanks : 1,
        WordsPerBank : 2048,
        BankAccessLatency : 1
    };

endpackage : lagd_mem_cfg_pkg