# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Adapted from cheshire/target/xilinx (ETH Zurich / University of Bologna).
#
# Common helpers + board parameters for the LAGD Xilinx (ZCU102) FPGA flow.

# zcu102 board params (Zynq UltraScale+ MPSoC ZU9EG; PL-only design, JTAG config)
# Bump the board_part revision (3.4) to match the board files installed in your
# Vivado (`get_board_parts *zcu102*`). cfgmp is unused by this flow (no flash rule).
set bpart(zcu102) "xilinx.com:zcu102:part0:3.4"
set fpart(zcu102) "xczu9eg-ffvb1156-2-e"
set hwdev(zcu102) "xczu9_0"
set cfgmp(zcu102) "mt25qu512-spi-x1_x2_x4"

# Initialize an implementation project
proc init_impl {xilinx_root argc argv} {
    global fpart
    global bpart
    global num_threads
    global num_jobs
    global project_root
    global board
    global proj
    if { $argc < 2 } {
        puts "Error: Insufficient implementation arguments (${argc}): ${argv}."
        return -code error
    }
    set num_threads 8
    set num_jobs 8
    set board [lindex $argv 0]
    set proj [lindex $argv 1]
    set_param general.maxThreads $num_threads
    set project_root ${xilinx_root}/build/${board}.${proj}
    file delete -force [glob -nocomplain ${project_root}/*]
    create_project $proj $project_root -force -part $fpart($board)
    set_property board_part $bpart($board) [current_project]
}

# Open a target device in the hardware manager
proc open_target {xilinx_root argc argv suffix} {
    global hwdev
    global project_root
    global board
    global hw_tgt
    global hw_device
    if { $argc < 3 } {
        puts "Error: Insufficient target arguments (${argc}): ${argv}."
        return -code error
    }
    set url [lindex $argv 0]
    set path [lindex $argv 1]
    set board [lindex $argv 2]
    set project_root ${xilinx_root}/build/${board}.${suffix}
    file delete -force [glob -nocomplain ${project_root}/*]
    open_hw_manager
    connect_hw_server -url $url
    set hw_tgts [get_hw_targets ${url}/${path}]
    set hw_tgt [lindex ${hw_tgts} [expr { [llength ${hw_tgts}] - 1 }]]
    open_hw_target $hw_tgt
    set_property PARAM.FREQUENCY 15000000 $hw_tgt
    set hw_device [get_hw_devices $hwdev($board)]
}

# Exit if a project does not support a given board
proc no_cfg_exit {proj board} {
    puts "Error: Unsupported board ${board} for ${proj}."
    return -code error
}

# Create timing/utilization reports
proc gen_reports {rptdir} {
    file delete -force $rptdir
    file mkdir ${rptdir}
    check_timing             -file ${rptdir}/check_timing.rpt       -verbose
    report_timing            -file ${rptdir}/timing_worst_100.rpt   -max_paths 100 -nworst 100 -delay_type max -sort_by slack
    report_timing            -file ${rptdir}/timing_worst.rpt       -nworst 1 -delay_type max -sort_by group
    report_utilization       -file ${rptdir}/utilization.rpt        -hierarchical
    report_cdc               -file ${rptdir}/cdc.rpt
    report_clock_interaction -file ${rptdir}/clock_interaction.rpt
    report_timing_summary    -file ${rptdir}/timing_summary.rpt
}

# Insert debug core and ILAs for any nets marked MARK_DEBUG (none by default)
proc insert_ilas {clk_net_name} {
    global project_root
    set debug_nets [lsort -dictionary [get_nets -hier -filter {MARK_DEBUG == 1}]]
    if { ![llength $debug_nets] } { return }
    create_debug_core i_ila ila
    set_property -dict [list \
        ALL_PROBE_SAME_MU {true} ALL_PROBE_SAME_MU_CNT {4} C_ADV_TRIGGER {true} \
        C_DATA_DEPTH {16384} C_EN_STRG_QUAL {true} C_INPUT_PIPE_STAGES {0} \
        C_TRIGIN_EN {false} C_TRIGOUT_EN {false} \
        ] [get_debug_cores i_ila]
    set_property port_width 1 [get_debug_ports i_ila/clk]
    connect_debug_port i_ila/clk [get_nets $clk_net_name]
    set net_name_last ""
    set i 0
    foreach net [concat $debug_nets {""}] {
        regsub {\[[0-9]*\]$} $net {} net_name
        if { $net_name_last != $net_name } {
            if { $net_name_last != "" } {
                puts "Creating probe $i of width [llength $sig_list] for `$net_name_last`."
                if { $i != 0 } { create_debug_port i_ila probe }
                set_property port_width [llength $sig_list] [get_debug_ports i_ila/probe$i]
                set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports i_ila/probe$i]
                connect_debug_port i_ila/probe$i [get_nets $sig_list]
                incr i
            }
            set sig_list ""
        }
        lappend sig_list $net
        set net_name_last $net_name
    }
    save_constraints -force
    implement_debug_core
}
