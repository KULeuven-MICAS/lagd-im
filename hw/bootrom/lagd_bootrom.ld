/* Copyright 2025 KU Leuven. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/* Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be> */

/* Inspired from https://github.com/pulp-platform/cheshire/blob/main/hw/bootrom/cheshire_bootrom.ld */

INCLUDE common.ldh

SECTIONS {

  .text : {
    *(.text._start)
    *(.text)
    *(.text.*)
  } > bootrom

  .misc : ALIGN(16) {
    *(.rodata)
    *(.rodata.*)
    *(.data)
    *(.data.*)
    *(.srodata)
    *(.srodata.*)
    *(.sdata)
    *(.sdata.*)
  } > bootrom

  . = ALIGN(32);
  __bss_start = .;
  .bss : {
    *(.bss)
    *(.bss.*)
    *(.sbss)
    *(.sbss.*)
  } > bootrom
  . = ALIGN(32);
  __bss_end = .;

  .bulk : ALIGN(16) {
    *(.bulk)
    *(.bulk.*)
  } > bootrom
}