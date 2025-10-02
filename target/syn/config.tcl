# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>
# Defines default values for synthesis parameters

puts "--------------------------------------------------------------------------------"
puts "Synthesis configuration parameters:"

# WORK_DIR: Directory where synthesis intermediate files are stored
# Default: ./work
# Used to spawn synthesis in a clean directory or parallel synthesis runs
if { [info exists ::env(WORK_DIR)] } {
    set WORK_DIR $::env(WORK_DIR)
} else {
    set WORK_DIR "./work"
}
puts "\tWORK_DIR: $WORK_DIR"

# RUN_ID: Identifier for the synthesis run
# Default: lagd-syn
# Used to create output directories and files
if { [info exists ::env(RUN_ID)] } {
    set RUN_ID $::env(RUN_ID)
} else {
    set RUN_ID "lagd-syn"
}
puts "\tRUN_ID: $RUN_ID"

# FILE_LIST: File containing the list of source files to be synthesized
# Default: ./inputs/lagd-flist.tcl
# Used to specify the Verilog files for synthesis
if { [info exists ::env(FILE_LIST)] } {
    set FILE_LIST $::env(FILE_LIST)
} else {
    set FILE_LIST "./inputs/lagd-flist.tcl"
}
puts "\tFILE_LIST: $FILE_LIST"

# SDC_CONSTRAINTS: File containing the SDC constraints for synthesis
# Default: ./inputs/lagd-constraints.sdc
# Used to specify timing and other constraints
if { [info exists ::env(SDC_CONSTRAINTS)] } {
    set SDC_CONSTRAINTS $::env(SDC_CONSTRAINTS)
} else {
    set SDC_CONSTRAINTS "./inputs/lagd.sdc"
}
puts "\tSDC_CONSTRAINTS: $SDC_CONSTRAINTS"

# TECH_NODE: Technology node for synthesis
# Default: tsmc7ff
# Used to select the technology-specific setup script
if { [info exists ::env(TECH_NODE)] } {
    set TECH_NODE $::env(TECH_NODE)
} else {
    set TECH_NODE "tsmc7ff"
}
puts "\tTECH_NODE: $TECH_NODE"

# SYN_TLE: Synthesis top-level entity name
# Default: lagd_soc
# Used to specify the top-level module for synthesis
if { [info exists ::env(SYN_TLE)] } {
    set SYN_TLE $::env(SYN_TLE)
} else {
    set SYN_TLE "system_top"
}
puts "\tSYN_TLE: $SYN_TLE"

puts "--------------------------------------------------------------------------------"
