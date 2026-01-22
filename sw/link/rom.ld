/* Copyright 2025 KU Leuven. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/* Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be> */

INCLUDE common.ldh

SECTIONS {
  /* Put all LOAD sections in one contiguous output section */
  .misc : {
    *(.text._start)
    *(.text)
    *(.text.*)
    *(.rodata)
    *(.rodata.*)
    *(.data)
    *(.data.*)
    *(.srodata)
    *(.srodata.*)
    *(.sdata)
    *(.sdata.*)
    *(.bulk)
    *(.bulk.*)
  } > l2_spm AT>extrom

  /* BSS is not loaded, but initialized by CRT0 */
  .bss : ALIGN(16) {
    __bss_start = .;
    *(.bss)
    *(.bss.*)
    *(.sbss)
    *(.sbss.*)
    __bss_end = .;
  } > l2_spm
}