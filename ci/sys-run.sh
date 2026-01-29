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
    cat <<'EOF'
Usage: ./ci/sys-run.sh [[
    --chip_level
    --bootmode=#boot_mode
    --preload=#preload_mode
    --binary=#binary_path
    --dbg=#dbg_lvl
    --gui
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
    echo "  --help: Show this help message"
}

SCRIPT_DIR=$(dirname "$0")
ROOT_DIR=$(realpath "${SCRIPT_DIR}/..")

CHIP_LEVEL=0
BOOT_MODE=0
PRELOAD_MODE=0
PRELOAD_ELF=$( pixi run bender path cheshire)/sw/tests/helloworld.rom.elf
DBG=0
NO_GUI=1

for i in "$@"; do
    case $i in
        --chip_level)
            CHIP_LEVEL=1
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

if [ ! -f "$PRELOAD_ELF" ]; then
    echo "Error: Binary file '$PRELOAD_ELF' does not exist."
    exit 1
fi

echo "Running system test with the following parameters:"
echo "  CHIP_LEVEL: $CHIP_LEVEL"
echo "  BOOT_MODE: $BOOT_MODE"
echo "  PRELOAD_MODE: $PRELOAD_MODE"
echo "  PRELOAD_ELF: $PRELOAD_ELF"
echo "  DBG: $DBG"
echo "  NO_GUI: $NO_GUI"
CHIP_LEVEL=${CHIP_LEVEL} BOOT_MODE=${BOOT_MODE} PRELOAD_MODE=${PRELOAD_MODE} \
    PRELOAD_ELF=${PRELOAD_ELF} DBG=${DBG} NO_GUI=${NO_GUI} make -C "${ROOT_DIR}/hw/tb" run