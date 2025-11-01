#!/bin/sh

# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>
# syn-run.sh - Run synthesis flow
# List of parameters:
#   PROJECT_ROOT
#   TECH_NODE
#   SYN_TLE
#   RUN_ID
#   RUN_DIR
#   WORK_DIR
#   DESIGN_INPUTS_DIR
#   HDL_FILE_LIST
#   SDC_CONSTRAINTS

set -e

# Parameters to override defaults
show_usage()
{
    echo "LAGD: Synthesis run trigger script"
    echo "Usage: $0 [--tech=#tech_node [--tle=#lagd_soc --run_id=#run_id --run_dir=#run_dir --work_dir=#work_dir --design_inputs_dir=#design_inputs_dir --hdl_flist=#flist_path --sdc_constraints=#sdc_path [--help]]"
    echo "Example: $0 --tech=sky130hd --run_id=001"
}

show_help()
{
    show_usage
    echo "  --tech=#tech_node: Technology node for synthesis (see target/syn/tech/ for supported nodes)"
    echo "  --tle=#lagd_soc: Synthesis target (default: lagd_soc)"
    echo "  --run_id=#run_id: Unique identifier for this synthesis run (to distinguish multiple runs)"
    echo "  --run_dir=#run_dir: Root directory for this synthesis run (default: \$PROJECT_ROOT/runs/\$SYN_TLE-\$TECH_NODE-\$RUN_ID)"
    echo "  --work_dir=#work_dir: Working directory for this synthesis run (default: \$RUN_DIR/work)"
    echo "  --design_inputs_dir=#design_inputs_dir: Directory containing design inputs (default: \$PROJECT_ROOT/inputs)"
    echo "  --hdl_flist=#flist_path: Path to HDL file list (default: \$DESIGN_INPUTS_DIR/hdl.flist)"
    echo "  --sdc_constraints=#sdc_path: Path to SDC constraints file (default: \$DESIGN_INPUTS_DIR/lagd.sdc)"
    echo "  --help: Show this help message"
}

SCRIPT_DIR=$(dirname "$0")
PROJECT_ROOT=$(realpath "${SCRIPT_DIR}/..")

ENV_VARS="PROJECT_ROOT=${PROJECT_ROOT}"

# Parse args: --VAR=value or --env-file=...
for i in "$@"; do
  case $i in
    --help|-h)
      show_help
      exit 0
      ;;
    --*=*)
      key="${i%%=*}"; key="${key#--}"; KEY="${key^^}"
      val="${i#*=}"
      echo "[INFO] ./ci/syn-run.sh: Setting ${KEY}=${val}"
      ENV_VARS="${ENV_VARS} ${KEY}=${val}"
      shift
      ;;
    *)
      echo "[ERROR] ./ci/syn-run.sh: Unknown option: $i"
      show_usage
      exit 1
      ;;
  esac
done

# source /esat/micas-data/software/scripts/syn_vU-2022.12-SP2.rc

CMD="$ENV_VARS dc_shell -f ${PROJECT_ROOT}/target/syn/syn.tcl"
echo "Running synthesis with command:"
echo "${CMD}"
eval $CMD