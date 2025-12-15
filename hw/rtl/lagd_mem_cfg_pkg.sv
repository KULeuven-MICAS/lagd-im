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
    localparam int unsigned L2WordsPerBank = 2048;
    localparam memory_island_pkg::mem_cfg_t L2MemCfg = '{
        // AddrWidth : `L2_MEM_ADDR_WIDTH,
        AddrWidth : `CVA6_ADDR_WIDTH,
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
        NumNarrowBanks : `L2_MEM_SIZE_B / (`LAGD_AXI_DATA_WIDTH/8) / L2WordsPerBank,
        WordsPerBank : 2048,
        BankAccessLatency : 1
    };

    localparam int unsigned StackWordsPerBank = L2WordsPerBank;
    localparam memory_island_pkg::mem_cfg_t CVA6StackMemCfg = '{
        // AddrWidth : `STACK_ADDR_WIDTH,
        AddrWidth : `CVA6_ADDR_WIDTH,
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
        NumNarrowBanks : `STACK_SIZE_B / (`LAGD_AXI_DATA_WIDTH/8) / StackWordsPerBank,
        WordsPerBank : StackWordsPerBank,
        BankAccessLatency : 1
    };

    // localparam int unsigned IsingCoreJWordsPerBank = `L1_J_MEM_SIZE_B*8/`IC_L1_J_MEM_DATA_WIDTH;
    localparam int unsigned IsingCoreJWordsPerBank = 64;
    localparam int unsigned IsingCoreJNumNarrowBanks = `L1_J_MEM_SIZE_B*8/IsingCoreJWordsPerBank/`LAGD_AXI_DATA_WIDTH;
    
    localparam memory_island_pkg::mem_cfg_t IsingCoreL1MemCfgJ = '{
        AddrWidth           : `CVA6_ADDR_WIDTH,
        NarrowDataWidth     : `LAGD_AXI_DATA_WIDTH,
        WideDataWidth       : `IC_L1_J_MEM_DATA_WIDTH,
        AxiNarrowIdWidth    : `LAGD_AXI_ID_WIDTH,
        AxiWideIdWidth      : `LAGD_AXI_ID_WIDTH,
        NumAxiNarrowReq : 1,
        NumDirectNarrowReq : 0,
        NumAxiWideReq : 0,
        NumDirectWideReq : 1,
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
        NumNarrowBanks : IsingCoreJNumNarrowBanks,
        WordsPerBank : IsingCoreJWordsPerBank,
        BankAccessLatency : 1
    };

    // localparam int unsigned IsingCoreFlipWordsPerBank = `L1_FLIP_MEM_SIZE_B*8/`IC_L1_FLIP_MEM_DATA_WIDTH;
    localparam int unsigned IsingCoreFlipWordsPerBank = 1024;
    localparam int unsigned IsingCoreFlipNumNarrowBanks = `L1_FLIP_MEM_SIZE_B*8/IsingCoreFlipWordsPerBank/`LAGD_AXI_DATA_WIDTH;
    localparam memory_island_pkg::mem_cfg_t IsingCoreL1MemCfgFlip = '{
        AddrWidth           : `CVA6_ADDR_WIDTH,
        NarrowDataWidth     : `LAGD_AXI_DATA_WIDTH,
        WideDataWidth       : `IC_L1_FLIP_MEM_DATA_WIDTH,
        AxiNarrowIdWidth    : `LAGD_AXI_ID_WIDTH,
        AxiWideIdWidth      : `LAGD_AXI_ID_WIDTH,
        NumAxiNarrowReq : 1,
        NumDirectNarrowReq : 0,
        NumAxiWideReq : 0,
        NumDirectWideReq : 1,
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
        NumNarrowBanks : IsingCoreFlipNumNarrowBanks,
        WordsPerBank : IsingCoreFlipWordsPerBank,
        BankAccessLatency : 1
    };

endpackage : lagd_mem_cfg_pkg