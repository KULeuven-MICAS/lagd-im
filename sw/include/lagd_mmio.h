#pragma once

#include <stdint.h>

// Write num_words consecutive 32-bit registers starting at reg[0] from vector[0..num_words-1].
static void lagd_write_vector(volatile uint32_t *reg, const uint32_t *vector, unsigned num_words) {
    for (unsigned i = 0; i < num_words; i++) {
        reg[i] = vector[i];
    }
}

// Read num_words consecutive 32-bit registers starting at reg[0] into out[0..num_words-1].
static void lagd_read_vector(volatile uint32_t *reg, uint32_t *out, unsigned num_words) {
    for (unsigned i = 0; i < num_words; i++) {
        out[i] = reg[i];
    }
}

// Set a single bit in the 32-bit register at reg through read-modify-write.
static void lagd_set_bit(volatile uint32_t *reg, unsigned bit) {
    *reg |= (1u << bit);
}

// Clear a single bit in the 32-bit register at reg through read-modify-write.
static void lagd_clear_bit(volatile uint32_t *reg, unsigned bit) {
    *reg &= ~(1u << bit);
}

// Write value into a multi-bit field of the 32-bit register at reg through read-modify-write,
// leaving every bit outside the field untouched. mask/offset match the *_MASK/*_OFFSET pair the
// reggen headers emit for each field (value is masked, not the field position -- an out-of-range
// value is silently truncated rather than corrupting neighboring fields).
static void lagd_write_field(volatile uint32_t *reg, uint32_t mask, unsigned offset, uint32_t value) {
    *reg = (*reg & ~(mask << offset)) | ((value & mask) << offset);
}

// Block until the given bit of the register at reg reads as 1 (want_set) or 0 (!want_set).
static void lagd_poll_bit(volatile uint32_t *reg, unsigned bit, int want_set) {
    if (want_set) {
        while ((*reg & (1u << bit)) == 0)
            ;
    } else {
        while ((*reg & (1u << bit)) != 0)
            ;
    }
}

// Block until the given bit of the register at reg differs from its value right now.
static void lagd_poll_bit_flip(volatile uint32_t *reg, unsigned bit) {
    int prev = (*reg & (1u << bit)) != 0;
    lagd_poll_bit(reg, bit, !prev);
}

// Block until the register at reg differs from its value right now; return the new value.
static uint32_t lagd_poll_word(volatile uint32_t *reg) {
    uint32_t old = *reg;
    uint32_t val;
    while ((val = *reg) == old)
        ;
    return val;
}
