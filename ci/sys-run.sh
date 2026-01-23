#!/bin/sh

# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>
# ut-run.sh - Run unit tests

set -e

show_usage()
{
    echo "LAGD: System test trigger script"
    echo "Usage: $0 [ --flist --bootmode=<mode> --preload=<mode> --binary=<binary> [--help]]"
    echo "Example: $0"
}