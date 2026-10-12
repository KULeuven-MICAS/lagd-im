#!/usr/bin/env bash

# Copyright 2026 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
# Author: Toon Bettens <toon.bettens@kuleuven.be>

#
# Build one ELF per scenario / core / scaling-factor combination, into a folder that is populated
# once and then reused. Re-running only builds what is missing, so it is cheap to call again after
# adding a core or extending the scaling-factor range.
#
#   calibrate_j          does not use SCALING_FACTOR  ->  one ELF per core
#   bias_review CU_ONLY  same: with CU_ONLY the MIXED and OPPOSED families are skipped, so no case
#                        has a non-zero HU and SCALING_FACTOR drops out of every prediction
#                        (total = cu_net + SCALING_FACTOR*hu_value with hu_value == 0)
#   calibrate_hup  }
#   calibrate_hdn  }     swept over SCALING_FACTOR  ->  one ELF per core per scaling factor
#   bias_review    }
#
# With the defaults that is 2 + 2 + 2*31*3 = 190 ELFs, named e.g.
#
#   calibrate_j_core0.elf
#   bias_review_core0_cuonly.elf
#   calibrate_hup_core0_sf07.elf
#   bias_review_core1_sf31.elf
#
# Usage:
#   utils/gen_calibration_elfs.sh              # build whatever is missing
#   FORCE=1 utils/gen_calibration_elfs.sh      # rebuild everything
#   CORES="1" SCALING_FACTORS="4 8" utils/gen_calibration_elfs.sh
#   OUT_DIR=/tmp/cal utils/gen_calibration_elfs.sh
#
# Each build goes through the normal `make tests/.../x.spm.elf COMPILE_ARGS="..."` path and the
# result is copied out immediately, since the next build overwrites it in place. The Makefile's
# FORCE rule is what makes that work -- make cannot see that COMPILE_ARGS changed, so without it
# the second and later builds would be skipped as up to date.

set -euo pipefail

SW_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
OUT_DIR="${OUT_DIR:-$SW_DIR/calibration_elfs}"
CORES="${CORES:-0 1}"
SCALING_FACTORS="${SCALING_FACTORS:-$(seq 1 31)}"
FORCE="${FORCE:-0}"

cd "$SW_DIR"
mkdir -p "$OUT_DIR"

built=0
skipped=0

# build <scenario> <output-name> <define>...
build() {
    local scenario=$1 out=$2
    shift 2
    local src="tests/galena/bias/${scenario}.spm.elf"
    local dest="${OUT_DIR}/${out}.elf"

    if [[ -f "$dest" && "$FORCE" != "1" ]]; then
        skipped=$((skipped + 1))
        return
    fi

    printf '  %-34s %s\n' "$out" "$*"
    make "$src" COMPILE_ARGS="$*" >/dev/null
    cp "$src" "$dest"
    built=$((built + 1))
}

echo "Output: $OUT_DIR"
echo "Cores : $CORES"
echo "Scales: $(echo "$SCALING_FACTORS" | tr '\n' ' ')"
echo

# Scenarios that do not depend on SCALING_FACTOR: one ELF per core.
for core in $CORES; do
    build calibrate_j "calibrate_j_core${core}" "CORE_TESTED=${core}"
    build bias_review "bias_review_core${core}_cuonly" "CORE_TESTED=${core}" "CU_ONLY=1"
done

for core in $CORES; do
    for sf in $SCALING_FACTORS; do
        printf -v sf_padded '%02d' "$sf"
        for scenario in calibrate_hup calibrate_hdn bias_review; do
            build "$scenario" "${scenario}_core${core}_sf${sf_padded}" \
                "CORE_TESTED=${core}" "SCALING_FACTOR=${sf}"
        done
    done
done

echo
echo "Built $built, skipped $skipped (already present), $(ls -1 "$OUT_DIR" | wc -l) ELFs total in $OUT_DIR"
