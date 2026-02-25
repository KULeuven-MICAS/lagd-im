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
  .l1j_data_c0 : { KEEP(*(.l1j_data_c0)) } > l1_j_spm_c0

  /* J coupling matrix: replicated into core 1's l1_j_spm_1 by the ELF loader */
  .l1j_data_c1 : { KEEP(*(.l1j_data_c1)) } > l1_j_spm_c1

  /* Flip candidate vectors: loaded directly into core 0's l1_f_spm by the ELF loader */
  .l1f_data_c0 : { KEEP(*(.l1f_data_c0)) } > l1_f_spm_c0

  /* Flip candidate vectors: replicated into core 1's l1_f_spm_1 by the ELF loader */
  .l1f_data_c1 : { KEEP(*(.l1f_data_c1)) } > l1_f_spm_c1
}
