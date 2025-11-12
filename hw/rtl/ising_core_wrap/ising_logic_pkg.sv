// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Jiacong Sun <jiacong.sun@kuleuven.be>

// Package for Ising logic configuration and definitions

`include "lagd_config.svh"

package ising_logic_pkg;

    typedef struct packed {
        /// Number of Spins
        int unsigned NumSpin;
        /// Bit width for J couplings
        int unsigned BitJ;
        /// Bit width for H fields
        int unsigned BitH;
        /// Depth of the flip icon memory
        int unsigned FlipIconDepth;
    } ising_logic_cfg_t;
    localparam ising_logic_cfg_t IsingLogicCfg = '{
        NumSpin : `NUM_SPIN,
        BitJ    : `BIT_J,
        BitH    : `BIT_H,
        FlipIconDepth : `FLIP_ICON_DEPTH
    };

endpackage: ising_logic_pkg