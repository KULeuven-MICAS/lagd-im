// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Jiacong Sun <jiacong.sun@kuleuven.be>
//
// LAGD-specific linker symbols, analogous to Cheshire's params.h.
// These symbols are resolved at link time (via --defsym in the Makefile
// or defined in the linker script).

#pragma once

// Base address of the LAGD Ising core register bank (IC_REGS_BASE_ADDR)
extern void *__base_lagd_regs;
