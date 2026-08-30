// Calibrate J_UP vs J_DN:
//    1) Choose starting spot (power/speed trade-off) using J_DN
//    2) Turn J_UP until output varies

#ifndef CORE_TESTED
#define CORE_TESTED 1
#endif
#ifndef TARGET_COLUMN
#define TARGET_COLUMN 128
#endif
#ifndef WWL_CYCLES
#define WWL_CYCLES 100
#endif
#ifndef SPIN_WRITE_CYCLES
#define SPIN_WRITE_CYCLES 100
#endif
#ifndef CYCLE_PER_READ
#define CYCLE_PER_READ 5
#endif
#ifndef READ_NUM
#define READ_NUM 1
#endif
#ifndef PROBE_INTERVAL_MS
#define PROBE_INTERVAL_MS 200
#endif
#ifndef PROBE_COUNT
#define PROBE_COUNT 1000
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
    galena_stage_spin_write_timing(CORE_TESTED, SPIN_WRITE_CYCLES);
    galena_commit_spin_configure(CORE_TESTED);

    galena_zero_array(CORE_TESTED);
    uint32_t zero_spins[LAGD_SPIN_NUM_WORDS] = {0};
    galena_write_spins(CORE_TESTED, zero_spins);

    int column[NUM_SPIN];
    pattern_gen_alternate(column, 64, 4, TARGET_COLUMN);
    galena_write_column(CORE_TESTED, TARGET_COLUMN, /*cu_values=*/column, /*hu_value=*/0);

    printf("array + spins zeroed, column %u loaded\r\n", TARGET_COLUMN);

    uint32_t rtc_freq = *reg32(&__base_regs, CHESHIRE_RTC_FREQ_REG_OFFSET);
    uint64_t ticks_per_probe = (uint64_t)rtc_freq * PROBE_INTERVAL_MS / 1000;

    for (unsigned n = 0; n < PROBE_COUNT; n++) {
        unsigned bit = galena_acc_probe(CORE_TESTED, TARGET_COLUMN, CYCLE_PER_READ, READ_NUM);
        printf("t=%6ums | spin = %u\r\n", n * PROBE_INTERVAL_MS, bit);
        clint_spin_ticks(ticks_per_probe);
    }

    printf("FINISH\r\n");

    lagd_chip_finish();
    return 0;
}
