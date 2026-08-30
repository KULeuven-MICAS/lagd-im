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
    --post-syn
    --post-pnr
    --skip-sw-build
    --vcd
    --sdf-annotate
    --wave-scope=#scope
    --no-wave-log
    --defines=#defines
    --sim-args=#sim_args
    --disable-assertions
    --data-folder=#data_folder
    --core-tested=#core_index
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
    echo "  --run_id=#run_id: Optional identifier for the simulation run (used to create a unique work directory)"
    echo "  --post-syn: Run post-synthesis simulation"
    echo "  --post-pnr: Run post-place-and-route simulation"
    echo "  --skip-sw-build: Skip the software build step"
    echo "  --vcd: Generate VCD waveform file (default: off)"
    echo "  --sdf-annotate: Enable SDF annotation for post-synthesis simulation (implies --post-syn or --netlist)"
    echo "  --wave-scope=#scope: Passed verbatim as arguments to vsim's 'log' command (only for dbg>0, default: '-r /*' -- everything); named scopes need the 'sim:' prefix, e.g. '-r sim:/tb_lagd_chip/*'"
    echo "  --no-wave-log: Don't log any waves up front (only for dbg>0); add your own 'log -r <scope>' from the vsim console instead, e.g. with --gui"
    echo "  --defines=#defines: Space-separated NAME or NAME=VALUE tokens, forwarded as +define+NAME[=VALUE] onto the vlog compile line (default: none, only affects files not covered by the bender-generated flist, e.g. --defines=\"TARGET_GALENA_NO_CHECKS\" has no effect on hw/tb/models/**)"
    echo "  --sim-args=#sim_args: Space-separated tokens appended to hw/tb/Makefile's SIM_ARGS, forwarded to 'bender script vsim' when generating the flist (default: none); use to add bender targets, e.g. --sim-args=\"-t galena_no_checks\" to compile hw/tb/models/galena/galena.sv with TARGET_GALENA_NO_CHECKS defined"
    echo "  --disable-assertions: Disable all SystemVerilog assertions design-wide at simulation runtime (equivalent to 'assertion disable -r /*' in vsim, no recompile needed)"
    echo "  --data-folder=#data_folder: Specify the data folder under sw/tests/data/ to use for the simulation (default: default)"
    echo "  --core-tested=#core_index: Core driven by the single-core tests (default: 0). Ignored by the multi-core tests"
    echo "  --help: Show this help message"
}

SCRIPT_DIR=$(dirname "$0")
ROOT_DIR=$(realpath "${SCRIPT_DIR}/..")

CHIP_LEVEL_TEST=0
BOOT_MODE=0
PRELOAD_MODE=0
USE_TECH_MODELS=0
NETLIST_PATH=""
RUN_ID="1"
POST_SYN=0
POST_PNR=0
SKIP_SW_BUILD=0
VCD_DUMP=0
SDF_FILE=""
SDF_ANNOTATE=0
WAVE_SCOPE="-r /*"
WAVE_LOG=1
DEFINES=""
SIM_ARGS=""
DISABLE_ASSERTIONS=0
DATA_FOLDER="default"
CORE_TESTED="${CORE_TESTED:-0}"

if bender --version > /dev/null 2>&1; then
    BENDER="bender"
elif pixi run bender --version > /dev/null 2>&1; then
    BENDER="pixi run bender"
elif ${HOME}/.cargo/bin/bender --version > /dev/null 2>&1; then
    BENDER="${HOME}/.cargo/bin/bender"
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
        --run_id=*)
            RUN_ID="${i#*=}"
            shift
            ;;
        --post-syn)
            POST_SYN=1
            shift
            ;;
        --post-pnr)
            POST_PNR=1
            shift
            ;;
        --skip-sw-build)
            SKIP_SW_BUILD=1
            shift
            ;;
        --vcd)
            VCD_DUMP=1
            shift
            ;;
        --sdf-annotate)
            SDF_ANNOTATE=1
            shift
            ;;
        --wave-scope=*)
            WAVE_SCOPE="${i#*=}"
            shift
            ;;
        --no-wave-log)
            WAVE_LOG=0
            shift
            ;;
        --defines=*)
            DEFINES="${i#*=}"
            shift
            ;;
        --sim-args=*)
            SIM_ARGS="${i#*=}"
            shift
            ;;
        --disable-assertions)
            DISABLE_ASSERTIONS=1
            shift
            ;;
        --data-folder=*)
            DATA_FOLDER="${i#*=}"
            shift
            ;;
        --core-tested=*)
            CORE_TESTED="${i#*=}"
            shift
            ;;
        *)
            echo "Unknown option: $i"
            show_usage
            exit 1
            ;;
    esac
done

# Build SW before simulation
if [ "${SKIP_SW_BUILD}" -eq 0 ]; then
    echo "[$(date +%T)] Starting SW build..."
    make -C "${ROOT_DIR}/sw" clean all BENDER="${BENDER}" DATA_FOLDER="${DATA_FOLDER}" \
        COMPILE_ARGS="CORE_TESTED=${CORE_TESTED}"
    echo "[$(date +%T)] SW build done."
else
    echo "[$(date +%T)] Skipping SW build."
fi

PRELOAD_ELF=$(realpath "$PRELOAD_ELF") # Cheshire requires an absolute path for ELF

if [ ! -f "$PRELOAD_ELF" ]; then
    echo "[ERROR] ./ci/sys-run.sh: Preload ELF file not found at path: ${PRELOAD_ELF}"
    exit 1
fi

if [ "${POST_SYN}" -eq 1 ] && [ ! -n "$NETLIST_PATH" ]; then
    NETLIST_PATH=/users/micas/shares/project_lagd/netlists/latest/
fi

if [ -n "$NETLIST_PATH" ] && [ ! -f "$NETLIST_PATH" ]; then
    NETLIST_PATH=( ${NETLIST_PATH}/*.v )
    if [ ! -f "$NETLIST_PATH" ]; then
        echo "[ERROR] ./ci/sys-run.sh: Netlist file not found at path: ${NETLIST_PATH}"
        exit 1
    fi
    echo "[INFO] ./ci/sys-run.sh: Autodetected netlist file(s): ${NETLIST_PATH}"
fi

if [ -n "$NETLIST_PATH" ]; then
    NETLIST_PATH=$(realpath ${NETLIST_PATH})
fi

if [ -n "$NETLIST_PATH" ]; then
    CHIP_LEVEL_TEST=1
    echo "[INFO] ./ci/sys-run.sh: Enabling chip-level test."
fi

if [ "${CHIP_LEVEL_TEST}" -eq 1 ]; then
    USE_TECH_MODELS=1
    echo "[INFO] ./ci/sys-run.sh: Enabling technology models."
fi

if [ "${SDF_ANNOTATE}" -eq 1 ]; then
    if [ "${POST_SYN}" -eq 0 ] && [ -z "$NETLIST_PATH" ]; then
        echo "[ERROR] ./ci/sys-run.sh: SDF annotation requires either post-syn simulation or a netlist path."
        exit 1
    fi
    echo "[INFO] ./ci/sys-run.sh: Enabling SDF annotation."
    NETLIST_ROOT=$(dirname "$NETLIST_PATH")
    SDF_FILE=( ${NETLIST_ROOT}/*.sdf )
    if [ ! -f "$SDF_FILE" ]; then
        echo "[ERROR] ./ci/sys-run.sh: No SDF file found in netlist directory: ${NETLIST_ROOT}"
        exit 1
    fi
fi

echo "Running system test with the following parameters:"
echo "  CHIP_LEVEL_TEST: $CHIP_LEVEL_TEST"
echo "  BOOT_MODE: $BOOT_MODE"
echo "  PRELOAD_MODE: $PRELOAD_MODE"
echo "  PRELOAD_ELF: $PRELOAD_ELF"
echo "  DBG: $DBG"
echo "  NO_GUI: $NO_GUI"
echo "  WAVE_SCOPE: $WAVE_SCOPE"
echo "  WAVE_LOG: $WAVE_LOG"
echo "  DEFINES: $DEFINES"
echo "  SIM_ARGS: $SIM_ARGS"
echo "  DISABLE_ASSERTIONS: $DISABLE_ASSERTIONS"
echo "  USE_TECH_MODELS: $USE_TECH_MODELS"
echo "  NETLIST_PATH: $NETLIST_PATH"
echo "  DATA_FOLDER: $DATA_FOLDER"
echo "  CORE_TESTED (for single-core tests): $CORE_TESTED"
echo "  RUN_ID: $RUN_ID"

# Force clean
USE_TECH_MODELS=${USE_TECH_MODELS} RUN_ID=${RUN_ID} make -C ${ROOT_DIR}/hw/tb/ clean

CHIP_LEVEL_TEST=${CHIP_LEVEL_TEST} BOOT_MODE=${BOOT_MODE} PRELOAD_MODE=${PRELOAD_MODE} \
    PRELOAD_ELF=${PRELOAD_ELF} DBG=${DBG} NO_GUI=${NO_GUI} USE_TECH_MODELS=${USE_TECH_MODELS} \
    NETLIST_PATH=${NETLIST_PATH} RUN_ID=${RUN_ID} VCD_DUMP=${VCD_DUMP} SDF_FILE=${SDF_FILE} \
    POST_PNR=${POST_PNR} POST_SYN=${POST_SYN} DATA_FOLDER=${DATA_FOLDER} WAVE_SCOPE="${WAVE_SCOPE}" \
    WAVE_LOG=${WAVE_LOG} DEFINES="${DEFINES}" SIM_ARGS="${SIM_ARGS}" \
    DISABLE_ASSERTIONS=${DISABLE_ASSERTIONS} \
    DST_PROJECT_ROOT="${DST_PROJECT_ROOT:-unused}" \
    make run-soc
echo "[$(date +%T)] Simulation done."
