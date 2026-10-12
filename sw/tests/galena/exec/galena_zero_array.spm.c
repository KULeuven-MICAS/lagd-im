// Copyright 2026 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Toon Bettens <toon.bettens@kuleuven.be>

// Write zero to every row of the J-array (rows 0..NUM_SPIN, i.e. all data rows plus the H-row).

#ifndef CORE_TESTED
#define CORE_TESTED 0
#endif
#ifndef WWL_CYCLES
#define WWL_CYCLES 100
#endif

#include <stdint.h>
#include "printf.h"
#include "lagd_chip.h"
#include "lagd_bringup.h"
#include "lagd_galena_recipes.h"

int main(void) {
    lagd_chip_init();

    lagd_core_apply_config(CORE_TESTED, &LAGD_BASE_CONFIG);
    galena_stage_wwl_timing(CORE_TESTED, WWL_CYCLES, WWL_CYCLES);
    galena_commit_dt_configure(CORE_TESTED);

    galena_zero_array(CORE_TESTED);
    printf("array zeroed\r\n");

    lagd_chip_finish();
    return 0;
}
