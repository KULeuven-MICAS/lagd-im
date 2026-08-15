#pragma once

#include "regs/cheshire.h"
#include "dif/clint.h"
#include "dif/uart.h"
#include "params.h"
#include "util.h"

// Bring up the UART so printf() produces readable output.
static void lagd_chip_init(void) {
    uint32_t rtc_freq = *reg32(&__base_regs, CHESHIRE_RTC_FREQ_REG_OFFSET);
    uint64_t core_freq = clint_get_core_freq(rtc_freq, 2500);
    uart_init(&__base_uart, core_freq, __BOOT_BAUDRATE);
}

// Flush any remaining printf writes out over the wire.
static void lagd_chip_finish(void) {
    uart_write_flush(&__base_uart);
}
