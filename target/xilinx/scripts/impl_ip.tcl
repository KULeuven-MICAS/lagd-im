# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Adapted from cheshire/target/xilinx (ETH Zurich / University of Bologna).
#
# Build a single Xilinx IP for the LAGD FPGA flow. tclargs: <board> <ip>

set xilinx_root [file dirname [file dirname [file normalize [info script]]]]
source ${xilinx_root}/scripts/common.tcl
init_impl $xilinx_root $argc $argv

switch $proj {

    clkwiz {
        # Single MMCM output: clk_out1 = 50 MHz from a 300 MHz buffered input.
        # The wrapper does its own IBUFDS, so the IP input is a plain buffer.
        create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name $proj
        switch $board {
            zcu102 {
                # ZCU102 user_si570_sysclk is 300 MHz differential. The wrapper
                # does its own IBUFDS, so the IP input is a plain buffer.
                set_property -dict [list \
                    CONFIG.PRIM_SOURCE {No_buffer} \
                    CONFIG.PRIM_IN_FREQ {300.000} \
                    CONFIG.USE_RESET {true} \
                    CONFIG.RESET_TYPE {ACTIVE_HIGH} \
                    CONFIG.RESET_PORT {reset} \
                    CONFIG.NUM_OUT_CLKS {1} \
                    CONFIG.CLKOUT1_USED {true} \
                    CONFIG.CLK_OUT1_PORT {clk_out1} \
                    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {50.000} \
                    CONFIG.MMCM_CLKIN1_PERIOD {3.333} \
                    ] [get_ips $proj]
            }
            default { no_cfg_exit $proj $board }
        }
    }

    default { no_cfg_exit $proj $board }
}

# Generate targets
set xci ${project_root}/${proj}.srcs/sources_1/ip/${proj}/${proj}.xci
generate_target all [get_files $xci]

# Synthesize IP out of context
create_ip_run [get_files -of_objects [get_fileset sources_1] $xci]
launch_run -jobs $num_jobs ${proj}_synth_1
wait_on_run ${proj}_synth_1

# Symlink for easy access and build tracking
file delete -force ${project_root}/out.xci
file link -symbolic ${project_root}/out.xci $xci
