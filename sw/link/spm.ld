/* Copyright 2025 KU Leuven. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/* Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be> */

INCLUDE common.ldh

SECTIONS {
  .text : {
    *(.text._start)
    *(.text)
    *(.text.*)
  } > l2_spm

  .misc : ALIGN(16) {
    *(.rodata)
    *(.rodata.*)
    *(.data)
    *(.data.*)
    *(.srodata)
    *(.srodata.*)
    *(.sdata)
    *(.sdata.*)
  } > l2_spm

  .bss : ALIGN(16) {
    __bss_start = .;
    *(.bss)
    *(.bss.*)
    *(.sbss)
    *(.sbss.*)
    __bss_end = .;
  } > l2_spm

  .bulk : ALIGN(16) {
    *(.bulk)
    *(.bulk.*)
  } > l2_spm
}
