// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

module pomelo_pll (
    input wire VDDA,
    input wire IN50U_REF,
    inout wire VCO_CTRL_EXT,

    input logic PLL_IN,
    output logic PLL_OUT,
    output logic LOCKED,
    inout logic IO_FB_PAD_TO_IP,
    inout logic IO_FB_IP_TO_PAD,

    input logic pdown_PD,
    input logic pdown_VCO,
    input logic [2:0] set_current,
    input logic [2:0] set_c1,
    input logic [2:0] set_c2,
    input logic [2:0] set_r1,
    input logic [3:0] vco_tune_coarse,
    input logic [3:0] vco_current_min,
    input logic [3:0] vco_current_max,
    input logic [1:0] set_v_ctrl,
    input logic set_clk_out,
    input logic [2:0] set_div_freq,
    input logic [1:0] set_fb_mux
);

    // PLL implementation goes here
    // For the purpose of this example, we will just tie outputs to inputs
    assign PLL_OUT = PLL_IN;
    assign IO_FB_PAD_TO_IP = IO_FB_IP_TO_PAD;
    assign LOCKED = 1'b1; // Assume PLL is always locked for this example

endmodule : pomelo_pll