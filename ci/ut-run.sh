#!/bin/sh

# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>
# ut-run.sh - Run unit tests

# TODO add support for multicore execution

set -e

show_usage()
{
    echo "LAGD: Unit test trigger script"
    cat <<'EOF'
Usage: ./ci/ut-run.sh [
    --test=#test_name [
    --tool=#sim_tool
    --leaf=#leaf_name
    --hdl_flist=#flist_path
    --gui
    --dbg=#dbg_lvl
    --defines=#defines
    --parameters=#params
    --clean
    --clean-only
    --help]]"
EOF
    echo "Example: $0 --test=adder"
}

show_help()
{
    show_usage
    echo "  --test=#test_name: Name of the test to run"
    echo "  --tool=#sim_tool: Simulation tool to use (default: vsim)"
    echo "  --leaf=#leaf_name: Name of the leaf test to run (optional)"
    echo "  --hdl_flist=#flist_path: Path to HDL file list (default: empty, the test will use the default HDL files)"
    echo "  --gui: Run simulation in GUI mode"
    echo "  --dbg=#dbg_lvl: Debug level (0-3, default: 0)"
    echo "  --defines=#defines: Additional defines for the simulation, unit test specific"
    echo "  --parameters=#params: Additional parameters for the simulation, unit test specific"
    echo "  --clean: Clean previous simulation artifacts before running"
    echo "  --clean-only: Only clean previous simulation artifacts and exit"
    echo "  --help: Show this help message"
}

SCRIPT_DIR=$(dirname "$0")
ROOT_DIR=$(realpath "${SCRIPT_DIR}/..")

SIM_TOOL="vsim"
HDL_FILES_LIST=""
LEAF=""
NO_GUI=1
DBG=0
DEFINES=""
PARAMS=""
CLEAN=""
CLEAN_ONLY=0

for i in "$@"; do
    case $i in
        --test=*)
            TEST_NAME="${i#*=}"
            shift
            ;;
        --leaf=*)
            LEAF="${i#*=}"
            shift
            ;;
        --tool=*)
            SIM_TOOL="${i#*=}"
            shift
            ;;
        --hdl_flist=*)
            HDL_FILES_LIST="${i#*=}"
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
        --parameters=*)
            PARAMS="${i#*=}"
            shift
            ;;
        --clean)
            CLEAN=${SIM_TOOL}-clean
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

if [ -n "${LEAF}" ]; then
    if [ ! -f "${TEST_PATH}/tests/${LEAF}.tcl" ]; then
        echo "Error: Leaf test '${LEAF}' for '${TEST_PATH}' does not exist."
        exit 1
    else
        HDL_FILES_LIST="${TEST_PATH}/tests/${LEAF}.tcl"
    fi
fi

if [ "${CLEAN_ONLY}" -eq 1 ]; then
    SIM_TOOL=${SIM_TOOL} LEAF=${LEAF} HDL_FILES_LIST=${HDL_FILES_LIST} \
        make -C "${TEST_PATH}" ${SIM_TOOL}-clean
else
    if [ -n "${HDL_FILES_LIST}" ]; then # HDL_FILES_LIST is not empty
        if [ -n "${LEAF}" ]; then
            echo "Running leaf test ${LEAF} for test ${TEST_NAME} with HDL file list ${HDL_FILES_LIST}"
            HDL_FILES_LIST=${HDL_FILES_LIST} DBG=${DBG} DEFINES=${DEFINES} PARAMS=${PARAMS} \
            NO_GUI=${NO_GUI} SIM_TOOL=${SIM_TOOL} LEAF=${LEAF} \
            make -C "${TEST_PATH}" ${CLEAN} run
        else
            echo "Running test '${TEST_NAME}' with HDL file list '${HDL_FILES_LIST}'"
            HDL_FILES_LIST=${HDL_FILES_LIST} DBG=${DBG} DEFINES=${DEFINES} PARAMS=${PARAMS} \
            NO_GUI=${NO_GUI} SIM_TOOL=${SIM_TOOL} \
            make -C "${TEST_PATH}" ${CLEAN} run
        fi
    else
        echo "Running test '${TEST_NAME}'"
        DBG=${DBG} DEFINES=${DEFINES} PARAMS=${PARAMS} NO_GUI=${NO_GUI} SIM_TOOL=${SIM_TOOL} \
            make -C "${TEST_PATH}" ${CLEAN} run
    fi
fi
