// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Jiacong Sun <jiacong.sun@kuleuven.be>

// Package for energy calculation functions, used in digital macro testbench

package energy_calc_pkg;
    import config_pkg::*;

    // ========================================================================
    // Energy Calculation Package
    // ========================================================================
    function automatic integer calculate_h_energy(
        // Formula: H = spin_vec * weights * spin_vec^T + hscaling * hbias * spin_vec^T
        input logic [NUM_SPIN-1:0] spin_vec,
        input logic [NUM_SPIN-1:0][NUM_SPIN*BITJ-1:0] weights,
        input logic signed [NUM_SPIN*BITH-1:0] hbias,
        input logic unsigned [SCALING_BIT-1:0] hscaling
    );
        logic signed [31:0] energy;
        logic signed [31:0] local_energy_temp, local_energy;
        logic signed [BITJ-1:0] w_ij;
        logic signed [BITH-1:0] h_i;
        logic [NUM_SPIN*BITJ-1:0] weight_vec;
        logic current_spin;
        integer i, j;
        energy = 0;
        for (i = 0; i < NUM_SPIN; i=i+1) begin
            if (LITTLE_ENDIAN) begin
                current_spin = spin_vec[i];
                h_i = $signed(hbias[(i*BITH)+:BITH]);
            end else begin
                current_spin = spin_vec[NUM_SPIN-1 - i];
                h_i = $signed(hbias[((NUM_SPIN-1 - i)*BITH)+:BITH]);
            end
            weight_vec = weights[i];

            // Add h_i * spin_i term
            local_energy_temp = h_i * $signed({1'b0, hscaling});
            for (j = 0; j < NUM_SPIN; j=j+1) begin
                w_ij = $signed(weight_vec[(j*BITJ)+:BITJ]);
                local_energy_temp += spin_vec[j] ? w_ij : -w_ij;
            end
            local_energy = current_spin ? local_energy_temp : -local_energy_temp;
            energy += local_energy;
            // $display("i='h%h, spin_vec='h%h, current_spin='h%h, h_i='h%h, weight_vec='h%h, energy='h%h", i, spin_vec, current_spin, h_i, weight_vec, energy);
        end
        if (H_IS_NEGATIVE)
            energy = -energy; // flip energy sign to keep formula to be H = - ( ... )
        return energy;
    endfunction
endpackage