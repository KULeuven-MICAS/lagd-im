// Copyright 2026 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Toon Bettens <toon.bettens@kuleuven.be>

// Step 2/4 of the single-spin-feedback procedure (run galena_zero_array.spm.c first): set every
// column's H-bias to H_VALUE, and every column's CU_ROW coupling to CU_VALUE (default: the J-row
// right next to the H-row, i.e. NUM_SPIN-1), then read both rows straight back and print them, so
// you can confirm they actually encode the intended value on every column before moving on.

#ifndef CORE_TESTED
#define CORE_TESTED 0
#endif
#ifndef H_VALUE
#define H_VALUE 1
#endif
#ifndef CU_ROW
#define CU_ROW (NUM_SPIN - 1)
#endif
#ifndef CU_VALUE
#define CU_VALUE 1
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

    galena_write_row_broadcast(CORE_TESTED, NUM_SPIN, H_VALUE);
    galena_write_row_broadcast(CORE_TESTED, CU_ROW, CU_VALUE);

    uint32_t wbl[LAGD_WBL_NUM_WORDS], wblb[LAGD_WBL_NUM_WORDS];
    galena_read_row(CORE_TESTED, NUM_SPIN, wbl, wblb);

    printf("H-row (H_VALUE=%+d):\r\n", H_VALUE);
    printf("  wbl :");
    for (unsigned i = 0; i < LAGD_WBL_NUM_WORDS; i++) printf(" %08x", wbl[i]);
    printf("\r\n");
    printf("  wblb:");
    for (unsigned i = 0; i < LAGD_WBL_NUM_WORDS; i++) printf(" %08x", wblb[i]);
    printf("\r\n");

    galena_read_row(CORE_TESTED, CU_ROW, wbl, wblb);

    printf("CU-row %u (CU_VALUE=%+d):\r\n", (unsigned)CU_ROW, CU_VALUE);
    printf("  wbl :");
    for (unsigned i = 0; i < LAGD_WBL_NUM_WORDS; i++) printf(" %08x", wbl[i]);
    printf("\r\n");
    printf("  wblb:");
    for (unsigned i = 0; i < LAGD_WBL_NUM_WORDS; i++) printf(" %08x", wblb[i]);
    printf("\r\n");
    printf("PASS\r\n");

    lagd_chip_finish();
    return 0;
}
