// Calibrate H_UP vs J_UP & J_DN:

#ifndef CORE_TESTED
#define CORE_TESTED 1
#endif
#ifndef TARGET_COLUMN
#define TARGET_COLUMN 128
#endif
#ifndef SCALE_FACTOR
#define SCALE_FACTOR 4
#endif
#ifndef SCALE_ROWS
#define SCALE_ROWS 32
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

    unsigned full_passes = SCALE_FACTOR / SCALE_ROWS;
    unsigned remainder = SCALE_FACTOR % SCALE_ROWS;

    int column[NUM_SPIN] = {0};
    unsigned row = 1;
    for (unsigned n = 0; n < SCALE_ROWS; n++) {
        if (row == TARGET_COLUMN) row++;
        unsigned magnitude = full_passes + (n < remainder ? 1 : 0);
        if (magnitude > 7) magnitude = 7;
        if (magnitude > 0) column[row] = -(int)magnitude;
        row++;
    }

    galena_write_column(CORE_TESTED, TARGET_COLUMN, /*cu_values=*/column, /*hu_value=*/1);

    printf("array + spins zeroed, column %u loaded: SCALE_FACTOR=%d over %d rows, HU=+1\r\n",
           TARGET_COLUMN, SCALE_FACTOR, SCALE_ROWS);
    printf("pattern:");
    for (unsigned i = 0; i < NUM_SPIN; i++)
        if (column[i]) printf(" [%u]=%d", i, column[i]);
    printf("\r\n");

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
