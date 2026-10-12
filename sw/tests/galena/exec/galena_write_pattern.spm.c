// Copyright 2026 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Toon Bettens <toon.bettens@kuleuven.be>

// Write a pattern to one column and exit -- no readback, no checking. Meant as a simple bench
// tool to get a known coupling pattern onto the chip (e.g. before probing it by hand), not a test.

#ifndef CORE_TESTED
#define CORE_TESTED 0
#endif
#ifndef TARGET_COLUMN
#define TARGET_COLUMN 128
#endif
#ifndef WWL_CYCLES
#define WWL_CYCLES 1000
#endif

#include <stdint.h>
#include "printf.h"
#include "lagd_chip.h"
#include "lagd_bringup.h"
#include "lagd_galena_recipes.h"
#include "lagd_galena_patterns.h"

int main(void) {
    lagd_chip_init();

    lagd_core_apply_config(CORE_TESTED, &LAGD_BASE_CONFIG);
    galena_stage_wwl_timing(CORE_TESTED, WWL_CYCLES, WWL_CYCLES);
    galena_commit_dt_configure(CORE_TESTED);

    // Edit this to try a different pattern (see lagd_galena_patterns.h for the full list).
    int h_value = 0;

    galena_write_column(CORE_TESTED, TARGET_COLUMN, pattern_neg5_rows_1_16, h_value);

    printf("column %u loaded, HU = %+d\r\n", TARGET_COLUMN, h_value);
    printf("PASS\r\n");

    lagd_chip_finish();
    return 0;
}
