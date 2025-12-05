# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>
# Basic build script for QuestaSim

if { [info exists ::env(BUILD_ONLY)] } {
    set BUILD_ONLY $::env(BUILD_ONLY)
} else {
    set BUILD_ONLY 1
}

set SCRIPT_DIR [file dirname [info script]]

source ${SCRIPT_DIR}/defines.tcl

vlib ${WLIB}
vmap work ${WLIB}
#vmap work_lib ${WLIB}

source ${HDL_FILE_LIST}

puts "Building ${SIM_NAME} ..."
foreach file $HDL_FILES {
    puts "Compiling ${file} ..."
    vlog -sv -work ${WLIB} {*}${DEFINES} ${file}
}


# Optimization and object preparation
if { $DBG == 1 } {
    vopt -quiet -work ${WLIB} +acc tb_${SIM_NAME} -o dbg_${SIM_NAME}
    set OBJ "dbg_${SIM_NAME}"
} else {
    vopt -quiet -work ${WLIB} tb_${SIM_NAME} -o nodbg_${SIM_NAME}
    set OBJ "nodbg_${SIM_NAME}"
}

if { $BUILD_ONLY == 1 } {
    quit
}
