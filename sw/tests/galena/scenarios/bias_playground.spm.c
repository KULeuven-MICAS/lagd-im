// Play around with various column-patterns.
//   1) zero the whole array (all J rows + h-row) AND every spin's stored value
//   2) write a chosen pattern into TARGET_COLUMN's CU column
//   3) every PROBE_INTERVAL_MS milliseconds, acc-probe TARGET_COLUMN's own spin, repeat for PROBE_COUNT times.

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
#define PROBE_COUNT 100
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

    // int column[NUM_SPIN] = {
    //   [20] = 7,
    //   [21] = -1, [22] = -1, [23] = -1, [24] = -1,[25] = -1, [26] = -1,
    //   [31] = -1, [32] = -1, [33] = -1, [34] = -1,[35] = -1, [36] = -1,
    //   [40] = 7,
    // };
    // galena_write_column(CORE_TESTED, TARGET_COLUMN, /*cu_values=*/column, /*hu_value=*/0);

    int column[NUM_SPIN];
    pattern_gen_alternate(column, 64, 4, TARGET_COLUMN);
    column[1] = -1;
    column[2] = -1;
    column[3] = -1;
    column[4] = -1;
    column[5] = 4;
    galena_write_column(CORE_TESTED, TARGET_COLUMN, /*cu_values=*/column, /*hu_value=*/1);

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
