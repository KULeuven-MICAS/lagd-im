#pragma once

#include "util.h"
#include "lagd_mmio.h"
#include "lagd_core_reg.h"
#include "lagd_define.h"

// Base address of a given core's register block.
static void *lagd_core_base(unsigned core) {
    return (void *)((uintptr_t)IC_REGS_BASE_ADDR + (uintptr_t)core * IC_NUM_REGS);
}

// Pointer to a single register of the given core's block, given its byte offset.
static volatile uint32_t *lagd_core_reg(unsigned core, uint32_t offset) {
    return reg32(lagd_core_base(core), offset);
}

// Write num_words consecutive 32-bit registers of the given core, starting at offset.
static void lagd_core_write_vector(unsigned core, uint32_t offset, const uint32_t *pattern, unsigned num_words) {
    lagd_write_vector(lagd_core_reg(core, offset), pattern, num_words);
}

// Read num_words consecutive 32-bit registers of the given core, starting at offset.
static void lagd_core_read_vector(unsigned core, uint32_t offset, uint32_t *out, unsigned num_words) {
    lagd_read_vector(lagd_core_reg(core, offset), out, num_words);
}

// Set a single bit in a register of the given core, given its byte offset.
static void lagd_core_set_bit(unsigned core, uint32_t offset, unsigned bit) {
    lagd_set_bit(lagd_core_reg(core, offset), bit);
}

// Clear a single bit in a register of the given core, given its byte offset.
static void lagd_core_clear_bit(unsigned core, uint32_t offset, unsigned bit) {
    lagd_clear_bit(lagd_core_reg(core, offset), bit);
}

// Write value into a multi-bit field of a register of the given core, given its byte offset and
// the field's *_MASK/*_OFFSET pair, through read-modify-write.
static void lagd_core_write_field(unsigned core, uint32_t offset, uint32_t mask, unsigned field_offset, uint32_t value) {
    lagd_write_field(lagd_core_reg(core, offset), mask, field_offset, value);
}

// Block until the given bit of a register of the given core reads as 1 (want_set) or 0 (!want_set).
static void lagd_core_poll_bit(unsigned core, uint32_t offset, unsigned bit, int want_set) {
    lagd_poll_bit(lagd_core_reg(core, offset), bit, want_set);
}
