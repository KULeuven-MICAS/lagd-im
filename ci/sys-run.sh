#!/bin/sh

# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>
# sys-run.sh - Run system tests

set -e

show_usage()
{
    echo "LAGD: System test trigger script"
    cat <<'EOF'
Usage: ./ci/sys-run.sh [[
    --chip_level
    --bootmode=#boot_mode
    --preload=#preload_mode
    --binary=#binary_path
    --dbg=#dbg_lvl
    --gui
    --use_tech_models
    --netlist=#netlist_path
    --help]]"
EOF
    echo "Example: $0"
}

show_help()
{
    show_usage
    echo "  --chip_level: Run chip-level system test (default: off, i.e., run soc-level test)"
    echo "  --bootmode=#boot_mode: Boot mode for the system test. Options: 0-ROM 1-SPI (default: ROM)"
    echo "  --preload=#preload_mode: Preload mode for the system test. Options: 0-JTAG 1-UART (default: JTAG)"
    echo "  --binary=#binary_path: Path to the binary to load into memory (default: helloworld.rom.elf)"
    echo "  --dbg=#dbg_lvl: Debug level (0-3, default: 0)"
    echo "  --gui: Run simulation in GUI mode"
    echo "  --use_tech_models: Use technology models for the simulation"
    echo "  --netlist=#netlist_path: Path to the netlist to use for the simulation (default: no netlist, i.e., use RTL)"
    echo "  --help: Show this help message"
}

SCRIPT_DIR=$(dirname "$0")
ROOT_DIR=$(realpath "${SCRIPT_DIR}/..")

CHIP_LEVEL_TEST=0
BOOT_MODE=0
PRELOAD_MODE=0
USE_TECH_MODELS=0
NETLIST_PATH=""

if bender --version > /dev/null 2>&1; then
    BENDER="bender"
elif pixi run bender --version > /dev/null 2>&1; then
    BENDER="pixi run bender"
else
    echo "[ERROR] ./ci/sys-run.sh: bender command not found. Please ensure bender is installed."
    exit 1
fi

CHS_PATH=$( ${BENDER} path cheshire)
PRELOAD_ELF=${CHS_PATH}/sw/tests/helloworld.spm.elf
DBG=0
NO_GUI=1

for i in "$@"; do
    case $i in
        --chip_level)
            CHIP_LEVEL_TEST=1
            shift
            ;;
        --bootmode=*)
            BOOT_MODE="${i#*=}"
            shift
            ;;
        --preload=*)
            PRELOAD_MODE="${i#*=}"
            shift
            ;;
        --binary=*)
            PRELOAD_ELF="${i#*=}"
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        --dbg=*)
            DBG="${i#*=}"
            shift
            ;;
        --gui)
            NO_GUI=0
            shift
            ;;
        --use_tech_models)
            USE_TECH_MODELS=1
            shift
            ;;
        --netlist=*)
            NETLIST_PATH="${i#*=}"
            shift
            ;;
        *)
            echo "Unknown option: $i"
            show_usage
            exit 1
            ;;
    esac
done

if [ ! -f "$PRELOAD_ELF" ]; then
    echo "[ERROR] ./ci/sys-run.sh: Preload ELF file not found at path: ${PRELOAD_ELF}"
    exit 1
fi

if [ -n "$NETLIST_PATH" ] && [ ! -f "$NETLIST_PATH" ]; then
    NETLIST_PATH=( ${NETLIST_PATH}/*.v )
    if [ ! -f "$NETLIST_PATH" ]; then
        echo "[ERROR] ./ci/sys-run.sh: Netlist file not found at path: ${NETLIST_PATH}"
        exit 1
    fi
    echo "[INFO] ./ci/sys-run.sh: Autodetected netlist file(s): ${NETLIST_PATH}"
    NETLIST_PATH=$(realpath ${NETLIST_PATH})
fi

echo "Running system test with the following parameters:"
echo "  CHIP_LEVEL_TEST: $CHIP_LEVEL_TEST"
echo "  BOOT_MODE: $BOOT_MODE"
echo "  PRELOAD_MODE: $PRELOAD_MODE"
echo "  PRELOAD_ELF: $PRELOAD_ELF"
echo "  DBG: $DBG"
echo "  NO_GUI: $NO_GUI"
echo "  USE_TECH_MODELS: $USE_TECH_MODELS"
echo "  NETLIST_PATH: $NETLIST_PATH"

if [ -n "$NETLIST_PATH" ]; then
    CHIP_LEVEL_TEST=1
    echo "[INFO] ./ci/sys-run.sh: Enabling chip-level test."
fi

if [ "${CHIP_LEVEL_TEST}" -eq 1 ]; then
    USE_TECH_MODELS=1
    echo "[INFO] ./ci/sys-run.sh: Enabling technology models."
fi

# Regenerate the flist
USE_TECH_MODELS=${USE_TECH_MODELS} make -C ${ROOT_DIR}/hw/tb/ clean flist

CHIP_LEVEL_TEST=${CHIP_LEVEL_TEST} BOOT_MODE=${BOOT_MODE} PRELOAD_MODE=${PRELOAD_MODE} \
    PRELOAD_ELF=${PRELOAD_ELF} DBG=${DBG} NO_GUI=${NO_GUI} USE_TECH_MODELS=${USE_TECH_MODELS} \
    NETLIST_PATH=${NETLIST_PATH} make run-soc