// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Jiacong Sun <jiacong.sun@esat.kuleuven.be>
//
// FPGA synthesizable stub for the `galena` analog macro.
//
// The real `galena` is an analog macro (black-box hard macro for synthesis,
// behavioural model for simulation). Neither can be mapped to FPGA fabric:
// the behavioural model in hw/tb/models/galena/galena.sv uses initial/forever,
// real-valued #delays, $urandom, file I/O, and clocks flops off data buses,
// and the module has no clock port at all.
//
// This stub replaces it on FPGA. It does NOT model the Ising compute: the
// ising cores are kept present (so the AXI/register address map matches
// silicon) but inert. That is sufficient for SPI-slave / JTAG / UART bring-up,
// where the ising cores are never triggered.
//
// wbl_read_o / wblb_read_o are driven to deterministic constants (loop-free,
// X-free); a combinational pass-through was deliberately avoided on these, as it
// could form a combinational loop through `digital_macro`. bct_read_o, however,
// is tapped combinationally from wbl_i (see the spin-path note below).
//
// --- Why the spin write/readback path is NOT modelled here --------------------
// A functional stub (spin_cache clocked off write_spin_i, gated bct_read_o) was
// tried on 2026-07-16 to exercise the spin path on the board. It elaborated and
// synthesized cleanly (+17k LUTs, timing met), but making bct_read_o functional
// un-prunes the two ising cores' spin datapath (1024-bit wbl muxes, 256-bit
// feedback/readout x2 cores). place_design then reported [Place 46-14] "highly
// congested" (64x64-tile region) and route_design failed after 3-4.7h with
// ~18-19k node overlaps ([Route 35-2]) - even with AltSpreadLogic_high placement.
// Routing it would require either editing the shared compute RTL
// (digital_macro.sv, gating the analog-loop leg for FPGA) or NUM_ISING_CORES=1,
// both out of scope for now. The functional version is preserved in git history
// if the spin path needs to be revisited. bct_read_o is no longer constant: it
// is now tapped combinationally from wbl_i (bct_read_o[i] = wbl_i[BIT_DATA*i +
// SPIN_WBL_OFFSET]) as a lightweight write-bit-line readback. The full
// spin_cache / write_spin path is still not modelled.
//
// Port list is identical to hw/tb/models/galena/galena.sv.

module galena import galena_pkg::*; (
    // --- Analog pins (no driver on FPGA: left high-Z) ---
    inout j_iref_aio,
    inout j_vup_aio,
    inout j_vdn_aio,
    inout h_iref_aio,
    inout h_vup_aio,
    inout h_vdn_aio,
    inout vread_aio,

    // --- Digital pins ---
    input  logic [WBL_WIDTH-1:0] wbl_i,
    input  logic [WBL_WIDTH-1:0] wblb_i,
    input  logic [WBL_WIDTH-1:0] wbl_floating_i,

    input  logic [WWL_WIDTH-1:0] wwl_i,
    input  logic [WWL_WIDTH-1:0] wwl_vdd_i,
    input  logic [WWL_WIDTH-1:0] wwl_vread_i,

    input  logic [NUM_SPIN-1:0]  write_spin_i,
    input  logic [NUM_SPIN-1:0]  feedback_i,

    output logic [WBL_WIDTH-1:0] wbl_read_o,
    output logic [WBL_WIDTH-1:0] wblb_read_o,
    output logic [NUM_SPIN-1:0]  bct_read_o
);

    // Deterministic, loop-free tie-off.
    // wblb_read_o = ~wbl_read_o mirrors the behavioural model (galena.sv:69).
    assign wbl_read_o  = '0;
    assign wblb_read_o = '1;

    for (genvar i = 0; i < NUM_SPIN; i++) begin : g_bct_read
        assign bct_read_o[i] = wbl_i[BIT_DATA*i + SPIN_WBL_OFFSET];
    end

endmodule
