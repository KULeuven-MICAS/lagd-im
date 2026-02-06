// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

`ifndef BOOT_MODE
`define BOOT_MODE 0
`endif

`ifndef PRELOAD_MODE
`define PRELOAD_MODE 0
`endif

`ifndef PRELOAD_ELF
`define PRELOAD_ELF ""
`endif

module tb_lagd_chip ();

  fixture_lagd_chip fix ();
  
  string      preload_elf;
  logic [1:0] boot_mode;
  logic [1:0] preload_mode;
  bit [31:0]  exit_code;

  assign boot_mode = `BOOT_MODE;
  assign preload_mode = `PRELOAD_MODE;
  assign preload_elf = `PRELOAD_ELF;

  initial begin
    $display("Boot mode: %0d, Preload mode: %0d, Preload ELF: %s", boot_mode, preload_mode, preload_elf);
    // Wait for reset
    fix.vip.wait_for_reset();
    
    if (boot_mode == 0) begin
      case (preload_mode)
        0: begin      // JTAG
          fix.vip.jtag_init();
          fix.vip.jtag_elf_run(preload_elf);
          fix.vip.jtag_wait_for_eoc(exit_code);
        end 1: begin  // UART
          fix.vip.uart_debug_elf_run_and_wait(preload_elf, exit_code);
        end default: begin
          $fatal(1, "Unsupported preload mode %d (reserved)!", preload_mode);
        end
      endcase
    end else if (boot_mode == 1) begin
      $fatal(1, "Unsupported boot mode %d (SD Card)!", boot_mode);
    end
    
    // Wait for the UART to finish reading the current byte
    wait (fix.vip.uart_reading_byte == 0);
    $finish;
  end
endmodule