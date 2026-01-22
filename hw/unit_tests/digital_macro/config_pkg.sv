// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Jiacong Sun <jiacong.sun@kuleuven.be>

// Package for configuration parameters, used in digital macro testbench

`define True 1'b1
`define False 1'b0

// Configuration package for digital macro unit tests
package config_pkg;
    // design-time parameters
    parameter int NUM_SPIN = 256;
    parameter int BITDATA = 4;
    parameter int SCALING_BIT = 5;
    parameter int LITTLE_ENDIAN = `False; // True: little endian, False: big endian
    parameter int PIPESINTF = 1;
    parameter int PIPESMID = 1;
    parameter int PIPESFLIPFILTER = 1;
    parameter int PARALLELISM = 4;
    parameter int BypassDataConversion = `False;
    parameter int ENERGY_TOTAL_BIT = 32;
    parameter int SPIN_DEPTH = 2;
    parameter int FLIP_ICON_DEPTH = 1024;
    parameter int COUNTER_BITWIDTH = 16;
    parameter int SYNCHRONIZER_PIPEDEPTH = 3;
    parameter int SPIN_WBL_OFFSET = 0;
    parameter int H_IS_NEGATIVE = `True;
    parameter int ENABLE_FLIP_DETECTION = `True;

    // run-time parameters (related to algorithm, others are defined at the beginning of the testbench)
    parameter int IconLastAddrPlusOne = FLIP_ICON_DEPTH;

    // run-time parameters (related to hardware)
    parameter int CyclePerWwlHigh = 2;
    parameter int CyclePerWwlLow = 2;
    parameter int CyclePerSpinWrite = 2; // cannot be 1 since the real value set is CyclePerSpinWrite - 1
    parameter int CyclePerSpinCompute = 2;
    parameter int SynchronizerPipeNum = 1;
    parameter int SpinWwlStrobe = {NUM_SPIN{1'b1}};
    parameter int SpinFeedback = {NUM_SPIN{1'b1}}; // all spins in feedback mode
    parameter int Flush = `False;

    // derived parameters
    parameter int BITJ = BITDATA;
    parameter int BITH = BITDATA;
    parameter int EmCfgCounter = NUM_SPIN - 1;

    // model type definition
    typedef struct {
        logic [NUM_SPIN-1:0][NUM_SPIN*BITJ-1:0] weights;
        logic [NUM_SPIN*BITH-1:0] hbias;
        logic [SCALING_BIT-1:0] scaling_factor;
        int signed constant;
    } model_t;
endpackage
