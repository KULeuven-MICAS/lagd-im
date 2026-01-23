// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Giuseppe Sarda <giuseppe.sarda@esat.kuleuven.be>

`ifndef BOOT_MODE
`define BOOT_MODE 0
`endif



module tb_cheshire_chip ();

  fixture_lagd_chip fix ();
  
  string      preload_elf;
  string      boot_hex;
  logic [1:0] boot_mode;
  logic [1:0] preload_mode;
  bit [31:0]  exit_code;

  initial begin 

  end
endmodule