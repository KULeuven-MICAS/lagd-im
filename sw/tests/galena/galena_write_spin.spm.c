// Write a 256-bit spin patterns, snapshot it back and check it.

#ifndef CORE_TESTED
#define CORE_TESTED 0
#endif
#ifndef SPIN_WRITE_CYCLES
#define SPIN_WRITE_CYCLES 5
#endif
#ifndef VERBOSE
#define VERBOSE 0
#endif

#include <stdint.h>
#include "printf.h"
#include "lagd_chip.h"
#include "lagd_bringup.h"
#include "lagd_galena_recipes.h"

// Write spins, read them back and compare. Returns 0 on a full match.
static int galena_write_and_check_spins(unsigned core, const char *name, const uint32_t spins[LAGD_SPIN_NUM_WORDS]) {
    galena_write_spins(core, spins);

    uint32_t out[LAGD_SPIN_NUM_WORDS];
    galena_read_spins(core, out);

    int pass = 1;
    for (unsigned i = 0; i < LAGD_SPIN_NUM_WORDS; i++) {
        if (out[i] != spins[i]) pass = 0;
    }
    if (VERBOSE && !pass) {
        printf("pattern %-12s -> FAIL\r\n", name);
        for (unsigned i = 0; i < LAGD_SPIN_NUM_WORDS; i++)
            printf("  word %u: wrote %08x read %08x\r\n", i, spins[i], out[i]);
    }
    return !pass;
}

int main(void) {
    lagd_chip_init();

    lagd_core_apply_config(CORE_TESTED, &LAGD_BASE_CONFIG);
    galena_stage_spin_write_timing(CORE_TESTED, SPIN_WRITE_CYCLES);
    galena_commit_spin_configure(CORE_TESTED);

    uint32_t all_zero[LAGD_SPIN_NUM_WORDS] = {0};
    uint32_t all_one[LAGD_SPIN_NUM_WORDS];
    uint32_t checkerboard[LAGD_SPIN_NUM_WORDS];
    uint32_t anti_checkerboard[LAGD_SPIN_NUM_WORDS];
    for (unsigned i = 0; i < LAGD_SPIN_NUM_WORDS; i++) {
        all_one[i] = 0xFFFFFFFFu;
        checkerboard[i] = (i % 2) ? 0xAAAAAAAAu : 0x55555555u;
        anti_checkerboard[i] = ~checkerboard[i];
    }

    unsigned failed = 0, tested = 0;
    failed += galena_write_and_check_spins(CORE_TESTED, "all-one", all_one);                   tested++;
    failed += galena_write_and_check_spins(CORE_TESTED, "all-zero", all_zero);                 tested++;
    failed += galena_write_and_check_spins(CORE_TESTED, "checker", checkerboard);              tested++;
    failed += galena_write_and_check_spins(CORE_TESTED, "anti-checker", anti_checkerboard);    tested++;
    printf("%u/%u patterns PASS, %u FAIL\r\n", tested - failed, tested, failed);
    printf(failed ? "FAIL\r\n" : "PASS\r\n");

    lagd_chip_finish();
    return failed;
}
