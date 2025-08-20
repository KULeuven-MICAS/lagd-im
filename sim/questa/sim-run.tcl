# Copyright 2024 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>
# Basic build script for QuestaSim

if { [info exists ::env(FORCE_BUILD)] } {
    set FORCE_BUILD $::env(FORCE_BUILD)
} else {
    set FORCE_BUILD 1
}

# If OBJ is not defined then search on the environment
if { ![info exists OBJ] } {
    if { [info exists ::env(OBJ)] } {
        set OBJ $::env(OBJ)
    } else {
        puts "ERROR: OBJ not defined"
        quit
    }
}

set SCRIPT_DIR [file dirname [info script]]

if { $FORCE_BUILD == 1 } {
    puts "Building ..."
    source ${SCRIPT_DIR}/build.tcl
} else {
    source ${SCRIPT_DIR}/defines.tcl
}

# Verify library mapping
vmap

# Apply the IterationLimit attribute
# set IterationLimit 20000000

# Run simulation
vsim -quiet \
    -wlf work/${SIM_NAME}.wlf \
    -msgmode both -displaymsgmode both \
    -L work_lib \
    -work ${WLIB} \
    -ini ./modelsim.ini \
    ${OBJ}

run -all
quit