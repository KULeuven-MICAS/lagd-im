#!/bin/sh

# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>
# ut-run.sh - Run unit tests

set -e

show_usage()
{
    echo "LAGD: Unit test trigger script"
    echo "Usage: $0 [--test=#test_name [--tool=#sim_tool --hdl_flist=#flist_path --gui --dbg=#dbg_lvl --defines=#defines --clean --clean-only [--help]]"
    echo "Example: $0 --test=adder"
}

show_help()
{
    show_usage
    echo "  --test=#test_name: Name of the test to run"
    echo "  --tool=#sim_tool: Simulation tool to use (default: questa)"
    echo "  --hdl_flist=#flist_path: Path to HDL file list (default: empty, the test will use the default HDL files)"
    echo "  --gui: Run simulation in GUI mode"
    echo "  --dbg=#dbg_lvl: Debug level (0-3, default: 0)"
    echo "  --defines=#defines: Additional defines for the simulation, unit test specific"
    echo "  --help: Show this help message"
}

SCRIPT_DIR=$(dirname "$0")
ROOT_DIR=$(realpath "${SCRIPT_DIR}/..")

SIM_TOOL="questa"
HDL_FILE_LIST=""
NO_GUI=1
DBG=0
DEFINES=""
CLEAN=0
CLEAN_ONLY=0

for i in "$@"; do
    case $i in
        --test=*)
            TEST_NAME="${i#*=}"
            shift
            ;;
        --tool=*)
            SIM_TOOL="${i#*=}"
            shift
            ;;
        --hdl_flist=*)
            HDL_FILE_LIST="${i#*=}"
            shift
            ;;
        --gui)
            NO_GUI=0
            shift
            ;;
        --dbg=*)
            DBG="${i#*=}"
            shift
            ;;
        --defines=*)
            DEFINES="${i#*=}"
            shift
            ;;
        --clean)
            CLEAN=1
            shift
            ;;
        --clean-only)
            CLEAN_ONLY=1
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $i"
            show_usage
            exit 1
            ;;
    esac
done

TEST_PATH="${ROOT_DIR}/hw/unit_tests/${TEST_NAME}"
if [ ! -d "${TEST_PATH}" ]; then
    echo "Error: Test path '${TEST_PATH}' does not exist."
    exit 1
fi

# Set call args for the simulation
ARGS=""
if [ -n "${HDL_FILE_LIST}" ]; then
    ARGS="HDL_FILES_LIST=${HDL_FILE_LIST}"
fi

if [ "${GUI}" -eq 1 ]; then
    ARGS="${ARGS} NO_GUI=0"
else
    ARGS="${ARGS} NO_GUI=1"
fi

if [ "${DBG}" -gt 0 ]; then
    ARGS="${ARGS} DBG=${DBG}"
else
    ARGS="${ARGS} DBG=0"
fi

if [ -n "${DEFINES}" ]; then
    ARGS="${ARGS} DEFINES=${DEFINES}"
fi

if [ "${CLEAN_ONLY}" -eq 1 ]; then
    make -C "${TEST_PATH}" clean
else
    if [ "${CLEAN}" -eq 1 ]; then # CLEAN is set to 1
        if [ -n "${HDL_FILE_LIST}" ]; then # HDL_FILE_LIST is not empty
            HDL_FILE_LIST=${HDL_FILE_LIST} DBG=${DBG} DEFINES=${DEFINES} NO_GUI=${NO_GUI} make -C "${TEST_PATH}" clean questa-run
        else
             DBG=${DBG} DEFINES=${DEFINES} NO_GUI=${NO_GUI} make -C "${TEST_PATH}" clean questa-run
        fi
    else
        if [ -n "${HDL_FILE_LIST}" ]; then # HDL_FILE_LIST is not empty
            HDL_FILE_LIST=${HDL_FILE_LIST} DBG=${DBG} DEFINES=${DEFINES} NO_GUI=${NO_GUI} make -C "${TEST_PATH}" questa-run
        else
             DBG=${DBG} DEFINES=${DEFINES} NO_GUI=${NO_GUI} make -C "${TEST_PATH}" questa-run
        fi
    fi
fi
