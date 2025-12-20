// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// Module: flip_engine
//
// Purpose:
// - Apply a per-bit "flip" mask (flip_icon) to incoming spin vectors.
// - Provide AXI-stream-like valid/ready handshakes for input spins (prev_spin_*)
//   and for output flipped spins (flipped_spin_*).
// - Stream flip icons from a read-port (flip_raddr_o / flip_rdata_i) and expose
//   a completion indicator when the address space has been exhausted (icon_finish_o).
// - Support a debug bypass (flip_disable_i) that forwards prev_spin_i
//   unchanged to flipped_spin_o and disables icon reads.
//
// Parameters:
// - DATASPIN               : bit width of each spin vector.
// - FLIP_ICON_DEPTH        : number of flip-icon entries to read.
// - FLIP_ICON_ADDR_DEPTH   : address width for flip-icon reads (derived).
//
// Key behaviour:
// - When en_i is asserted and the input handshake (prev_spin_valid_i & prev_spin_ready_o)
//   completes, the module produces a flipped spin on flipped_spin_o with a corresponding
//   flipped_spin_valid_o valid result. Downstream acceptance is governed by
//   flipped_spin_ready_i.
// - If flip_disable_i is high the module bypasses the XOR and forwards
//   prev_spin_i directly to the output; flip-icon reads are inhibited.
// - flip icons are fetched from the external memory via flip_ren_o / flip_raddr_o.
//   flip_raddr_reg increments on each acknowledged read; it wraps to zero when it
//   reaches FLIP_ICON_DEPTH-1. icon_finish_o is asserted when the last address is
//   read (flip_ren_o while flip_raddr_reg == FLIP_ICON_DEPTH-1).
// - flip reads are enabled (flip_ren_p -> flip_ren_o) when en_i is set and either
//   cmpt_en_i is asserted or a new input spin handshake occurs, provided flush_i
//   and flip_disable_i are not asserted.
// - flush_i clears internal registered state and inhibits activity.
//
// Ports (summary):
// - clk_i, rst_ni         : clock and async active-low reset
// - en_i                  : module-level enable
// - cmpt_en_i             : enable/arm icon streaming (also used to gate reads)
// - flush_i               : synchronous flush/clear of internal state
// - prev_spin_valid_i     : input spin valid
// - prev_spin_i           : input spin vector [DATASPIN-1:0]
// - prev_spin_ready_o     : input spin ready (consumer to producer)
// - flipped_spin_ready_i  : downstream ready for flipped output
// - flipped_spin_o        : output flipped spin vector [DATASPIN-1:0]
// - flipped_spin_valid_o  : output flipped valid
// - flip_ren_o            : read enable to flip-icon memory
// - flip_raddr_o          : read address to flip-icon memory
// - flip_rdata_i          : read data from flip-icon memory
// - icon_finish_o         : asserted when final flip-icon entry is read
// - flip_disable_i  : bypass flipping and inhibit icon reads
//
// Notes:
// - Internal state (flipped data, valid flag, read address, and a registered
//   copy of flip_rdata) are maintained with clocked registers and cleared by
//   flush_i or reset. Register macros from ../lib/registers.svh are used.

`include "common_cells/registers.svh"

module flip_engine #(
    parameter int DATASPIN = 256,
    parameter int FLIP_ICON_DEPTH = 1024,
    parameter int FLIP_ICON_ADDR_DEPTH = $clog2(FLIP_ICON_DEPTH)
)(
    input logic clk_i,
    input logic rst_ni,
    input logic en_i,

    input logic cmpt_en_i,
    input logic flush_i,

    input logic prev_spin_valid_i,
    input logic [DATASPIN-1:0] prev_spin_i,
    output logic prev_spin_ready_o,

    input logic flipped_spin_ready_i,
    output logic [DATASPIN-1:0] flipped_spin_o,
    output logic flipped_spin_valid_o,

    output logic flip_ren_o,
    output logic [FLIP_ICON_ADDR_DEPTH+1-1:0] flip_raddr_o,
    input logic [FLIP_ICON_ADDR_DEPTH+1-1:0] icon_last_raddr_plus_one_i,
    input logic [DATASPIN-1:0] flip_rdata_i,

    output logic icon_finish_o,

    input logic flip_disable_i
);

    // Internal signals
    logic prev_spin_handshake;
    logic flipped_spin_handshake;
    logic flip_icon_valid;
    logic flip_icon_ready;
    logic flipped_spin_valid_comb;
    logic flipped_spin_valid_reg;
    logic flip_ren_p, flip_ren_n;
    logic [DATASPIN-1:0] flip_icon;
    logic [DATASPIN-1:0] flipped_spin_comb;
    logic [DATASPIN-1:0] flipped_spin_reg;
    logic [FLIP_ICON_ADDR_DEPTH:0] flip_raddr_n, flip_raddr_reg;
    logic [DATASPIN-1:0] flip_rdata_reg;
    logic icon_fifo_empty_comb;

    // Data logic
    assign flipped_spin_comb = flip_disable_i ? prev_spin_i : (prev_spin_i ^ flip_icon);
    assign flipped_spin_o = (en_i & prev_spin_handshake) ? flipped_spin_comb : flipped_spin_reg;

    assign flip_raddr_n = flip_raddr_reg + 1'b1;

    assign flip_icon = flip_ren_n ? flip_rdata_i : flip_rdata_reg;

    // Control logic
    assign prev_spin_handshake = prev_spin_valid_i && prev_spin_ready_o;
    assign flipped_spin_handshake = flipped_spin_valid_o && flipped_spin_ready_i;

    assign prev_spin_ready_o = en_i & flipped_spin_ready_i;
    assign flipped_spin_valid_o = en_i & prev_spin_valid_i;

    assign flip_ren_p = en_i & prev_spin_handshake & (~flush_i) & (~flip_disable_i);
    assign icon_fifo_empty_comb = (flip_raddr_reg == icon_last_raddr_plus_one_i);
    assign flip_ren_o = flip_ren_p;
    assign flip_raddr_o = flip_raddr_reg;

    // Sequential logic
    `FFLARNC(flipped_spin_reg, flipped_spin_comb, en_i & prev_spin_handshake, flush_i, 'd0, clk_i, rst_ni);
    `FFLARNC(icon_finish_o, icon_fifo_empty_comb, en_i, flush_i, 'd0, clk_i, rst_ni);
    `FFLARNC(flip_raddr_reg, flip_raddr_n, en_i & flip_ren_p, flush_i, 'd0, clk_i, rst_ni);
    `FFLARNC(flip_ren_n, flip_ren_p, en_i, flush_i, 'd0, clk_i, rst_ni);
    `FFLARNC(flip_rdata_reg, flip_rdata_i, flip_ren_n, flush_i, 'd0, clk_i, rst_ni); // assume read data is valid one cycle after read enable

endmodule