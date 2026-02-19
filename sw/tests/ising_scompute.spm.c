// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Author: Jiacong Sun <jiacong.sun@kuleuven.be>

#include "regs/cheshire.h"
#include "dif/clint.h"
#include "dif/uart.h"
#include "params.h"
#include "util.h"
#include "printf.h"
#include "data/model_1_data.h"

int main(void) {
    // UART init
    uint32_t rtc_freq = *reg32(&__base_regs, CHESHIRE_RTC_FREQ_REG_OFFSET);
    uint64_t reset_freq = clint_get_core_freq(rtc_freq, 2500);
    uart_init(&__base_uart, reset_freq, __BOOT_BAUDRATE);

    printf("=== Ising Model Data Verification ===\r\n");

    // Print data summary
    printf("model_j_data addr   : %p\r\n",   (void *)model_j_data);
    printf("MODEL_J_LEN         : %u\r\n",   (unsigned)MODEL_J_LEN);
    printf("MODEL_H_U32_LEN     : %u\r\n",   (unsigned)MODEL_H_U32_LEN);
    printf("model_scaling_factor: %u\r\n",   (unsigned)model_scaling_factor);
    printf("model_offset        : %f\r\n",   model_offset);

    // Compute and verify J matrix XOR checksum
    uint64_t j_xor = 0;
    for (unsigned i = 0; i < MODEL_J_LEN; i++)
        j_xor ^= model_j_data[i];
    printf("J XOR checksum      : 0x%016llx ", (unsigned long long)j_xor);
    if (j_xor == MODEL_J_XOR_CHECKSUM)
        printf("[PASS]\r\n");
    else
        printf("[FAIL] expected 0x%016llx\r\n", (unsigned long long)MODEL_J_XOR_CHECKSUM);

    // Compute and verify h vector XOR checksum
    uint32_t h_xor = 0;
    for (unsigned i = 0; i < MODEL_H_U32_LEN; i++)
        h_xor ^= model_h_data[i];
    printf("H XOR checksum      : 0x%08x ", h_xor);
    if (h_xor == MODEL_H_XOR_CHECKSUM)
        printf("[PASS]\r\n");
    else
        printf("[FAIL] expected 0x%08x\r\n", MODEL_H_XOR_CHECKSUM);

    printf("=== DONE ===\r\n");
    uart_write_flush(&__base_uart);
    return 0;
}
