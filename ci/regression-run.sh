#!/bin/sh

# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Jiacong Sun <jiacong.sun@kuleuven.be>
# regression-run.sh - Build the software once and run every system test on it
#
# Run this before pushing a change to sw/ or hw/: it reports one line per test and exits non-zero
# as soon as any of them failed, so the result can be read at a glance.
#
# A simulation that fails does not make vsim exit non-zero, so each run is judged from its log:
# a test passes when the simulation reached its end, the program returned 0, the simulator counted
# no errors, and the marker the test prints on success is there.

show_usage()
{
    echo "LAGD: System test regression script"
    cat <<'EOF'
Usage: ./ci/regression-run.sh [[
    --tests=#list
    --data-folder=#data_folder
    --core-tested=#core_index
    --row-stride=#stride
    --log-dir=#path
    --skip-sw-build
    --help]]"
EOF
    echo "Example: $0 --tests=helloworld,lagd_debug_spin"
}

show_help()
{
    show_usage
    echo "  --tests=#list: Comma separated tests to run (default: all of them)"
    echo "  --data-folder=#data_folder: Data folder under sw/tests/data/ (default: default)"
    echo "  --core-tested=#core_index: Core driven by the single-core tests (default: 0)"
    echo "  --row-stride=#stride: Word line stride of lagd_debug_dt (default: 256, one J row)"
    echo "  --log-dir=#path: Where to keep the run logs (default: ci/regression-logs)"
    echo "  --skip-sw-build: Use the binaries already built under sw/tests/"
    echo "  --help: Show this help message"
    echo ""
    echo "Available tests: ${ALL_TESTS}"
}

SCRIPT_DIR=$(dirname "$0")
ROOT_DIR=$(realpath "${SCRIPT_DIR}/..")

# Ordered fastest first, so a broken build or setup shows up in minutes instead of at the end
ALL_TESTS="helloworld lagd_debug_spin lagd_debug_dt lagd_scompute lagd_dcompute lagd_reg"

TESTS="${ALL_TESTS}"
DATA_FOLDER="default"
CORE_TESTED=0
ROW_STRIDE=256
LOG_DIR="${ROOT_DIR}/ci/regression-logs"
SKIP_SW_BUILD=0

for i in "$@"; do
    case $i in
        --tests=*)
            TESTS=$(echo "${i#*=}" | tr ',' ' ')
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
        --row-stride=*)
            ROW_STRIDE="${i#*=}"
            shift
            ;;
        --log-dir=*)
            LOG_DIR="${i#*=}"
            shift
            ;;
        --skip-sw-build)
            SKIP_SW_BUILD=1
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

for t in ${TESTS}; do
    if ! echo " ${ALL_TESTS} " | grep -q " ${t} "; then
        echo "[ERROR] ./ci/regression-run.sh: unknown test '${t}'"
        echo "Available tests: ${ALL_TESTS}"
        exit 1
    fi
done

mkdir -p "${LOG_DIR}"

# The marker a test prints when it is happy. helloworld only has to reach the end of the program.
marker_of()
{
    case $1 in
        helloworld)     echo "" ;;
        lagd_reg)       echo "0 MISMATCH" ;;
        *)              echo "PASS" ;;
    esac
}

echo "Running the system test regression with the following parameters:"
echo "  TESTS: ${TESTS}"
echo "  DATA_FOLDER: ${DATA_FOLDER}"
echo "  CORE_TESTED (for single-core tests): ${CORE_TESTED}"
echo "  ROW_STRIDE (for lagd_debug_dt): ${ROW_STRIDE}"
echo "  LOG_DIR: ${LOG_DIR}"

# Build every binary once, so the tests below only pay for their simulation
if [ "${SKIP_SW_BUILD}" -eq 0 ]; then
    if ! python3 -c "import hjson" > /dev/null 2>&1; then
        echo "[ERROR] ./ci/regression-run.sh: python3 cannot import hjson, which the register"
        echo "        header generation needs. Building now would truncate the generated headers"
        echo "        under .bender/git/checkouts/. Put a python that has it first on the PATH:"
        echo "            export PATH=${ROOT_DIR}/.pixi/envs/default/bin:\$PATH"
        echo "        or install it with 'pip install --user hjson'."
        exit 1
    fi
    echo "[$(date +%T)] Building the software ..."
    if ! make -C "${ROOT_DIR}/sw" clean all DATA_FOLDER="${DATA_FOLDER}" \
        CORE_TESTED="${CORE_TESTED}" ROW_STRIDE="${ROW_STRIDE}" \
        > "${LOG_DIR}/sw-build.log" 2>&1; then
        echo "[ERROR] ./ci/regression-run.sh: software build failed, see ${LOG_DIR}/sw-build.log"
        exit 1
    fi
    echo "[$(date +%T)] Software build done."
else
    echo "[$(date +%T)] Skipping the software build."
fi

FAILED_TESTS=""
PASSED_TESTS=""
SUMMARY_FILE=$(mktemp)

for t in ${TESTS}; do
    LOG="${LOG_DIR}/${t}.log"
    START=$(date +%s)
    printf "[%s] %-18s running ...\n" "$(date +%T)" "${t}"

    "${ROOT_DIR}/ci/sys-run.sh" --binary="${ROOT_DIR}/sw/tests/${t}.spm.elf" \
        --data-folder="${DATA_FOLDER}" --core-tested="${CORE_TESTED}" --skip-sw-build \
        > "${LOG}" 2>&1
    RUN_STATUS=$?

    ELAPSED=$(( $(date +%s) - START ))
    REASON=""

    if [ ${RUN_STATUS} -ne 0 ]; then
        REASON="sys-run.sh exited ${RUN_STATUS}"
    elif ! grep -q "Simulation done" "${LOG}"; then
        REASON="the simulation did not reach its end"
    elif grep -q "FAILED: return code" "${LOG}"; then
        CODE=$(grep -o 'FAILED: return code [0-9]*' "${LOG}" | tail -1 | awk '{print $NF}')
        REASON="the program returned ${CODE}"
    elif grep -qE "^# \*\* (Error|Fatal)" "${LOG}"; then
        REASON="the simulator reported $(grep -cE '^# \*\* (Error|Fatal)' "${LOG}") error(s)"
    else
        MARKER=$(marker_of "${t}")
        if [ -n "${MARKER}" ] && ! grep -q "${MARKER}" "${LOG}"; then
            REASON="'${MARKER}' missing from the output"
        fi
    fi

    if [ -z "${REASON}" ]; then
        printf "  %-18s [PASS] %4ds  %s\n" "${t}" "${ELAPSED}" "${LOG}" >> "${SUMMARY_FILE}"
        PASSED_TESTS="${PASSED_TESTS} ${t}"
        printf "[%s] %-18s [PASS] (%ds)\n" "$(date +%T)" "${t}" "${ELAPSED}"
    else
        printf "  %-18s [FAIL] %4ds  %s  (%s)\n" "${t}" "${ELAPSED}" "${LOG}" "${REASON}" \
            >> "${SUMMARY_FILE}"
        FAILED_TESTS="${FAILED_TESTS} ${t}"
        printf "[%s] %-18s [FAIL] (%ds) %s\n" "$(date +%T)" "${t}" "${ELAPSED}" "${REASON}"
        # Show what the test itself said, the logs hold the rest
        grep -E "MISMATCH|FAIL|FAILED: return code|^# \*\* (Error|Fatal)" "${LOG}" | head -5 \
            | sed 's/^/      /'
    fi
done

echo ""
echo "=== Regression summary ==="
cat "${SUMMARY_FILE}"
rm -f "${SUMMARY_FILE}"

if [ -n "${FAILED_TESTS}" ]; then
    echo "=== FAILED:${FAILED_TESTS} ==="
    exit 1
fi

echo "=== All tests passed:${PASSED_TESTS} ==="
exit 0
