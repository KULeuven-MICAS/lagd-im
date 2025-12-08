// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

// Package for LAGD system-wide types and hardware generation

`include "lagd_config.svh"
`include "lagd_platform.svh"
`include "lagd_define.svh"

package lagd_pkg;

    // Definitions
    localparam int unsigned SpihNumCs = cheshire_pkg::SpihNumCs;
    localparam int unsigned SlinkNumChan = cheshire_pkg::SlinkNumChan;
    localparam int unsigned SlinkNumLanes = cheshire_pkg::SlinkNumLanes;

    // LAGD AXI index map /////////////////////////////////////
    
    typedef struct packed {
        cheshire_pkg::byte_bt L2_MEM;
        cheshire_pkg::byte_bt STACK_MEM; 
        cheshire_pkg::byte_bt ISING_CORES_BASE;
    } lagd_slv_idx_e;
    
    localparam lagd_slv_idx_e LagdSlvIdxEnum = '{
        L2_MEM: 0,
        STACK_MEM: 1,
        ISING_CORES_BASE: 2
    };

    typedef cheshire_pkg::byte_bt [2**(cheshire_pkg::MaxExtAxiSlvWidth)-1:0] lagd_slv_idx_map_t;

    function automatic lagd_slv_idx_map_t gen_lagd_slv_idx_map(lagd_slv_idx_e IdxMap);
        lagd_slv_idx_map_t idx_map;
        int unsigned idx;
        // Map slave IDs to cores
        // Slave ID 0 is reserved for L2 memory
        idx_map[IdxMap.L2_MEM] = IdxMap.L2_MEM; // L2 memory
        // Slave ID 1 is reserved for CVA6 stack memory
        idx_map[IdxMap.STACK_MEM] = IdxMap.STACK_MEM; // CVA6 stack memory
        // cores start from ID 2
        for (int unsigned i = 0; i < `NUM_ISING_CORES; i++) begin
            idx = $unsigned(IdxMap.ISING_CORES_BASE) + i;
            idx_map[idx] = idx;
        end
        return idx_map;
    endfunction : gen_lagd_slv_idx_map

    localparam lagd_slv_idx_map_t LagdSlvIdxMap = gen_lagd_slv_idx_map(LagdSlvIdxEnum);
    ////////////////////////////////////////////////////////////

    // LAGD AXI address map ////////////////////////////////////
    typedef cheshire_pkg::doub_bt [2**(cheshire_pkg::MaxExtAxiSlvWidth)-1:0] lagd_slv_addr_map_t;

    function automatic lagd_slv_addr_map_t gen_lagd_slv_start_addr(lagd_slv_idx_e Idx);
        lagd_slv_addr_map_t addr_map;
        int unsigned idx;
        // L2 memory
        addr_map[Idx.L2_MEM] = `L2_MEM_BASE_ADDR;
        // CVA6 stack memory
        addr_map[Idx.STACK_MEM] = `STACK_BASE_ADDR;
        // Ising cores
        for (int unsigned i = 0; i < `NUM_ISING_CORES; i++) begin
            idx = $unsigned(Idx.ISING_CORES_BASE + i);
            addr_map[idx] = $unsigned(`IC_MEM_BASE_ADDR + (i)*`IC_L1_MEM_LIMIT);
        end
        return addr_map;
    endfunction : gen_lagd_slv_start_addr

    function automatic lagd_slv_addr_map_t gen_lagd_slv_end_addr(lagd_slv_idx_e Idx);
        lagd_slv_addr_map_t addr_map;
        int unsigned idx;
        // L2 memory
        addr_map[Idx.L2_MEM] = $unsigned(`L2_MEM_BASE_ADDR + `L2_MEM_SIZE_B - 1);
        // CVA6 stack memory
        addr_map[Idx.STACK_MEM] = $unsigned(`STACK_BASE_ADDR + `STACK_SIZE_B - 1);
        // Ising cores
        localparam int unsigned ISING_END_ADDR_OFFSET = $unsigned(`IC_MEM_BASE_ADDR + 
            `IC_L1_MEM_SIZE_B);
        for (int unsigned i = 0; i < `NUM_ISING_CORES; i++) begin
            idx = $unsigned(Idx.ISING_CORES_BASE + i);
            addr_map[idx] = $unsigned(ISING_END_ADDR_OFFSET + (i+1)*`IC_L1_MEM_LIMIT - 1);
        end
        return addr_map;
    endfunction : gen_lagd_slv_end_addr

    localparam lagd_slv_addr_map_t LagdSlvAddrStart = gen_lagd_slv_start_addr(LagdSlvIdxEnum);
    localparam lagd_slv_addr_map_t LagdSlvAddrEnd   = gen_lagd_slv_end_addr(LagdSlvIdxEnum);
    ////////////////////////////////////////////////////////////

    // LAGD Regs index map /////////////////////////////////////

    typedef struct packed {
        cheshire_pkg::byte_bt ISING_CORES_BASE;
    } lagd_reg_idx_e;
    
    localparam lagd_reg_idx_e LagdRegIdxEnum = '{
        ISING_CORES_BASE: 0
    };

    typedef cheshire_pkg::byte_bt [2**(cheshire_pkg::MaxExtRegSlvWidth)-1:0] lagd_reg_idx_map_t;

    function automatic lagd_reg_idx_map_t gen_lagd_reg_idx_map(lagd_reg_idx_e IdxMap);
        lagd_reg_idx_map_t idx_map;
        // Map reg IDs to cores
        int unsigned idx;
        for (int unsigned i = 0; i < `NUM_ISING_CORES; i++) begin
            idx = $unsigned(IdxMap.ISING_CORES_BASE + i);
            idx_map[idx] = idx;
        end
        return idx_map;
    endfunction : gen_lagd_reg_idx_map

    localparam lagd_reg_idx_map_t LagdRegIdxMap = gen_lagd_reg_idx_map(LagdRegIdxEnum);
    ////////////////////////////////////////////////////////////

    // LAGD Regs address map ///////////////////////////////////

    typedef cheshire_pkg::doub_bt [2**(cheshire_pkg::MaxExtRegSlvWidth)-1:0] lagd_reg_addr_map_t;

    function automatic lagd_reg_addr_map_t gen_lagd_reg_start_addr(lagd_reg_idx_e Idx);
        lagd_reg_addr_map_t addr_map;
        // Ising cores registers
        int unsigned idx;
        for (int unsigned i = 0; i < `NUM_ISING_CORES; i++) begin
            idx = $unsigned(Idx.ISING_CORES_BASE + i);
            addr_map[idx] = $unsigned(`IC_REGS_BASE_ADDR + (i)*`IC_NUM_REGS);
        end
        return addr_map;
    endfunction : gen_lagd_reg_start_addr

    function automatic lagd_reg_addr_map_t gen_lagd_reg_end_addr(lagd_reg_idx_e Idx);
        lagd_reg_addr_map_t addr_map;
        // Ising cores registers
        for (int unsigned i = 0; i < `NUM_ISING_CORES; i++) begin
            addr_map[i] = $unsigned(`IC_REGS_BASE_ADDR + (i+1)*`IC_NUM_REGS - 1);
        end
        return addr_map;
    endfunction : gen_lagd_reg_end_addr

    localparam lagd_reg_addr_map_t LagdRegAddrStart = gen_lagd_reg_start_addr(LagdRegIdxEnum);
    localparam lagd_reg_addr_map_t LagdRegAddrEnd = gen_lagd_reg_end_addr(LagdRegIdxEnum);
    ////////////////////////////////////////////////////////////
    

    // Cheshire configuration
    function automatic cheshire_pkg::cheshire_cfg_t gen_cheshire_cfg();
        cheshire_pkg::cheshire_cfg_t cfg = cheshire_pkg::DefaultCfg;
        // CVA6 parameters
        // default cfg not present in checkedout cva6 repo
        //cfg.Cva6RASDepth = ariane_pkg::ArianeDefaultCfg.RASDepth;
        //cfg.Cva6BTBEntries = ariane_pkg::ArianeDefaultCfg.BTBEntries;
        //cfg.Cva6BHTEntries = ariane_pkg::ArianeDefaultCfg.BHTEntries;
        cfg.Cva6NrPMPEntries = 0;
        cfg.Cva6ExtCieLength = 'h1000_0000;
        cfg.Cva6ExtCieOnTop = 1'b0;
        // Harts
        cfg.NumCores = 1;           // Only 1 core
        cfg.CoreMaxTxns = 8;        // Max 8 transactions per core
        cfg.CoreMaxTxnsPerId = 2;   // Max 2 transactions per ID
        cfg.CoreUserAmoOffs = 0;    // No user AMO bits
        // Interrupts
        cfg.NumExtInIntrs = 0;  // No of external interruptible harts (e.g., CPU cores)
        // TODO check the meaning of other parameters
        // Interconnect // TODO check how the User fields are used
        cfg.AddrWidth = `CVA6_ADDR_WIDTH;
        cfg.AxiDataWidth = `LAGD_AXI_DATA_WIDTH;  // 64-bit AXI data bus
        // Real Time Clock reference frequency
        cfg.RtcFreq = 32_768; // 32.768 kHz RTC
        // Features
        cfg.Bootrom = 1;
        cfg.Uart = 1;
        cfg.I2c = 0;
        cfg.SpiHost = 0;
        cfg.Gpio = 0;
        cfg.Dma = 1;
        cfg.SerialLink = 1;
        cfg.Vga = 0;
        cfg.Usb = 0;
        cfg.AxiRt = 0;
        cfg.Clic = 0;
        cfg.IrqRouter = 0;
        cfg.BusErr = 1;
        // Debug  module keeps defaults
        // no LLC
        cfg.LlcNotBypass = 0;
        cfg.LlcOutConnect = 0;
        // Serial Link parameters are defaults
        // DMA config defaults are defaults
        // External AXI ports
        cfg.AxiExtNumSlv = $unsigned(`LAGD_NUM_AXI_SLV);
        cfg.AxiExtNumMst = $unsigned(`LAGD_NUM_AXI_MST);
        cfg.AxiExtNumRules = $unsigned(`LAGD_NUM_AXI_SLV);
        cfg.AxiExtRegionIdx = LagdSlvIdxMap;
        cfg.AxiExtRegionStart = LagdSlvAddrStart;
        cfg.AxiExtRegionEnd = LagdSlvAddrEnd;
        // External register slaves
        cfg.RegExtNumSlv = `LAGD_NUM_REG_SLV;
        cfg.RegExtNumRules = `LAGD_NUM_REG_SLV;
        cfg.RegExtRegionIdx = LagdRegIdxMap;
        cfg.RegExtRegionStart = LagdRegAddrStart;
        cfg.RegExtRegionEnd = LagdRegAddrEnd;

        return cfg;
    endfunction : gen_cheshire_cfg
    localparam cheshire_pkg::cheshire_cfg_t CheshireCfg = gen_cheshire_cfg();

    ///////////////////////////////////////
    ////////// Static assertions //////////
    ///////////////////////////////////////

    // Check that the number of cores can be encoded in the AXI Slave ID width
    `PACKAGE_ASSERT(cheshire_pkg::MaxExtAxiSlvWidth >= $clog2(`NUM_ISING_CORES + 2))
    // Check that the number of cores can be encoded in the Reg Slave ID width
    `PACKAGE_ASSERT(cheshire_pkg::MaxExtRegSlvWidth >= $clog2(`NUM_ISING_CORES))
    // Check that the memory per core is not larger than the maximum allowed
    `PACKAGE_ASSERT(`L1_J_MEM_SIZE_B <= `IC_L1_MEM_LIMIT)
    `PACKAGE_ASSERT(`L1_FLIP_MEM_SIZE_B <= `IC_L1_MEM_LIMIT)


endpackage : lagd_pkg

// Package for Ising logic configuration and definitions
package ising_logic_pkg;

    typedef struct packed {
        /// Number of Spins
        int unsigned NumSpin;
        /// Bit width for J couplings
        int unsigned BitJ;
        /// Bit width for H fields
        int unsigned BitH;
        /// Bit width for scaling
        int unsigned ScalingBit;
        /// Parallelism factor
        int unsigned Parallelism;
        /// Total energy bit width
        int unsigned EnergyTotalBit;
        /// Depth of the flip icon memory
        int unsigned FlipIconDepth;
        /// Config counter bitwidth
        int unsigned CfgCounterBitwidth;
        /// Spin depth
        int unsigned SpinDepth;
        /// Little endian flag
        bit LittleEndian;
        /// Pipeline at energy monitor interface
        bit PipesIntf;
        /// Pipeline in adder tree of energy monitor
        bit PipesMid;
        /// Synchronizer pipe depth
        int unsigned SynchronizerPipeDepth;
    } ising_logic_cfg_t;
    localparam ising_logic_cfg_t IsingLogicCfg = '{
        NumSpin : `NUM_SPIN,
        BitJ    : `BIT_J,
        BitH    : `BIT_H,
        ScalingBit: `SCALING_BIT,
        Parallelism: `PARALLELISM,
        EnergyTotalBit: `ENERGY_TOTAL_BIT,
        FlipIconDepth : `FLIP_ICON_DEPTH,
        CfgCounterBitwidth : 16,
        SpinDepth: 2,
        LittleEndian: 0,
        PipesIntf: 1, // pipeline at energy monitor interface
        PipesMid: 1, // pipeline in adder tree of energy monitor
        SynchronizerPipeDepth: `SYNCH_PIPE_DEPTH
    };

endpackage: ising_logic_pkg