// Coverage testcase for the lagd_galena_recipes.h dt-path API:
// sweep-check every WWL row (0..NUM_SPIN-1 j rows plus the h row)

#ifndef CORE_TESTED
#define CORE_TESTED 0
#endif
#ifndef VERBOSE
#define VERBOSE 0
#endif

#include <stdint.h>
#include "printf.h"
#include "lagd_chip.h"
#include "lagd_bringup.h"
#include "lagd_galena_recipes.h"

// Write pattern into row via galena_write_row, read it back via galena_read_row, and check the
// whole row against pattern (WBL) and its bitwise complement (WBLB). Returns 0 on full match.
// Prints per-row/per-pattern detail only when VERBOSE -- main()'s summary count covers the
// routine case.
static int galena_write_and_check_row(unsigned core, unsigned row, const char *name,
                                      const uint32_t pattern[LAGD_WBL_NUM_WORDS]) {
    galena_write_row(core, row, pattern);

    uint32_t wbl[LAGD_WBL_NUM_WORDS], wblb[LAGD_WBL_NUM_WORDS];
    galena_read_row(core, row, wbl, wblb);

    int pass = 1;
    for (unsigned i = 0; i < LAGD_WBL_NUM_WORDS; i++) {
        if (wbl[i] != pattern[i] || wblb[i] != ~pattern[i]) pass = 0;
    }
    if (VERBOSE && !pass) printf("row %3u pattern %-9s -> FAIL\r\n", row, name);
    return !pass;
}

int main(void) {
    lagd_chip_init();

    lagd_core_apply_config(CORE_TESTED, &LAGD_BASE_CONFIG);

    uint32_t all_zero[LAGD_WBL_NUM_WORDS] = {0};
    uint32_t all_one[LAGD_WBL_NUM_WORDS];
    uint32_t checkerboard[LAGD_WBL_NUM_WORDS];
    for (unsigned i = 0; i < LAGD_WBL_NUM_WORDS; i++) {
        all_one[i] = 0xFFFFFFFFu;
        checkerboard[i] = (i % 2) ? 0xAAAAAAAAu : 0x55555555u;
    }

    unsigned failed = 0, tested = 0;
    for (unsigned row = 0; row <= NUM_SPIN; row++) {
        failed += galena_write_and_check_row(CORE_TESTED, row, "all-one", all_one);
        failed += galena_write_and_check_row(CORE_TESTED, row, "all-zero", all_zero);
        failed += galena_write_and_check_row(CORE_TESTED, row, "checkerboard", checkerboard);
        tested += 3;
    }
    printf("%u/%u row/pattern checks PASS, %u FAIL\r\n", tested - failed, tested, failed);
    printf(failed ? "FAIL\r\n" : "PASS\r\n");

    lagd_chip_finish();
    return failed;
}
