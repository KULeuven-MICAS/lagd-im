# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Adapted from cheshire/target/xilinx (ETH Zurich / University of Bologna).
#
# Program a bitstream onto the board.
# tclargs: <hw_server_url> <hw_device_path> <board> <bitstream>

set xilinx_root [file dirname [file dirname [file dirname [file normalize [info script]]]]]
source -quiet ${xilinx_root}/scripts/common.tcl
open_target $xilinx_root $argc $argv program

# Additional argument provides bitstream
set bit [lindex $argv 3]

# Program bitstream and refresh device
current_hw_device $hw_device
set_property PROGRAM.FILE $bit $hw_device
program_hw_devices $hw_device
refresh_hw_device $hw_device
