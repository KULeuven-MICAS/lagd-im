# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

set SCRIPTDIR [file dirname [info script]]

# Add any technology-specific setup here
puts "To be implemented: technology-specific setup"

# Example from Ryan
# set target_library [list \
#     $stdcell_dir_path/stdcells_ss_corner_0p75v85c.db \
#     $memories_dir_path/memories_ss_corner_0p75v85c.db \
#     $other_ip_dir_path/other_ip_ss_corner_0p75v85c.db \
#  ]

# set link_library "* $target_library"

source $SCRIPTDIR/IPs/ip-setup.tcl
source $SCRIPTDIR/IPs/mem-setup.tcl