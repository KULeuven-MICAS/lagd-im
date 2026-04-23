// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Author: Giuseppe M. Sarda <giuseppe.sarda@esat.kuleuven.be>

`ifndef TB_COMMON_SVH
`define TB_COMMON_SVH

`ifndef DBG
`define DBG 0
`endif

`ifndef VCD_DUMP
`define VCD_DUMP 0
`endif

`ifndef VCD_FILE
`define VCD_FILE "tb.vcd"
`endif

`ifndef VCD_START
`define VCD_START 1
`endif

`ifndef VCD_STOP
`define VCD_STOP 0
`endif

`ifndef END_SIM_AT_VCD_STOP
`define END_SIM_AT_VCD_STOP 0
`endif

`define VCD_GEN_ST_SP(__enable, __vcd_file, __scope, __start, __stop, __sim_stop) \
    initial begin \
        if (__enable) begin \
            $dumpfile(__vcd_file); \
            $dumpvars(0, __scope); \
            $dumpoff; \
        end \
    end \
    initial begin \
        if (__enable) begin \
            #1; \
            wait(__start); \
            $display("Enabling VCD dumping at time %0t", $time); \
            $dumpon; \
            wait(__stop); \
            $display("Disabling VCD dumping at time %0t", $time); \
            $dumpoff; \
            #1; \
            if (__sim_stop) begin \
                $display("Ending simulation at time %0t", $time); \
                $finish; \
            end \
        end \
    end

`define VCD_GEN_ST(__enable, __vcd_file, __scope, __start) \
    `VCD_GEN_ST_SP(__enable, __vcd_file, __scope, __start, 0, 0)

`define VCD_GEN(__enable, __vcd_file, __scope) \
    `VCD_GEN_ST_SP(__enable, __vcd_file, __scope, 1, 0, 0)

`endif
