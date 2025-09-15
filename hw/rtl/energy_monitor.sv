// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Module description:
// Energy monitor of the Ising solver
//
// Parameters:
// - BITJ: bit precision of J
// - DATAJ: number of bits of the input J data
// - ADDRJ: number of bits of address for J
// - DATASPIN: number of bits of spins
// - ENERGY_BIT: bit precision of energy per spin
// - ENERGY_LOCAL:
// - ENERGY_TOTAL_BIT: bit precision of total energy value

`include third_parties/cheshire/.bender/git/checkouts/common_cells-7f7ae0f5e6bf7fb5/include/common_cells/registers.svh

module energy_monitor #(
    parameter int BITJ = 4,
    parameter int DATAJ = 256 * BITJ,
    parameter int ADDRJ = 8,
    parameter int DATASPIN = 256,
    parameter int ENERGY_BIT = 13,
    parameter int ENERGY_LOCAL = DATASPIN * ENERGY_BIT,
    parameter int ENERGY_TOTAL_BIT = 15,
)(
    input logic clk_i, // input clock signal
    input logic rst_ni, // asynchornous reset, active low
    input logic wen_ji,
    input logic [ADDRJ-1:0] waddr_ji,
    input logic signed [DATAJ-1:0] wdata_ji,
    input logic ren_ji,
    input logic [ADDRJ-1:0] raddr_ji,
    output logic signed [DATAJ-1:0] rdata_jo,

    input logic wvalid_spin_i,
    output logic wready_spin_o,
    input logic [DATASPIN-1:0] wdata_spin_i,

    output logic rvalid_spin_o,
    input logic rready_spin_o,
    output logic [DATASPIN-1:0] rdata_spin_o,
    output logic signed [ENERGY_LOCAL-1:0] local_energy_o,
    output logic signed [ENERGY_TOTAL_BIT-1:0] total_energy_o,
);



endmodule