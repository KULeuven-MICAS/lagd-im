// Copyright 2025 KU Leuven.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

// Package for LAGD system-wide parameters and types

`ifndef LAGD_PKG_SVH
`define LAGD_PKG_SVH

`include "lagd_config.svh"
`include "lagd_platform.svh"
`include "lagd_define.svh"

package lagd_pkg;

    // Definitions
    localparam int unsigned SpihNumCs = cheshire_pkg::SpihNumCs;
    localparam int unsigned SlinkNumChan = cheshire_pkg::SlinkNumChan;
    localparam int unsigned SlinkNumLanes = cheshire_pkg::SlinkNumLanes;

    localparam int unsigned ISING_ISLANDS_MEM_SIZE_B = `NUM_ISING_MEM_BLOCKS * `MEM_BLOCK_SIZE_B;

    // LAGD AXI index map /////////////////////////////////////
    typedef enum int unsigned {
        L2_MEM = 0,
        LAGD_ISLAND_BASE = 1
    } lagd_slv_idx_e;
    localparam lagd_slv_idx_e LagdSlvIdxEnum;

    typedef cheshire_pkg::byte_bt [2**(cheshire_pkg::MaxExtAxiSlvWidth)-1:0] lagd_slv_idx_map_t;

    function automatic lagd_slv_idx_map_t gen_lagd_slv_idx_map(lagd_slv_idx_e Idx);
        lagd_slv_idx_map_t idx_map;
        // Map slave IDs to islands
        // Slave ID 0 is reserved for L2 memory
        idx_map[Idx.L2_MEM] = Idx.L2_MEM; // L2 memory
        int unsigned idx;
        for (int i = 0; i <= `NUM_ISING_ISLANDS; i++) begin
            idx = Idx.LAGD_ISLAND_BASE + i;
            map[idx] = idx;
        end
        return map;
    endfunction : gen_lagd_slv_idx_map

    localparam lagd_slv_idx_map_t LagdSlvIdxMap = gen_lagd_slv_idx_map(LagdSlvIdxEnum);
    ////////////////////////////////////////////////////////////

    // LAGD AXI address map ////////////////////////////////////
    typedef cheshire_pkg::doub_bt [2**(cheshire_pkg::MaxExtAxiSlvWidth)-1:0] lagd_slv_addr_map_t;

    function automatic lagd_slv_addr_map_t gen_lagd_slv_start_addr(lagd_slv_idx_e Idx);
        lagd_slv_addr_map_t addr_map;
        // L2 memory
        addr_map[Idx.L2_MEM] = `L2_MEM_BASE_ADDR;
        // Ising islands
        int unsigned idx;
        for (int i = 0; i < `NUM_ISING_ISLANDS; i++) begin
            idx = Idx.LAGD_ISLAND_BASE + i;
            addr_map[idx] = `ISING_ISLANDS_BASE_ADDR + (i)*`MAX_MEM_PER_ISLAND - 1;
        end
        return addr_map;
    endfunction : gen_lagd_slv_start_addr

    function automatic lagd_slv_addr_map_t gen_lagd_slv_end_addr(lagd_slv_idx_e Idx);
        lagd_slv_addr_map_t addr_map;
        // L2 memory
        addr_map[Idx.L2_MEM] = `L2_MEM_BASE_ADDR + `L2_MEM_SIZE_B - 1;
        // Ising islands
        localparam int ISING_END_ADDR_OFFSET = `ISING_ISLANDS_BASE_ADDR + ISING_ISLANDS_MEM_SIZE_B;
        for (int i = 0; i < `NUM_ISING_ISLANDS; i++) begin
            idx = Idx.LAGD_ISLAND_BASE + i;
            addr_map[idx] = ISING_END_ADDR_OFFSET + (i)*`MAX_MEM_PER_ISLAND - 1;
        end
        return addr_map;
    endfunction : gen_lagd_slv_end_addr

    localparam lagd_slv_addr_map_t LagdSlvAddrStart = gen_lagd_slv_start_addr(LagdSlvIdxEnum);
    localparam lagd_slv_addr_map_t LagdSlvAddrEnd   = gen_lagd_slv_end_addr(LagdSlvIdxEnum);
    ////////////////////////////////////////////////////////////

    // LAGD Regs index map /////////////////////////////////////
    typedef enum int unsigned {
        LAGD_ISLAND_BASE = 0
    } lagd_reg_idx_e;
    localparam lagd_reg_idx_e LagdRegIdxEnum;

    typedef cheshire_pkg::byte_bt [2**(cheshire_pkg::MaxExtRegSlvWidth)-1:0] lagd_reg_idx_map_t;

    function automatic lagd_reg_idx_map_t gen_lagd_reg_idx_map(lagd_reg_idx_e Idx);
        lagd_reg_idx_map_t idx_map;
        // Map reg IDs to islands
        int unsigned idx;
        for (int i = 0; i <= `NUM_ISING_ISLANDS; i++) begin
            idx = Idx.LAGD_ISLAND_BASE + i;
            map[idx] = idx;
        end
        return map;
    endfunction : gen_lagd_slv_idx_map

    localparam lagd_slv_idx_map_t LagdSlvIdxMap = gen_lagd_slv_idx_map(LagdRegIdxEnum);
    ////////////////////////////////////////////////////////////

    // LAGD Regs address map ///////////////////////////////////

    typedef cheshire_pkg::doub_bt [2**(cheshire_pkg::MaxExtRegSlvWidth)-1:0] lagd_reg_addr_map_t;

    function automatic lagd_reg_addr_map_t gen_lagd_reg_start_addr(lagd_reg_idx_e Idx);
        lagd_reg_addr_map_t addr_map;
        // Ising islands registers
        int unsigned idx;
        for (int i = 0; i < `NUM_ISING_ISLANDS; i++) begin
            idx = Idx.LAGD_ISLAND_BASE + i;
            addr_map[idx] = `LAGD_REGS_BASE_ADDR + (i)*`REGS_PER_ISLAND;
        end
        return addr_map;
    endfunction : gen_lagd_reg_start_addr

    function automatic lagd_reg_addr_map_t gen_lagd_reg_end_addr(lagd_reg_idx_e Idx);
        lagd_reg_addr_map_t addr_map;
        // Ising islands registers
        for (int i = 0; i < `NUM_ISING_ISLANDS; i++) begin
            addr_map[i] = `LAGD_REGS_BASE_ADDR + (i+1)*`REGS_PER_ISLAND - 1;
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
        cfg.Cva6RASDepth = ariane_pkg::ArianeDefaultCfg.RASDepth;
        cfg.Cva6BTBEntries = ariane_pkg::ArianeDefaultCfg.BTBEntries;
        cfg.Cva6BHTEntries = ariane_pkg::ArianeDefaultCfg.BHTEntries;
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
        cfg.AddrWidth = 48;
        cfg.AxiDataWidth = 64;  // 64-bit AXI data bus (TODO check increase or make another bus?)
        // Real Time Clock reference frequency
        cfg.RtcFreq = 32_768; // 32.768 kHz RTC
        // Features
        cfg.Bootrom = 1;
        cfg.Uart = 1;
        cfg.I2c = 0;
        cfg.SpiHost = 1;
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
        cfg.AxiExtNumSlv = `NUM_ISING_ISLANDS + 1; // +1 for L2 memory
        cfg.AxiExtNumMst = `NUM_ISING_ISLANDS;
        cfg.AxiExtNumRules = `NUM_ISING_ISLANDS + 1; // +1 for L2 memory
        cfg.AxiExtRegionIdx = LagdSlvIdxMap;
        cfg.AxiExtRegionStart = LagdSlvAddrStart;
        cfg.AxiExtRegionEnd = LagdSlvAddrEnd;
        // External register slaves
        cfg.RegExtNumSlv = `NUM_ISING_ISLANDS;
        cfg.RegExtNumRules = `NUM_ISING_ISLANDS;
        cfg.RegExtRegionIdx = LagdRegIdxMap;
        cfg.RegExtRegionStart = LagdRegAddrStart;
        cfg.RegExtRegionEnd = LagdRegAddrEnd;

        return cfg;
    endfunction : gen_cheshire_cfg
    localparam cheshire_pkg::cheshire_cfg_t CheshireCfg = gen_cheshire_cfg();

    ///////////////////////////////////////
    ////////// Static assertions //////////
    ///////////////////////////////////////

    // Check that the number of islands can be encoded in the AXI Slave ID width
    `PACKAGE_ASSERT(cheshire_pkg::MaxExtAxiSlvWidth >= $clog2(`NUM_ISING_ISLANDS + 1))
    // Check that the number of islands can be encoded in the AXI Master ID width
    `PACKAGE_ASSERT(cheshire_pkg::MaxExtAxiMstWidth >= $clog2(`NUM_ISING_ISLANDS))
    // Check that the number of islands can be encoded in the Reg Slave ID width
    `PACKAGE_ASSERT(cheshire_pkg::MaxExtRegSlvWidth >= $clog2(`NUM_ISING_ISLANDS))
    // Check that the memory per island is not larger than the maximum allowed
    `PACKAGE_ASSERT((`NUM_ISING_MEM_BLOCKS * `MEM_BLOCK_SIZE_B) <= `MAX_MEM_PER_ISLAND)


endpackage : lagd_pkg

`endif // LAGD_PKG_SVH
