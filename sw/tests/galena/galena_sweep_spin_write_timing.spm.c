// Find how low cycle_per_spin_write (galena_stage_spin_write_timing) can go before spin writes stop
// working consistently. Analogous to galena_sweep_wwl_write_timing.spm.c for the dt path, but
// simpler: unlike dt's shared wwl_high/wwl_low counter pair (one register split between write and
// read timing), spin write and spin read live in entirely separate counter fields (counter_cfg_2 vs
// counter_cfg_3), so a swept write timing value can never bleed into the read side. No "safe timing
// swap-back" dance is needed here -- galena_read_spins's own fixed read timing is untouched by
// anything this test stages.
//
// Spins are written and checked as a whole (all 256 at once, via the shared strobe): there is no
// per-row addressing concept on the spin path the way there is for dt's WWL rows.

#ifndef CORE_TESTED
#define CORE_TESTED 0
#endif
#ifndef SPIN_WRITE_CYCLES_START
#define SPIN_WRITE_CYCLES_START 100
#endif
#ifndef SPIN_WRITE_CYCLES_STOP
#define SPIN_WRITE_CYCLES_STOP 1 // sweep continues all the way down to this cycle count regardless of failures
#endif

#include <stdint.h>
#include "printf.h"
#include "lagd_chip.h"
#include "lagd_bringup.h"
#include "lagd_galena_recipes.h"

// Write pattern, read it back, compare. Returns 0 on match.
static int check_spins(unsigned core, const uint32_t pattern[LAGD_SPIN_NUM_WORDS]) {
    galena_write_spins(core, pattern);
    uint32_t out[LAGD_SPIN_NUM_WORDS];
    galena_read_spins(core, out);
    for (unsigned i = 0; i < LAGD_SPIN_NUM_WORDS; i++) {
        if (out[i] != pattern[i]) return 1;
    }
    return 0;
}

int main(void) {
    lagd_chip_init();

    lagd_core_apply_config(CORE_TESTED, &LAGD_BASE_CONFIG);

    // The dt word lines must stay clear for the whole test: wwl_i and write_spin_i can never both
    // be driven.
    uint32_t no_wwl[LAGD_WWL_NUM_WORDS] = {0};
    galena_stage_wwl_pattern(CORE_TESTED, no_wwl, 0);
    galena_commit_dt_configure(CORE_TESTED);

    uint32_t checkerboard[LAGD_SPIN_NUM_WORDS];
    uint32_t anti_checkerboard[LAGD_SPIN_NUM_WORDS];
    for (unsigned i = 0; i < LAGD_SPIN_NUM_WORDS; i++) {
        checkerboard[i] = (i % 2) ? 0xAAAAAAAAu : 0x55555555u;
        anti_checkerboard[i] = ~checkerboard[i];
    }

    int write_min = -1;
    for (unsigned cycles = SPIN_WRITE_CYCLES_START; ; cycles--) {
        const uint32_t *pattern = (cycles % 2) ? checkerboard : anti_checkerboard;
        galena_stage_spin_write_timing(CORE_TESTED, cycles);
        int pass = !check_spins(CORE_TESTED, pattern);
        printf("write calibration: %u cycles -> %s\r\n", cycles, pass ? "PASS" : "FAIL");
        if (pass) write_min = (int)cycles;
        if (cycles == SPIN_WRITE_CYCLES_STOP) break;
    }

    printf("write minimum: %d cycles\r\n", write_min);
    int failed = write_min < 0;
    printf(failed ? "FAIL\r\n" : "PASS\r\n");

    lagd_chip_finish();
    return failed;
}
