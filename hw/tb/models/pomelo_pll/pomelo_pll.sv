// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

`define REPORT_CHANGES(signal, enable) \
    always @(signal) begin \
        if (enable) begin \
            $display("[pomelo_pll DEBUG - Time:%0t] %s changed to %b", $time, `"signal`", signal); \
        end \
    end

module pomelo_pll (
    input wire VDDA,
    input wire IN50U_REF,
    inout wire VCO_CTRL_EXT,

    input logic PLL_IN,
    output logic PLL_OUT,
    output logic LOCKED,
    input logic IO_FB_PAD_TO_IP,
    output logic IO_FB_IP_TO_PAD,
    input logic CLK_EXT,

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
    assign IO_FB_IP_TO_PAD = !IO_FB_PAD_TO_IP;
    assign LOCKED = 1'b1; // Assume PLL is always locked for this example

    logic enable_dbg_trigger, sim_rst_n;
    // Debugging: Print configuration changes
    initial begin
        enable_dbg_trigger = 1'b0;
        repeat (10) @(posedge CLK_EXT); // Wait for the first clock edge
        $display("[pomelo_pll DEBUG] Initial configurations:");
        $display("\tpdown_PD=%b, pdown_VCO=%b, set_current=%b", pdown_PD, pdown_VCO, set_current);
        $display("\tset_c1=%b, set_c2=%b, set_r1=%b, vco_tune_coarse=%b", set_c1, set_c2, set_r1, vco_tune_coarse);
        $display("\tvco_current_min=%b, vco_current_max=%b, set_v_ctrl=%b", vco_current_min, vco_current_max, set_v_ctrl);
        $display("\tset_clk_out=%b, set_div_freq=%b, set_fb_mux=%b", set_clk_out, set_div_freq, set_fb_mux);
        enable_dbg_trigger = 1'b1; // Enable trigger after initial print
    end
    initial begin
        sim_rst_n = 1'b0;
        #1; // Simulate reset duration
        sim_rst_n = 1'b1;
    end
    `REPORT_CHANGES(pdown_PD, enable_dbg_trigger)
    `REPORT_CHANGES(pdown_VCO, enable_dbg_trigger)
    `REPORT_CHANGES(set_current, enable_dbg_trigger)
    `REPORT_CHANGES(set_c1, enable_dbg_trigger)
    `REPORT_CHANGES(set_c2, enable_dbg_trigger)
    `REPORT_CHANGES(set_r1, enable_dbg_trigger)
    `REPORT_CHANGES(vco_tune_coarse, enable_dbg_trigger)
    `REPORT_CHANGES(vco_current_min, enable_dbg_trigger)
    `REPORT_CHANGES(vco_current_max, enable_dbg_trigger)
    `REPORT_CHANGES(set_v_ctrl, enable_dbg_trigger)
    `REPORT_CHANGES(set_clk_out, enable_dbg_trigger)
    `REPORT_CHANGES(set_div_freq, enable_dbg_trigger)
    `REPORT_CHANGES(set_fb_mux, enable_dbg_trigger)


    // Check for Unknowns (X/Z) on inputs

    `ifdef TARGET_SYNTHESIS
        always_comb begin
            assert (1) else $error("This is a model intended for simulation only. It must not be in synthesis list.");
        end
    `endif

    always_comb begin
        if (sim_rst_n) begin
            assert (!$isunknown(PLL_IN)) else $warning("PLL_IN is unknown (X or Z)");
            assert (!$isunknown(CLK_EXT)) else $warning("CLK_EXT is unknown (X or Z)");
            assert (!$isunknown(pdown_PD)) else $warning("pdown_PD is unknown (X or Z)");
            assert (!$isunknown(pdown_VCO)) else $warning("pdown_VCO is unknown (X or Z)");
            assert (!$isunknown(set_current)) else $warning("set_current is unknown (X or Z)");
            assert (!$isunknown(set_c1)) else $warning("set_c1 is unknown (X or Z)");
            assert (!$isunknown(set_c2)) else $warning("set_c2 is unknown (X or Z)");
            assert (!$isunknown(set_r1)) else $warning("set_r1 is unknown (X or Z)");
            assert (!$isunknown(vco_tune_coarse)) else $warning("vco_tune_coarse is unknown (X or Z)");
            assert (!$isunknown(vco_current_min)) else $warning("vco_current_min is unknown (X or Z)");
            assert (!$isunknown(vco_current_max)) else $warning("vco_current_max is unknown (X or Z)");
            assert (!$isunknown(set_v_ctrl)) else $warning("set_v_ctrl is unknown (X or Z)");
            assert (!$isunknown(set_clk_out)) else $warning("set_clk_out is unknown (X or Z)");
            assert (!$isunknown(set_div_freq)) else $warning("set_div_freq is unknown (X or Z)");
            assert (!$isunknown(set_fb_mux)) else $warning("set_fb_mux is unknown (X or Z)");
        end
    end

endmodule : pomelo_pll