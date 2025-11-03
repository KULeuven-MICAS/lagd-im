# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>
# Defines default values for synthesis parameters
# List of parameters:
#   TECH_NODE
#   SYN_TLE
#   RUN_ID
#   RUN_DIR
#   WORK_DIR
#   DESIGN_INPUTS_DIR
#   HDL_FILE_LIST
#   SDC_CONSTRAINTS

puts "--------------------------------------------------------------------------------"
puts "Synthesis configuration parameters:"

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
    set SYN_TLE "lagd_soc"
}
puts "\tSYN_TLE: $SYN_TLE"

# RUN_ID: Identifier for the synthesis run
# Default: [get_curr_time]
# Used to create output directories and files
if { [info exists ::env(RUN_ID)] } {
    set RUN_ID $::env(RUN_ID)
} else {
    set RUN_ID [get_curr_time]
}
puts "\tRUN_ID: $RUN_ID"

# RUN_DIR: Directory where the synthesis is run
# Default: $PROJECT_ROOT/runs/
# Used to organize multiple synthesis runs
if { [info exists ::env(RUN_DIR)] } {
    set RUN_DIR $::env(RUN_DIR)
} else {
    set RUN_DIR $PROJECT_ROOT/runs/${SYN_TLE}-${TECH_NODE}-${RUN_ID}
}
puts "\tRUN_DIR: $RUN_DIR"

# WORK_DIR: Directory where synthesis intermediate files are stored
# Default: $RUN_DIR/work
# Used to spawn synthesis in a clean directory or parallel synthesis runs
if { [info exists ::env(WORK_DIR)] } {
    set WORK_DIR $::env(WORK_DIR)
} else {
    set WORK_DIR $RUN_DIR/work
}
puts "\tWORK_DIR: $WORK_DIR"

# DESIGN_INPUTS_DIR: Directory containing design input files
# Default: $PROJECT_ROOT/target/syn/inputs
# Used to locate source files and constraints
if { [info exists ::env(DESIGN_INPUTS_DIR)] } {
    set DESIGN_INPUTS_DIR $::env(DESIGN_INPUTS_DIR)
} else {
    set DESIGN_INPUTS_DIR "$PROJECT_ROOT/target/syn/inputs"
}
puts "\tDESIGN_INPUTS_DIR: $DESIGN_INPUTS_DIR"

# HDL_FILE_LIST: File containing the list of source files to be synthesized
# Default: $DESIGN_INPUTS_DIR/lagd-flist.tcl
# Used to specify the Verilog files for synthesis
if { [info exists ::env(HDL_FILE_LIST)] } {
    set HDL_FILE_LIST $::env(HDL_FILE_LIST)
} else {
    set HDL_FILE_LIST "$DESIGN_INPUTS_DIR/lagd-flist.tcl"
}
puts "\tHDL_FILE_LIST: $HDL_FILE_LIST"

# SDC_CONSTRAINTS: File containing the SDC constraints for synthesis
# Default: $DESIGN_INPUTS_DIR/lagd.sdc
# Used to specify timing and other constraints
if { [info exists ::env(SDC_CONSTRAINTS)] } {
    set SDC_CONSTRAINTS $::env(SDC_CONSTRAINTS)
} else {
    set SDC_CONSTRAINTS "$DESIGN_INPUTS_DIR/lagd.sdc"
}
set SDC_CONSTRAINTS_PATH [file normalize $SDC_CONSTRAINTS]
puts "\tSDC_CONSTRAINTS: $SDC_CONSTRAINTS"

puts "--------------------------------------------------------------------------------"
