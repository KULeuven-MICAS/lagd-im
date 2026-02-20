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

  /* J coupling matrix: loaded directly into core 0's l1_j_spm by the ELF loader */
  .l1j_data : { KEEP(*(.l1j_data)) } > l1_j_spm

  /* Flip candidate vectors: loaded directly into core 0's l1_f_spm by the ELF loader */
  .l1f_data : { KEEP(*(.l1f_data)) } > l1_f_spm
}
