# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Jiacong Sun <jiacong.sun@kuleuven.be>
#
# Enumerate the JTAG hardware targets and devices visible to a Vivado hw_server.
#
# WHAT IT DOES
#   Connects to an hw_server, lists every hardware target (cable) it sees, opens
#   the last one, and prints the devices in that JTAG chain. Nothing else - it
#   does NOT program, configure, or modify the board in any way (read-only).
#
# WHEN TO USE IT (this is a DIAGNOSTIC, not part of the build)
#   `make program` does not need this: the target path is baked into the Makefile
#   default (HWS_PATH ?= xilinx_tcf/Digilent/*). Reach for it only when:
#     * `make program` reports no target / cannot open the cable -> this prints
#       "NO TARGETS" so you can tell a permissions/driver problem from a wiring
#       one (see target/xilinx/README.md, "Programming").
#     * more than one board shares the hw_server -> it prints each serial so you
#       can pin `make program HWS_PATH=xilinx_tcf/Digilent/<serial>` (the glob
#       otherwise silently takes the LAST match).
#     * you want to confirm the right board is attached -> DEVICES should list
#       `xczu9_0` for the ZCU102 (a Zedboard would show `xc7z020`).
#
# STANDALONE: this script is fully self-contained. It sources nothing (not even
# common.tcl) and is sourced by nothing, so editing it cannot affect the build or
# programming flow. Run it via `make list-hw`, or directly:
#     vivado -mode batch -nolog -nojournal -source scripts/util/list_hw.tcl \
#         -tclargs <hw_server_url>
#
# tclargs: [<hw_server_url>]  (default: localhost:3121)

set url [expr { $argc >= 1 ? [lindex $argv 0] : "localhost:3121" }]

open_hw_manager
connect_hw_server -url $url

set tgts [get_hw_targets]
puts "TARGETS: $tgts"
if { [llength $tgts] == 0 } {
    puts "NO TARGETS -- hw_server sees no cable. Check: board powered, USB-JTAG"
    puts "  cabled, cable drivers/udev installed, and hw_server running."
    close_hw_manager
    exit 1
}

# Open the last target (single-board default) and list its JTAG chain.
open_hw_target [lindex $tgts end]
puts "DEVICES: [get_hw_devices]"
close_hw_manager
