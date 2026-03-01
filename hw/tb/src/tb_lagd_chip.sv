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

`ifndef CHIP_LEVEL_TEST
`define CHIP_LEVEL_TEST 0
`endif

`include "lagd_test/tb_common.svh"

module tb_lagd_chip ();

  localparam int unsigned ChipTest = `CHIP_LEVEL_TEST;
  fixture_lagd_chip #(.ChipTest(ChipTest)) fix ();
  
  string      preload_elf;
  logic [1:0] boot_mode;
  logic [1:0] preload_mode;
  logic enable_vcd_dumping;
  bit [31:0]  exit_code;

  assign boot_mode = `BOOT_MODE;
  assign preload_mode = `PRELOAD_MODE;
  assign preload_elf = `PRELOAD_ELF;

  initial begin
    enable_vcd_dumping = 1'b0;
    $display("Boot mode: %0d, Preload mode: %0d, Preload ELF: %s", boot_mode, preload_mode, preload_elf);
    
    // Wait for reset
    fix.vip.wait_for_reset();
    wait(fix.pll_test_done == 1);

    if (boot_mode == 0) begin
      case (preload_mode)
        0: begin      // JTAG
          fix.vip.jtag_init();
          fix.vip.jtag_elf_run(preload_elf);
          enable_vcd_dumping = 1'b1;
          fix.vip.jtag_wait_for_eoc(exit_code);
        end 1: begin  // UART
          fix.vip.uart_debug_elf_run_and_wait(preload_elf, exit_code);
        end 2: begin  // SPI
        //  fix.spi_vip.spi_init();
        //  fix.spi_vip.spi_write_u32(32'h0000001f, 32'h8000_0000);
        //  fix.spi_vip.spi_read(32'h00000004, 32'h8000_0000);
          repeat (1000) @(posedge fix.vip.clk);  // Wait for some time to let the SPI transaction complete
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

  //==============================================
  // Add vcd dumping and debug setup
  //==============================================
  if (ChipTest == 1) begin : gen_debug_setup
    `EN_SETUP_DEBUG(`DBG, `VCD_FILE, tb_lagd_chip.fix.gen_dut_lagd_chip.dut, enable_vcd_dumping)
  end

endmodule