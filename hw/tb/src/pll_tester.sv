// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

module pll_tester (
    input logic clk_i,
    output logic data_strb_o,
    output logic data_o,
    output logic cfg_vld_strb_o,
    output logic test_done
);

    logic [1:0] state;
    logic [$bits(pll_cfg_pkg::pll_cfg_t)-1:0] packed_test_cfg;
    pll_cfg_pkg::pll_cfg_t test_cfg;

    assign test_cfg = '{
        fb_clk_oen: 1'b1,
        pll_clk_o_en: 1'b0,
        clk_div_val: 10'd4,
        clk_div_en: 1'b1,
        pdown_PD: 1'b0,
        pdown_VCO: 1'b0,
        set_current: 3'b101,
        set_c1: 3'b010,
        set_c2: 3'b011,
        set_r1: 3'b001,
        vco_tune_coarse: 4'b1100,
        vco_current_min: 4'b0010,
        vco_current_max: 4'b1110,
        set_v_ctrl: 2'b10,
        set_clk_out: 1'b0,
        set_div_freq: 3'b010,
        set_fb_mux: 2'b01
    };
    assign packed_test_cfg = pll_cfg_pkg::pack_pll_cfg(test_cfg);

    initial begin
        test_done = 0;
        data_strb_o = 1;
        data_o = 0;
        cfg_vld_strb_o = 1; 

        repeat (2) @(posedge clk_i);

        // Deassert strobes to release reset on config registers
        data_strb_o <= #1 0;
        cfg_vld_strb_o <= #1 0;

        // Send packed configuration data
        for (int i=$size(packed_test_cfg)-1; i>=0; i--) begin
            repeat (2) @(posedge clk_i);
            data_o <= packed_test_cfg[i];
            repeat (2) @(posedge clk_i);
            data_strb_o <= 1;
            repeat (2) @(posedge clk_i);
            data_strb_o <= #1 0;
        end

        // Do the valid strobe
        repeat (10) @(posedge clk_i);
        cfg_vld_strb_o <= #1 1;
        repeat (1) @(posedge clk_i);
        cfg_vld_strb_o <= #1 0;
        test_done <= 1'b1;
        $display("PLL Configuration Sent from pll_tester in fixture");
    end
endmodule : pll_tester