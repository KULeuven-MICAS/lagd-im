# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Fast implementation-only run: reuse the EXISTING synthesis checkpoint from a
# previous `make bitstream` / `make synth` and run opt/place/route/bitstream.
# Skips synthesis (~26 min) + the RTL elaboration (~4 min).
#
# Use when only implementation-affecting inputs changed (pins, impl-only XDC,
# strategy). If the RTL or the bender source list changed, you MUST re-run
# `make bitstream` - this script would silently implement the stale netlist.
#
# FIDELITY CAVEAT: IPs are linked from their out-of-context .dcp, not their .xci.
# Vivado warns about this ([Vivado 12-5469]/[Project 1-840]) because an IP's own
# constraints live in the xci, not the checkpoint - so they are NOT applied here.
# For clk_wiz the impact is minimal (MMCM output clocks are auto-derived), but
# this flow is for ITERATION. Produce the final/sign-off bitstream with
# `make bitstream`, which goes through read_ip and applies the IP constraints.
#
# tclargs: <board> <proj>

set xilinx_root [file dirname [file dirname [file normalize [info script]]]]
source ${xilinx_root}/scripts/common.tcl

if { $argc < 2 } {
    puts "Error: Insufficient arguments (${argc}): ${argv}."
    return -code error
}
set board [lindex $argv 0]
set proj  [lindex $argv 1]

set num_threads 8
set num_jobs 8
set_param general.maxThreads $num_threads

set project_root ${xilinx_root}/build/${board}.${proj}
set top lagd_fpga
set dcp ${project_root}/${proj}.runs/synth_1/${top}.dcp

if { ![file exists $dcp] } {
    puts "Error: no synthesis checkpoint at ${dcp}."
    puts "Run `make bitstream` (or `make synth`) once first."
    return -code error
}

puts "LAGD: reusing synthesis checkpoint ${dcp} (skipping synthesis)."
open_checkpoint $dcp

# Link the out-of-context IP checkpoints. The IPs (e.g. clkwiz) are synthesized
# OOC in their own projects under build/<board>.<ip>/, so the top-level synthesis
# checkpoint carries them as BLACK BOXES. Project mode links them automatically;
# in non-project mode we must do it explicitly, or opt_design fails with
# [DRC INBB-3] "has undefined contents and is considered a black box".
foreach ipdcp [glob -nocomplain ${xilinx_root}/build/${board}.*/*.runs/*_synth_1/*.dcp] {
    set ipname [file rootname [file tail $ipdcp]]
    set cells [get_cells -hier -filter "REF_NAME == ${ipname} || ORIG_REF_NAME == ${ipname}"]
    foreach c $cells {
        puts "LAGD: linking IP checkpoint for cell ${c} (${ipname}) <- ${ipdcp}"
        read_checkpoint -cell $c $ipdcp
    }
}

# Fail loudly rather than producing a broken bitstream if anything is still a
# black box (e.g. a new IP whose checkpoint was not found by the glob above).
set bboxes [get_cells -hier -filter {IS_BLACKBOX == 1}]
if { [llength $bboxes] } {
    puts "Error: unresolved black box cell(s) after linking IPs: ${bboxes}"
    puts "Run `make ips` (and `make bitstream` if the RTL changed)."
    return -code error
}

# Re-read the FULL constraint set, in the same order as impl_sys.tcl.
#
# The synth_1 checkpoint does NOT carry the pin constraints: PACKAGE_PIN and
# IOSTANDARD are physical constraints that project mode applies during
# IMPLEMENTATION, not synthesis. Reading only the impl-only file leaves every
# port unconstrained and write_bitstream dies on [DRC NSTD-1]/[DRC UCIO-1].
#
# Reading these from disk (rather than relying on the checkpoint) is also what
# makes `make impl` useful: any pin/timing edit is picked up without re-synthesis.
#
# The timing constraints WERE used in synthesis, so they are already in the
# checkpoint; re-reading them redefines the same clocks with identical
# parameters. Vivado logs "clock already exists / redefining" warnings for
# sys_clk, spi_sck, jtag_tck and rtc_clk - those are expected and harmless.
foreach xdc [list \
        ${xilinx_root}/constraints/lagd.xdc \
        ${xilinx_root}/constraints/${board}.xdc \
        ${xilinx_root}/constraints/${board}_impl.xdc] {
    if { [file exists $xdc] } {
        puts "LAGD: applying ${xdc}."
        read_xdc $xdc
    }
}

# Implementation
opt_design
place_design
phys_opt_design
route_design

set rptdir ${project_root}/reports.impl
gen_reports $rptdir

# Check timing constraints
set trep [report_timing_summary -no_header -no_detailed_paths -return_string]
if { ![string match -nocase {*timing constraints are met*} $trep] } {
    puts "Warning: Timing constraints not met for ${proj} on ${board}."
}

# Write the bitstream to the same place as the full flow
file mkdir ${xilinx_root}/out
write_bitstream -force ${xilinx_root}/out/${proj}.${board}.bit
puts "LAGD: wrote ${xilinx_root}/out/${proj}.${board}.bit"
