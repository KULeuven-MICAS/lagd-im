// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

// Module: memory_island_wrap

// Description:
//      Top-level wrapper for the memory island subsystem. Bridges AXI protocol interfaces 
//      to the memory island's internal memory protocol
//
//      This wrapper handles:
//      - AXI-to-memory protocol conversion (via axi_to_mem_adapter) for narrow and wide ports.
//      - Read/write splitting for AXI ports with independent channels.
//      - Aggregation of AXI-converted and direct memory channels into unified request/response arrays.

// The entire memory island was inspired by:
// https://github.com/pulp-platform/memory_island

// Parameters:
//      Cfg: Configuration struct (type mem_cfg_t, see memory_island_pkg.sv)
//      axi_narrow_req_t / axi_narrow_rsp_t: AXI request/response typedefs for narrow ports.
//      axi_wide_req_t / axi_wide_rsp_t: AXI request/response typedefs for wide ports.
//      mem_narrow_req_t / mem_narrow_rsp_t: Memory protocol typedefs for narrow ports.
//      mem_wide_req_t / mem_wide_rsp_t: Memory protocol typedefs for wide ports (same fields).

// Ports:
//      clk_i: Clock.
//      rst_ni: Active-low reset.
//      AXI Narrow Ports (converted to memory protocol):
//          axi_narrow_req_i[Cfg.NumAxiNarrowReq-1:0]: AXI narrow request inputs.
//          axi_narrow_rsp_o[Cfg.NumAxiNarrowReq-1:0]: AXI narrow response outputs.
//      AXI Wide Ports (converted to memory protocol):
//          axi_wide_req_i[Cfg.NumAxiWideReq-1:0]: AXI wide request inputs.
//          axi_wide_rsp_o[Cfg.NumAxiWideReq-1:0]: AXI wide response outputs.
//      Direct Memory Narrow Ports (bypass AXI conversion):
//          mem_narrow_req_i[Cfg.NumDirectNarrowReq-1:0]: Direct narrow memory requests.
//          mem_narrow_rsp_o[Cfg.NumDirectNarrowReq-1:0]: Direct narrow memory responses.
//      Direct Memory Wide Ports (bypass AXI conversion):
//          mem_wide_req_i[Cfg.NumDirectWideReq-1:0]: Direct wide memory requests.
//          mem_wide_rsp_o[Cfg.NumDirectWideReq-1:0]: Direct wide memory responses.

// Internal Architecture:
//  1. AXI-to-Memory Conversion (axi_to_mem_adapter instances).
//  2. Entry-Point Pipeline Stages (mem_multicut instances).
//  3. Channel Aggregation.
//  4. Core Memory Island instance.

// Testing:
//      No verification yet.
//      Synthesis only.

`include "lagd_platform.svh"

module memory_island_wrap import memory_island_pkg::*; #(
    parameter mem_cfg_t Cfg = default_mem_cfg(),

    parameter type axi_narrow_req_t = logic,
    parameter type axi_narrow_rsp_t = logic,
    
    parameter type axi_wide_req_t = logic,
    parameter type axi_wide_rsp_t = logic,

    parameter type mem_narrow_req_t = logic,
    parameter type mem_narrow_rsp_t = logic,

    parameter type mem_wide_req_t = logic,
    parameter type mem_wide_rsp_t = logic,

    // Derived parameters - Do not override
    parameter int unsigned NumAxiNarrowReqSafe = `ZWIDTH_SAFE(Cfg.NumAxiNarrowReq),
    parameter int unsigned NumAxiWideReqSafe = `ZWIDTH_SAFE(Cfg.NumAxiWideReq),
    parameter int unsigned NumDirectNarrowReqSafe = `ZWIDTH_SAFE(Cfg.NumDirectNarrowReq),
    parameter int unsigned NumDirectWideReqSafe = `ZWIDTH_SAFE(Cfg.NumDirectWideReq)
)(
    input logic clk_i,
    input logic rst_ni,

    input axi_narrow_req_t [NumAxiNarrowReqSafe-1:0] axi_narrow_req_i,
    output axi_narrow_rsp_t [NumAxiNarrowReqSafe-1:0] axi_narrow_rsp_o,

    input axi_wide_req_t [NumAxiWideReqSafe-1:0] axi_wide_req_i,
    output axi_wide_rsp_t [NumAxiWideReqSafe-1:0] axi_wide_rsp_o,

    input mem_narrow_req_t [NumDirectNarrowReqSafe-1:0] mem_narrow_req_i,
    output mem_narrow_rsp_t [NumDirectNarrowReqSafe-1:0] mem_narrow_rsp_o,

    input mem_wide_req_t [NumDirectWideReqSafe-1:0] mem_wide_req_i,
    output mem_wide_rsp_t [NumDirectWideReqSafe-1:0] mem_wide_rsp_o
);

    // Narrow AXI requests and responses for adapter and spilling
    localparam int unsigned axi_rw_narrow_reqs = Cfg.NumAxiNarrowReq + $countones(Cfg.AxiNarrowRW);
    localparam int unsigned axi_rw_narrow_reqs_safe = (axi_rw_narrow_reqs > 0) ? axi_rw_narrow_reqs : 1;
    mem_narrow_req_t [axi_rw_narrow_reqs_safe-1:0] mem_narrow_req_from_axi, mem_narrow_req_from_axi_q1;
    mem_narrow_rsp_t [axi_rw_narrow_reqs_safe-1:0] mem_narrow_rsp_to_axi, mem_narrow_rsp_to_axi_q1;

    // Wide AXI requests and responses for adapter and spilling
    localparam int unsigned axi_rw_wide_reqs = Cfg.NumAxiWideReq + $countones(Cfg.AxiWideRW);
    localparam int unsigned axi_rw_wide_reqs_safe = (axi_rw_wide_reqs > 0) ? axi_rw_wide_reqs : 1;
    mem_wide_req_t [axi_rw_wide_reqs_safe-1:0] mem_wide_req_from_axi, mem_wide_req_from_axi_q1;
    mem_wide_rsp_t [axi_rw_wide_reqs_safe-1:0] mem_wide_rsp_to_axi, mem_wide_rsp_to_axi_q1;

    // Full memory island requests and responses narrow
    localparam int unsigned total_narrow_reqs = axi_rw_narrow_reqs + Cfg.NumDirectNarrowReq;
    localparam int unsigned total_narrow_reqs_safe = (total_narrow_reqs > 0) ? total_narrow_reqs : 1;
    mem_narrow_req_t [total_narrow_reqs_safe-1:0] mem_narrow_req;
    mem_narrow_rsp_t [total_narrow_reqs_safe-1:0] mem_narrow_rsp;
    
    //=============================================================================================
    // *Narrow* requests and responses aggregation
    //=============================================================================================

    generate // Narrow responses to AXI
        if (axi_rw_narrow_reqs > 0) begin : gen_narrow_rsp_axi_assign
            assign mem_narrow_rsp_to_axi = mem_narrow_rsp[total_narrow_reqs-1:Cfg.NumDirectNarrowReq];
        end else begin : gen_narrow_rsp_axi_empty
            assign mem_narrow_rsp_to_axi = '0;
        end
    endgenerate

    generate // Narrow responses to direct access
        if (Cfg.NumDirectNarrowReq > 0) begin : gen_narrow_rsp_direct_assign
            assign mem_narrow_rsp_o = mem_narrow_rsp[Cfg.NumDirectNarrowReq-1:0];
        end else begin : gen_narrow_rsp_direct_empty
            assign mem_narrow_rsp_o = '0;
        end
    endgenerate
    
    generate // Narrow requests aggregation
        if (total_narrow_reqs > 0) begin : gen_narrow_req_assign
            if (axi_rw_narrow_reqs > 0 && Cfg.NumDirectNarrowReq > 0) begin
                assign mem_narrow_req = {mem_narrow_req_from_axi_q1[axi_rw_narrow_reqs-1:0], mem_narrow_req_i};
            end else if (axi_rw_narrow_reqs > 0) begin
                assign mem_narrow_req = mem_narrow_req_from_axi_q1[axi_rw_narrow_reqs-1:0];
            end else if (Cfg.NumDirectNarrowReq > 0) begin
                assign mem_narrow_req = mem_narrow_req_i;
            end
        end else begin : gen_narrow_req_empty
            assign mem_narrow_req = '0;
        end
    endgenerate

    //=============================================================================================
    // *Wide* requests and responses aggregation
    //=============================================================================================

    // Full memory island requests and responses wide
    localparam int unsigned total_wide_reqs = axi_rw_wide_reqs + Cfg.NumDirectWideReq;
    localparam int unsigned total_wide_reqs_safe = (total_wide_reqs > 0) ? total_wide_reqs : 1;
    mem_wide_req_t [total_wide_reqs_safe-1:0] mem_wide_req;
    mem_wide_rsp_t [total_wide_reqs_safe-1:0] mem_wide_rsp;
    
    generate // Wide responses to AXI
        if (axi_rw_wide_reqs > 0) begin : gen_wide_rsp_axi_assign
            assign mem_wide_rsp_to_axi = mem_wide_rsp[total_wide_reqs-1:Cfg.NumDirectWideReq];
        end else begin : gen_wide_rsp_axi_empty
            assign mem_wide_rsp_to_axi = '0;
        end
    endgenerate

    generate // Wide responses to direct access
        if (Cfg.NumDirectWideReq > 0) begin : gen_wide_rsp_direct_assign
            assign mem_wide_rsp_o = mem_wide_rsp[Cfg.NumDirectWideReq-1:0];
        end else begin : gen_wide_rsp_direct_empty
            assign mem_wide_rsp_o = '0;
        end
    endgenerate

    generate // Wide requests aggregation
        if (total_wide_reqs > 0) begin : gen_wide_req_assign
            if (axi_rw_wide_reqs > 0 && Cfg.NumDirectWideReq > 0) begin
                assign mem_wide_req = {mem_wide_req_from_axi_q1[axi_rw_wide_reqs-1:0], mem_wide_req_i};
            end else if (axi_rw_wide_reqs > 0) begin
                assign mem_wide_req = mem_wide_req_from_axi_q1[axi_rw_wide_reqs-1:0];
            end else if (Cfg.NumDirectWideReq > 0) begin
                assign mem_wide_req = mem_wide_req_i;
            end
        end else begin : gen_wide_req_empty
            assign mem_wide_req = '0;
        end
    endgenerate
    // Spill latencies
    localparam int unsigned NarrowMemRspLatency = Cfg.SpillAxiNarrowReqEntry +
        Cfg.SpillNarrowReqRouted + Cfg.SpillReqBank + Cfg.SpillRspBank +
        Cfg.SpillNarrowRspRouted + Cfg.SpillAxiNarrowRspEntry + Cfg.BankAccessLatency;

    localparam int unsigned WideMemRspLatency = Cfg.SpillAxiWideReqEntry +
        Cfg.SpillWideReqRouted + Cfg.SpillReqBank + Cfg.SpillRspBank +
        Cfg.SpillWideRspRouted + Cfg.SpillAxiWideRspEntry + Cfg.BankAccessLatency;
    
    // =============================================================================================
    // Axi to mem adapters
    // =============================================================================================

    generate // Axi to mem adapters narrow
        if (Cfg.NumAxiNarrowReq > 0) begin : gen_axi_narrow_adapters
            for (genvar i = 0; i < Cfg.NumAxiNarrowReq; i++) begin: axi_narrow_adapter
                localparam int unsigned id = i + $countones(Cfg.AxiNarrowRW[i:0]);
                axi_to_mem_adapter #(
                    .axi_req_t(axi_narrow_req_t),
                    .axi_rsp_t(axi_narrow_rsp_t),
                    .mem_req_t(mem_narrow_req_t),
                    .mem_rsp_t(mem_narrow_rsp_t),
                    .AddrWidth(Cfg.AddrWidth),
                    .DataWidth(Cfg.NarrowDataWidth),
                    .IdWidth(Cfg.AxiNarrowIdWidth),
                    .BufDepth(1 + NarrowMemRspLatency),
                    .ReadWrite(Cfg.AxiNarrowRW[i])
                ) u_axi_to_mem_adapter_narrow (
                    .clk_i(clk_i),
                    .rst_ni(rst_ni),
                    .axi_req_i(axi_narrow_req_i[i]),
                    .axi_rsp_o(axi_narrow_rsp_o[i]),
                    .mem_req_o(mem_narrow_req_from_axi[id-:1+Cfg.AxiNarrowRW[i]]),
                    .mem_rsp_i(mem_narrow_rsp_to_axi_q1[id-:1+Cfg.AxiNarrowRW[i]])
                );
            end
        end else begin : gen_axi_narrow_adapters_empty
            assign axi_narrow_rsp_o = '0;
            assign mem_narrow_req_from_axi = '0;
        end
    endgenerate
    
    generate // Axi to mem adapters wide
        if (Cfg.NumAxiWideReq > 0) begin : gen_axi_wide_adapters
            for (genvar i = 0; i < Cfg.NumAxiWideReq; i++) begin: axi_wide_adapter
                localparam int unsigned id = i + $countones(Cfg.AxiWideRW[i:0]);
                axi_to_mem_adapter #(
                    .axi_req_t(axi_wide_req_t),
                    .axi_rsp_t(axi_wide_rsp_t),
                    .mem_req_t(mem_wide_req_t),
                    .mem_rsp_t(mem_wide_rsp_t),
                    .AddrWidth(Cfg.AddrWidth),
                    .DataWidth(Cfg.WideDataWidth),
                    .IdWidth(Cfg.AxiWideIdWidth),
                    .BufDepth(1 + WideMemRspLatency),
                    .ReadWrite(Cfg.AxiWideRW[i])
                ) u_axi_to_mem_adapter_wide (
                    .clk_i(clk_i),
                    .rst_ni(rst_ni),
                    .axi_req_i(axi_wide_req_i[i]),
                    .axi_rsp_o(axi_wide_rsp_o[i]),
                    .mem_req_o(mem_wide_req_from_axi[id-:1+Cfg.AxiWideRW[i]]),
                    .mem_rsp_i(mem_wide_rsp_to_axi_q1[id-:1+Cfg.AxiWideRW[i]])
                );
            end
        end else begin : gen_axi_wide_adapters_empty
            assign axi_wide_rsp_o = '0;
            assign mem_wide_req_from_axi = '0;
        end
    endgenerate

    // =============================================================================================
    // Entry spilling
    // =============================================================================================
    generate // Narrow spilling
        if (axi_rw_narrow_reqs > 0) begin : gen_spill_narrow_entry
            for (genvar i = 0; i < axi_rw_narrow_reqs; i++) begin: spill_narrow_entry
                mem_multicut #(
                    .AddrWidth(Cfg.AddrWidth),
                    .DataWidth(Cfg.NarrowDataWidth),
                    .NumCutsReq(Cfg.SpillAxiNarrowReqEntry),
                    .NumCutsRsp(Cfg.SpillAxiNarrowRspEntry),
                    .mem_req_t(mem_narrow_req_t),
                    .mem_rsp_t(mem_narrow_rsp_t)
                ) u_spill_narrow_entry (
                    .clk_i(clk_i),
                    .rst_ni(rst_ni),
                    .req_i(mem_narrow_req_from_axi[i]),
                    .req_o(mem_narrow_req_from_axi_q1[i]),
                    .rsp_i(mem_narrow_rsp_to_axi[i]),
                    .rsp_o(mem_narrow_rsp_to_axi_q1[i]),
                    .read_ready_i(1'b1),
                    .read_ready_o()
                );
            end
        end else begin : gen_spill_narrow_entry_empty
            assign mem_narrow_req_from_axi_q1 = '0;
            assign mem_narrow_rsp_to_axi_q1 = '0;
        end
    endgenerate

    generate // Wide spilling
        if (axi_rw_wide_reqs > 0) begin : gen_spill_wide_entry
            for (genvar i = 0; i < axi_rw_wide_reqs; i++) begin: spill_wide_entry
                mem_multicut #(
                    .AddrWidth(Cfg.AddrWidth),
                    .DataWidth(Cfg.WideDataWidth),
                    .NumCutsReq(Cfg.SpillAxiWideReqEntry),
                    .NumCutsRsp(Cfg.SpillAxiWideRspEntry),
                    .mem_req_t(mem_wide_req_t),
                    .mem_rsp_t(mem_wide_rsp_t)
                ) u_spill_wide_entry (
                    .clk_i(clk_i),
                    .rst_ni(rst_ni),
                    .req_i(mem_wide_req_from_axi[i]),
                    .req_o(mem_wide_req_from_axi_q1[i]),
                    .rsp_i(mem_wide_rsp_to_axi[i]),
                    .rsp_o(mem_wide_rsp_to_axi_q1[i]),
                    .read_ready_i(1'b1),
                    .read_ready_o()
                );
            end
        end else begin : gen_spill_wide_entry_empty
            assign mem_wide_req_from_axi_q1 = '0;
            assign mem_wide_rsp_to_axi_q1 = '0;
        end
    endgenerate

    // =============================================================================================
    // Memory island core
    // =============================================================================================
    memory_island_core #(
        .mem_narrow_req_t(mem_narrow_req_t),
        .mem_narrow_rsp_t(mem_narrow_rsp_t),
        .mem_wide_req_t(mem_wide_req_t),
        .mem_wide_rsp_t(mem_wide_rsp_t),
        .Cfg(Cfg)
    ) i_memory_island_core (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .mem_narrow_req_i(mem_narrow_req),
        .mem_narrow_rsp_o(mem_narrow_rsp),
        .mem_wide_req_i(mem_wide_req),
        .mem_wide_rsp_o(mem_wide_rsp)
    );

    // ==============================================================================================
    // Assertions
    // ==============================================================================================
    localparam int unsigned total_reqs = total_narrow_reqs + total_wide_reqs;
    `STATIC_ASSERT(
        total_reqs > 0,
        "memory_island_wrap: At least one memory request channel (AXI or direct) must be enabled."
    );

endmodule : memory_island_wrap
