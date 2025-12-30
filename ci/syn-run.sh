#!/bin/sh

# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>
# syn-run.sh - Run synthesis flow
# List of parameters:
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
    echo "Usage: $0 [--tech=#tech_node [--tle=#lagd_soc --run_id=#run_id --run_dir=#run_dir --work_dir=#work_dir --design_inputs_dir=#design_inputs_dir --hdl_flist=#flist_path --sdc_constraints=#sdc_path --corner=#corner --ddc=#ddc_path][--help]]"
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
    echo "  --corner=#corner: Process corner for synthesis (default: tt)"
    echo "  --ddc=#ddc_path: Path to DDC file (default: no path)"
    echo "  --help: Show this help message"
}

SCRIPT_DIR=$(dirname "$0")
PROJECT_ROOT=$(realpath "${SCRIPT_DIR}/..")

ENV_VARS="PROJECT_ROOT=${PROJECT_ROOT}"

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

# TODO: add make commands to generate all the files needed for synthesis/ before running this script

# source /esat/micas-data/software/scripts/syn_vU-2022.12-SP2.rc
TMP_DIR="${PROJECT_ROOT}/.dc-tmp"
mkdir -p "${TMP_DIR}"

TCL_SCRIPT="${PROJECT_ROOT}/target/syn/src/syn.tcl"
# Extract DDC variable from ENV_VARS
DDC=$(echo $ENV_VARS | tr ' ' '\n' | grep '^DDC=' | cut -d'=' -f2-)
if [ -n "$DDC" ] then # if DDC variable is set
  DDC_FILE_PATH="${DDC}"
  if [[ ! "$DDC" == *.ddc ]]; then # if DDC not a .ddc file
    DDC_FILE_PATH=( "${DDC_FILE_PATH}/*.ddc" )
  fi
  if [ ! -f "$DDC_FILE_PATH" ]; then
    echo "[ERROR] ./ci/syn-run.sh: DDC file not found at path: ${DDC_FILE_PATH}"
    exit 1
  fi
  echo "[INFO] ./ci/syn-run.sh: Reading DDC file: ${DDC_FILE_PATH}"
  ENV_VARS="${ENV_VARS} DDC_FILE_PATH=${DDC_FILE_PATH}"
  TCL_SCRIPT="${PROJECT_ROOT}/target/syn/src/read_ddc.tcl"
fi

CMD="$ENV_VARS dc_shell -f $TCL_SCRIPT"
echo "Running synthesis with command:"
echo "${CMD}"
cd "${TMP_DIR}" && eval $CMD > ${TMP_DIR}/syn_run.log 2>&1
echo "[INFO] ./ci/syn-run.sh: Synthesis completed. Log available at ${TMP_DIR}/syn_run.log"