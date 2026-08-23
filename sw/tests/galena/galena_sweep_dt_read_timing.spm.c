// Find how low cycle_per_wwl_high/cycle_per_wwl_low (galena_stage_wwl_timing) can go before
// reads stop working consistently across the array. See galena_sweep_wwl_write_timing.spm.c
// for the write-side counterpart -- kept as a separate test since there is no reason to expect the
// two to share the same minimum (e.g. the read side additionally has to clear the WBL-read
// synchronizer pipe before data is valid, a constraint the write side doesn't have), even though
// both operations share the very same counters/registers (analog_dt_debug.sv has one
// wwl_high_counter/wwl_low_counter pair, reused for both).
//
// To isolate a read failure from a write failure, every write in this test runs at
// WWL_CYCLES_SAFE (deliberately generous, not just LAGD_BASE_CONFIG's default -- see below), while
// only the read side is swept down. That way a mismatch can only be attributed to the read.
//
// Only the two outermost j rows (0 and NUM_SPIN-1) are swept -- physically the farthest from the
// row drivers/periphery and so, presumably, the worst case for wire delay -- rather than the full
// array, to keep the sweep's runtime down.

#ifndef CORE_TESTED
#define CORE_TESTED 0
#endif
#ifndef WWL_CYCLES_START
#define WWL_CYCLES_START 100
#endif
#ifndef WWL_CYCLES_SAFE
#define WWL_CYCLES_SAFE 100
#endif
#ifndef WWL_CYCLES_STOP
#define WWL_CYCLES_STOP \
    1 // sweep continues all the way down to this cycle count regardless of failures
#endif

#include <stdint.h>
#include "printf.h"
#include "lagd_chip.h"
#include "lagd_bringup.h"
#include "lagd_galena_recipes.h"

#define NUM_TEST_ROWS 2
static const unsigned test_rows[NUM_TEST_ROWS] = {0, NUM_SPIN - 1};

// Read row back and check it against pattern (WBL) and its complement (WBLB). Returns 0 on match.
static int check_row(unsigned core, unsigned row, const uint32_t pattern[LAGD_WBL_NUM_WORDS]) {
    uint32_t wbl[LAGD_WBL_NUM_WORDS], wblb[LAGD_WBL_NUM_WORDS];
    galena_read_row(core, row, wbl, wblb);

    for (unsigned i = 0; i < LAGD_WBL_NUM_WORDS; i++) {
        if (wbl[i] != pattern[i] || wblb[i] != ~pattern[i]) return 1;
    }
    return 0;
}

int main(void) {
    lagd_chip_init();

    lagd_core_apply_config(CORE_TESTED, &LAGD_BASE_CONFIG);

    uint32_t checkerboard[LAGD_WBL_NUM_WORDS];
    uint32_t anti_checkerboard[LAGD_WBL_NUM_WORDS];
    for (unsigned i = 0; i < LAGD_WBL_NUM_WORDS; i++) {
        checkerboard[i] = (i % 2) ? 0xAAAAAAAAu : 0x55555555u;
        anti_checkerboard[i] = ~checkerboard[i];
    }

    int read_min = -1;
    for (unsigned cycles = WWL_CYCLES_START;; cycles--) {
        const uint32_t *pattern = (cycles % 2) ? checkerboard : anti_checkerboard;
        int pass = 1;
        for (unsigned i = 0; i < NUM_TEST_ROWS; i++) {
            unsigned row = test_rows[i];
            galena_stage_wwl_timing(CORE_TESTED, WWL_CYCLES_SAFE, WWL_CYCLES_SAFE);
            galena_write_row(CORE_TESTED, row, pattern);
            galena_stage_wwl_timing(CORE_TESTED, cycles, cycles);
            if (check_row(CORE_TESTED, row, pattern)) pass = 0;
        }
        printf("read calibration: %u cycles -> %s\r\n", cycles, pass ? "PASS" : "FAIL");
        if (pass) read_min = (int)cycles;
        if (cycles == WWL_CYCLES_STOP) break;
    }

    printf("read minimum: %d cycles\r\n", read_min);
    int failed = read_min < 0;
    printf(failed ? "FAIL\r\n" : "PASS\r\n");

    lagd_chip_finish();
    return failed;
}
