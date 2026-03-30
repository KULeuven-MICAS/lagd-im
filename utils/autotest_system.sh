#!/bin/bash

# Enable pipefail to catch errors in tee pipelines
set -o pipefail

# Wrapper to run this script in pixi environment
if [ -z "$PIXI_ENVIRONMENT_NAME" ]; then
    exec pixi run bash "$0" "$@"
fi

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

total=0
passed=0

# Log directory
LOG_DIR="utils/logs"

# Create logs directory if it doesn't exist
rm -rf "$LOG_DIR"
mkdir -p "$LOG_DIR"

# Function to run sys-run.sh commands
run_sys_test() {
    local cmd="$1"
    local test_name="$2"
    echo -e "${YELLOW}[SYS]${NC} $test_name"
    local start_time=$(date +%s)
    if eval "$cmd" > /dev/null 2>&1; then
        local end_time=$(date +%s)
        local elapsed=$((end_time - start_time))
        echo "SUCCESS (${elapsed}s)"
        ((passed++))
    else
        local end_time=$(date +%s)
        local elapsed=$((end_time - start_time))
        echo -e "${RED}FAILED${NC} (${elapsed}s)"
        exit 1
    fi
    ((total++))
    echo ""
}

# Function to run ut-run.sh commands
run_ut_test() {
    local cmd="$1"
    local test_name="$2"
    echo -e "${YELLOW}[UT]${NC} $test_name"
    local start_time=$(date +%s)
    if eval "$cmd" > /dev/null 2>&1; then
        local end_time=$(date +%s)
        local elapsed=$((end_time - start_time))
        echo -e "${GREEN}PASSED${NC} (${elapsed}s)"
        ((passed++))
    else
        local end_time=$(date +%s)
        local elapsed=$((end_time - start_time))
        echo -e "${RED}FAILED${NC} (${elapsed}s)"
        exit 1
    fi
    ((total++))
    echo ""
}

echo "========================================"
echo "Running Unit Tests (ut-run.sh)"
echo "========================================"
echo ""

OVERALL_START=$(date +%s)
run_ut_test "./ci/ut-run.sh --test=adder --tool=vsim |& tee $LOG_DIR/adder_sim_vsim.log" "adder (vsim)"
run_ut_test "./ci/ut-run.sh --test=adder --tool=vcs |& tee $LOG_DIR/adder_sim_vcs.log" "adder (vcs)"
run_ut_test "./ci/ut-run.sh --test=analog_model --tool=vsim |& tee $LOG_DIR/analog_model_sim_vsim.log" "analog_model (vsim)"
run_ut_test "./ci/ut-run.sh --test=analog_model --tool=vcs |& tee $LOG_DIR/analog_model_sim_vcs.log" "analog_model (vcs)"
run_ut_test "./ci/ut-run.sh --test=flip_manager --tool=vsim |& tee $LOG_DIR/flip_manager_sim_vsim.log" "flip_manager (vsim)"
run_ut_test "./ci/ut-run.sh --test=flip_manager --tool=vcs |& tee $LOG_DIR/flip_manager_sim_vcs.log" "flip_manager (vcs)"
run_ut_test "./ci/ut-run.sh --test=energy_monitor --tool=vsim |& tee $LOG_DIR/energy_monitor_sim_vsim.log" "energy_monitor (vsim)"
run_ut_test "./ci/ut-run.sh --test=digital_macro --tool=vsim |& tee $LOG_DIR/digital_macro_sim_vsim.log" "digital_macro (vsim)"
run_ut_test "./ci/ut-run.sh --test=ising_core_wrap --tool=vsim |& tee $LOG_DIR/ising_core_wrap_sim_vsim.log" "ising_core_wrap (vsim)"
run_ut_test "./ci/ut-run.sh --test=analog_macro_wrap --tool=vsim |& tee $LOG_DIR/analog_macro_wrap_sim_vsim.log" "analog_macro_wrap (vsim)"

echo "========================================"
echo "Running System Tests (sys-run.sh)"
echo "========================================"
echo ""

run_sys_test "./ci/sys-run.sh --binary=sw/tests/lagd_dcompute.spm.elf --tool=vsim |& tee $LOG_DIR/lagd_dcompute_sim_vsim.log" "lagd_dcompute (vsim)"
run_sys_test "./ci/sys-run.sh --binary=sw/tests/lagd_dcompute.spm.elf --tool=vcs |& tee $LOG_DIR/lagd_dcompute_sim_vcs.log" "lagd_dcompute (vcs)"
run_sys_test "CORE_TESTED=0 ./ci/sys-run.sh --binary=sw/tests/lagd_debug_dt.spm.elf --tool=vsim |& tee $LOG_DIR/lagd_debug_dt_sim_vsim.log" "lagd_debug_dt (vsim)"
run_sys_test "CORE_TESTED=0 ./ci/sys-run.sh --binary=sw/tests/lagd_debug_dt.spm.elf --tool=vcs |& tee $LOG_DIR/lagd_debug_dt_sim_vcs.log" "lagd_debug_dt (vcs)"
run_sys_test "CORE_TESTED=1 ./ci/sys-run.sh --binary=sw/tests/lagd_debug_spin.spm.elf --tool=vsim |& tee $LOG_DIR/lagd_debug_spin_sim_vsim.log" "lagd_debug_spin (vsim)"
run_sys_test "CORE_TESTED=1 ./ci/sys-run.sh --binary=sw/tests/lagd_debug_spin.spm.elf --tool=vcs |& tee $LOG_DIR/lagd_debug_spin_sim_vcs.log" "lagd_debug_spin (vcs)"
run_sys_test "./ci/sys-run.sh --binary=sw/tests/helloworld.spm.elf --tool=vsim |& tee $LOG_DIR/helloworld_sim_vsim.log" "helloworld (vsim)"
run_sys_test "./ci/sys-run.sh --binary=sw/tests/helloworld.spm.elf --tool=vcs |& tee $LOG_DIR/sim_vcs_helloworld.log" "helloworld (vcs)"


OVERALL_END=$(date +%s)
OVERALL_ELAPSED=$((OVERALL_END - OVERALL_START))

echo "========================================"
echo "Test Summary"
echo "========================================"
echo "Total: $total"
echo -e "Passed: ${GREEN}$passed${NC}"
echo -e "Failed: ${RED}$((total - passed))${NC}"
echo -e "Elapsed: ${YELLOW}${OVERALL_ELAPSED}s${NC}"
echo ""

if [ $passed -eq $total ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi