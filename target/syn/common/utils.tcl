# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

# Utility functions for synthesis scripts

#-----------------------------------
# proc get_curr_time {}
#===========================================================
# Description: gets the current time formatted as YYYY-MM-DD_HH-MM-SS
# Input: none
# Returns:
#   formatted current time string
#===========================================================
proc get_curr_time {} {
    set curr_time [clock format [clock seconds]]
    set curr_time [string map {" " _} $curr_time]
    set curr_time [string map {: -} $curr_time]
    return $curr_time
}