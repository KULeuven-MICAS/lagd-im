// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Authors: 
//  Fanchen Kong <fanchen.kong@kuleuven.be>

`define SEEK_SET 0
`define SEEK_CUR 1
`define SEEK_END 2

task automatic spi_init();
  reg [7:0] cmd;  // SPI command code
  integer i;

  // Wait for a clock edge to align
  @(posedge spis_sck_i);
  #1;
  spis_csb_i = 0;

  // Switch SPI to Quad SPI mode
  cmd = 8'h1;
  // Send commend
  spis_drive_enable = 1;
  for (i = 7; i >= 0; i--) begin
    @(negedge spis_sck_i);
    #1;
    spis_sd_i[0] = cmd[i];  // Send 1 bit at a time on MOSI
  end
  // Enable Quad SPI mode by writing 0x01 to the status register
  for (i = 7; i >= 0; i--) begin
    @(negedge spis_sck_i);
    #1;
    spis_sd_i[0] = cmd[i];  // Send 1 bit at a time on MOSI
  end
  @(posedge spis_sck_i);
  #1;
  spis_csb_i = 1;  // Bring CSB high to end the transaction
  spis_drive_enable = 0;

endtask

task automatic spi_read(input integer length, input logic [31:0] addr);
  // Inputs:
  //   addr   - 32-bit Address to read from
  //   length - Number of bytes to read
  // Output:
  //   data   - Array to store read data

  reg [7:0] cmd;  // SPI read command code
  integer i, j, k;
  reg [3:0] mosi_data;  // Data to send over SPI (master out)
  reg [3:0] miso_data;  // Data received from SPI (slave out)

  // Wait for a clock edge to align
  @(posedge spis_sck_i);
  #1;
  spis_csb_i = 0;  // Bring CSB high to end the transaction

  // Set the SPI Read MEM code
  cmd = 8'hB;

  // Send the command code (8 bits) over 4 data lines (2 clock cycles)
  spis_drive_enable = 1;  // Enable driving spis_sd_io
  for (i = 7; i >= 0; i -= 4) begin
    @(negedge spis_sck_i);
    #1;
    if (i >= 3) begin
      mosi_data = cmd[i-:4];
    end else begin
      // For i = 3 to 0
      mosi_data = cmd[3:0];
      mosi_data = mosi_data << (3 - i);  // Left-align to 4 bits
    end
    spis_sd_i = mosi_data;  // Drive data lines
  end

  // Send the 32-bit address over 4 data lines (8 clock cycles)
  for (i = 31; i >= 0; i -= 4) begin
    @(negedge spis_sck_i);
    #1;
    if (i >= 3) begin
      mosi_data = addr[i-:4];
    end else begin
      // For i = 3 to 0
      mosi_data = addr[3:0];
      mosi_data = mosi_data << (3 - i);  // Left-align to 4 bits
    end
    spis_sd_i = mosi_data;  // Drive data lines
  end

  @(negedge spis_sck_i);  // Wait for last data to be sent
  #1;
  spis_drive_enable = 0;

  // Insert dummy cycles if required (e.g., 32 cycles)
  // This is the bug of ETH: @spi_slave_rx.sv, the counter count one more cycles
  for (i = 0; i <= 32; i = i + 1) begin
    @(posedge spis_sck_i);
    // Do nothing, just wait
  end


  // Now read the data from the slave
  // Becareful that the data is coming out from SPI in reversed order (Most Significant Byte first, most significant bit inside one byte first)
  for (i = 0; i < length; i = i + 4) begin
    reg [7:0] byte_data[4] = '{default: 8'h00};

    for (j = 3; j >= 0; j -= 1) begin
      for (k = 7; k >= 0; k -= 4) begin
        @(posedge spis_sck_i);
        #1;
        miso_data = spis_sd_o;  // Read 4 bits from slave
        if (k >= 3) begin
          byte_data[j][k-:4] = miso_data;
        end else begin
          // For j = 3 to 0
          byte_data[j][3:0] = miso_data >> (3 - j);
        end
      end
    end
    for (j = 0; j < 4; j = j + 1) begin
      $display("Read byte %0d: %h", (i + j), byte_data[j]);  // Print the byte to the console
    end
  end

  // Bring CSB high to end the transaction
  @(negedge spis_sck_i);
  #1;
  spis_csb_i = 1;
endtask

task automatic spi_read_u32(input logic [31:0] addr);
  spi_read(4, addr);
endtask

// Like spi_read_u32, but RETURNS the word instead of only printing it.
// Needed to poll SCRATCH_2 for end-of-computation (see spi_wait_for_eoc).
task automatic spi_read_u32_val(input logic [31:0] addr, output logic [31:0] data);
  reg [7:0] cmd;
  integer i, j, k;
  reg [3:0] miso_data;
  reg [7:0] byte_data [4];

  @(posedge spis_sck_i);
  #1;
  spis_csb_i = 0;

  cmd = 8'hB;
  spis_drive_enable = 1;
  for (i = 7; i >= 0; i -= 4) begin
    @(negedge spis_sck_i);
    #1;
    spis_sd_i = cmd[i-:4];
  end
  for (i = 31; i >= 0; i -= 4) begin
    @(negedge spis_sck_i);
    #1;
    spis_sd_i = addr[i-:4];
  end

  @(negedge spis_sck_i);
  #1;
  spis_drive_enable = 0;

  // Turnaround: 33 idle SCK before the slave drives data (see spi_read).
  for (i = 0; i <= 32; i = i + 1) begin
    @(posedge spis_sck_i);
  end

  // Data comes out most-significant byte first, most-significant nibble first.
  for (j = 3; j >= 0; j -= 1) begin
    for (k = 7; k >= 0; k -= 4) begin
      @(posedge spis_sck_i);
      #1;
      miso_data = spis_sd_o;
      byte_data[j][k-:4] = miso_data;
    end
  end

  @(negedge spis_sck_i);
  #1;
  spis_csb_i = 1;

  data = {byte_data[3], byte_data[2], byte_data[1], byte_data[0]};
endtask

task automatic spi_write_u32(input logic [31:0] data, input logic [31:0] addr);
  // Inputs:
  //   data - 8-bit data to write
  //   addr - 32-bit Address to write to

  reg [7:0] cmd;  // SPI write command code
  integer i, j;
  reg [3:0] mosi_data;  // Data to send over SPI (master out)

  // Wait for a clock edge to align
  @(posedge spis_sck_i);
  #1;
  spis_csb_i = 0;  // Bring CSB high to end the transaction

  // Set the SPI Write MEM code
  cmd = 8'h2;
  spis_drive_enable = 1;
  // Send the command code (8 bits) over 4 data lines (2 clock cycles)
  for (i = 7; i >= 0; i -= 4) begin
    @(negedge spis_sck_i);
    #1;
    if (i >= 3) begin
      mosi_data = cmd[i-:4];
    end else begin
      // For i = 3 to 0
      mosi_data = cmd[3:0];
      mosi_data = mosi_data << (3 - i);  // Left-align to 4 bits
    end
    spis_sd_i = mosi_data;  // Drive data lines
  end

  // Send the 32-bit address over 4 data lines (8 clock cycles)
  for (i = 31; i >= 0; i -= 4) begin
    @(negedge spis_sck_i);
    #1;
    if (i >= 3) begin
      mosi_data = addr[i-:4];
    end else begin
      // For i = 3 to 0
      mosi_data = addr[3:0];
      mosi_data = mosi_data << (3 - i);  // Left-align to 4 bits
    end
    spis_sd_i = mosi_data;  // Drive data lines
  end

  // Send the 32-bit data over 4 data lines (8 clock cycles)
  for (i = 31; i >= 0; i -= 4) begin
    @(negedge spis_sck_i);
    #1;
    mosi_data = data[i-:4];
    spis_sd_i = mosi_data;  // Drive data lines

  end
  $display("Wrote %h to address %h finished", data, addr);
  @(negedge spis_sck_i);
  #1;

  // Bring CSB high to end the transaction
  spis_csb_i = 1;
  spis_drive_enable = 0;
endtask

// Write `n_words` consecutive 32-bit words in ONE CS-low frame. The slave
// auto-increments the address by 4 per word, so a burst costs the 10-SCK
// command+address preamble once instead of once per word. This is the same
// framing the FPGA driver uses on hardware (lagd-meas chip_controller
// DATA_WRITE), so the preload path here exercises what the board does.
task automatic spi_write_words(
  input logic [31:0] addr,
  ref   logic [31:0] words [],
  input int unsigned first,      // index of the first word to send
  input int unsigned n_words
);
  reg [7:0] cmd;
  integer i;
  int unsigned w;

  @(posedge spis_sck_i);
  #1;
  spis_csb_i = 0;

  cmd = 8'h2;
  spis_drive_enable = 1;
  for (i = 7; i >= 0; i -= 4) begin
    @(negedge spis_sck_i);
    #1;
    spis_sd_i = cmd[i-:4];
  end
  for (i = 31; i >= 0; i -= 4) begin
    @(negedge spis_sck_i);
    #1;
    spis_sd_i = addr[i-:4];
  end
  for (w = 0; w < n_words; w++) begin
    for (i = 31; i >= 0; i -= 4) begin
      @(negedge spis_sck_i);
      #1;
      spis_sd_i = words[first + w][i-:4];
    end
  end

  @(negedge spis_sck_i);
  #1;
  spis_csb_i = 1;
  spis_drive_enable = 0;
endtask

task automatic spi_write_image(input string path, input logic [31:0] addr);
  // Inputs:
  //   path   - Path to the file to write
  //   addr   - 32-bit Address to read from

  reg [7:0] cmd;  // SPI write command code
  integer i, j, k;
  reg [3:0] mosi_data;  // Data to send over SPI (master out)
  reg [3:0] miso_data;  // Data received from SPI (slave out)
  integer file;
  integer file_size;

  // Start to load binaries from file
  // Wait for a clock edge to align
  @(posedge spis_sck_i);
  #1;
  spis_csb_i = 0;  // Bring CSB high to end the transaction

  // Set the SPI Write MEM code
  cmd = 8'h2;
  spis_drive_enable = 1;
  // Send the command code (8 bits) over 4 data lines (2 clock cycles)
  for (i = 7; i >= 0; i -= 4) begin
    @(negedge spis_sck_i);
    #1;
    if (i >= 3) begin
      mosi_data = cmd[i-:4];
    end else begin
      // For i = 3 to 0
      mosi_data = cmd[3:0];
      mosi_data = mosi_data << (3 - i);  // Left-align to 4 bits
    end
    spis_sd_i = mosi_data;  // Drive data lines
  end

  // Send the 32-bit address over 4 data lines (8 clock cycles)
  for (i = 31; i >= 0; i -= 4) begin
    @(negedge spis_sck_i);
    #1;
    if (i >= 3) begin
      mosi_data = addr[i-:4];
    end else begin
      // For i = 3 to 0
      mosi_data = addr[3:0];
      mosi_data = mosi_data << (3 - i);  // Left-align to 4 bits
    end
    spis_sd_i = mosi_data;  // Drive data lines
  end

  // Now write the data to the slave
  // Open the file for reading and get the size of the file
  file = $fopen(path, "r");
  if (file == 0) begin
    $display("Error: Could not open file %s", path);
    return;
  end
  $fseek(file, 0, `SEEK_END);
  file_size = $ftell(file);
  $fseek(file, 0, `SEEK_SET);

  // Read the file in chunks of 4 bytes
  for (i = 0; i < file_size; i = i + 4) begin
    reg [7:0] byte_data[4] = '{default: 8'h00};

    for (j = 0; j < 4; j = j + 1) begin
      byte_data[j] = $fgetc(file);
    end

    for (j = 3; j >= 0; j -= 1) begin
      for (k = 7; k >= 0; k -= 4) begin
        @(posedge spis_sck_i);
        #1;
        if (k >= 3) begin
          mosi_data = byte_data[j][k-:4];
        end else begin
          // For j = 3 to 0
          mosi_data = byte_data[j][3:0] << (3 - j);
        end
        spis_sd_i = mosi_data;  // Drive data lines
      end
    end
    for (j = 0; j < 4; j = j + 1) begin
      $display("Wrote byte %0d: %h", (i + j), byte_data[j]);  // Print the byte to the console
    end
  end
  $fclose(file);
  $display("Wrote to address %h finished", addr);
  @(negedge spis_sck_i);
  #1;

  // Bring CSB high to end the transaction
  spis_csb_i = 1;
  spis_drive_enable = 0;
endtask

// ---------------------------------------------------------------------------
// ELF preload over SPI (passive boot)
// ---------------------------------------------------------------------------
//
// Mirrors cheshire's slink_elf_run: the SPI slave is an AXI master into the
// crossbar, so it can write the program straight into memory while the bootrom
// spins in boot_passive() polling SCRATCH_2. This is exactly the flow the FPGA
// driver runs on hardware (lagd-meas sw/tools/spi_program_loader.py).
//
// Requires boot_mode == 0 (passive boot): the bootrom must be running and
// polling, otherwise the launch signal is never observed. Program output still
// arrives over UART - the VIP's UART monitor prints it, no extra call needed.

import "DPI-C" function byte read_elf(input string filename);
import "DPI-C" function byte get_entry(output longint entry);
import "DPI-C" function byte get_section(output longint address, output longint len);
import "DPI-C" context function byte read_section(input longint address, inout byte buffer[], input longint len);

// Words per CS-low write frame. Any value below 65536 is safe; the slave's
// wrap_length is never programmed and underflows to 0xFFFF, so a single frame
// of exactly 65536 words would wrap the address back to its base
// (see doc/axi_spi_slave_known_issues.md).
localparam int unsigned SpiBurstWords = 1024;

// Polls before giving up on end-of-computation. Each poll is one read frame
// (~51 SCK) plus the idle gap, so the default is far beyond any real test but
// still bounded - a hung program fails the run instead of hanging CI.
localparam int unsigned SpiEocMaxPolls = 100000;

task automatic spi_elf_preload(input string binary, output longint entry);
  longint sec_addr, sec_len;
  $display("[SPI] Preloading ELF binary: %s", binary);
  if (read_elf(binary))
    $fatal(1, "[SPI] Failed to load ELF!");
  while (get_section(sec_addr, sec_len)) begin
    byte bf [] = new [sec_len];
    logic [31:0] words [];
    int unsigned n_words;
    $display("[SPI] Preloading section at 0x%h (%0d bytes)", sec_addr, sec_len);
    if (read_section(sec_addr, bf, sec_len))
      $fatal(1, "[SPI] Failed to read ELF section!");
    if (sec_addr[1:0] != 2'b00)
      $fatal(1, "[SPI] Section address 0x%h is not word-aligned!", sec_addr);

    // Pack the little-endian byte stream into 32-bit words, zero-padding a
    // trailing partial word. The slave reassembles the word MSB-nibble-first,
    // so this matches what the host-side loader sends.
    n_words = int'((sec_len + 3) / 4);
    words   = new [n_words];
    for (int unsigned w = 0; w < n_words; w++) begin
      words[w] = '0;
      for (int unsigned e = 0; e < 4; e++)
        if (longint'(4*w + e) < sec_len)
          words[w][8*e +: 8] = bf[4*w + e];
    end

    for (int unsigned base = 0; base < n_words; base += SpiBurstWords) begin
      int unsigned chunk = n_words - base;
      if (chunk > SpiBurstWords) chunk = SpiBurstWords;
      if (base != 0)
        $display("[SPI] - %0d/%0d words (%0d%%)", base, n_words, base*100/n_words);
      spi_write_words(sec_addr[31:0] + 4*base, words, base, chunk);
    end
  end
  void'(get_entry(entry));
  $display("[SPI] Preload complete");
endtask

task automatic spi_elf_run(input string binary);
  longint entry;
  spi_elf_preload(binary, entry);
  // Entry point, then the launch signal the bootrom is waiting for.
  spi_write_u32(entry[63:32], cheshire_pkg::AmRegs + cheshire_reg_pkg::CHESHIRE_SCRATCH_1_OFFSET);
  spi_write_u32(entry[31:0],  cheshire_pkg::AmRegs + cheshire_reg_pkg::CHESHIRE_SCRATCH_0_OFFSET);
  spi_write_u32(32'd2,        cheshire_pkg::AmRegs + cheshire_reg_pkg::CHESHIRE_SCRATCH_2_OFFSET);
  $display("[SPI] Wrote launch signal and entry point 0x%h", entry);
endtask

// Poll SCRATCH_2 until the program sets bit 0; the exit code is the rest.
// The bootrom's _exit writes (retval << 1) | 1.
task automatic spi_wait_for_eoc(output logic [31:0] exit_code, input int unsigned idle_cycles = 100);
  logic [31:0] regval;
  int unsigned polls = 0;
  do begin
    repeat (idle_cycles) @(posedge spis_sck_i);
    spi_read_u32_val(cheshire_pkg::AmRegs + cheshire_reg_pkg::CHESHIRE_SCRATCH_2_OFFSET, regval);
    if (++polls >= SpiEocMaxPolls)
      $fatal(1, "[SPI] Timed out after %0d polls waiting for end-of-computation", polls);
  end while (~regval[0]);
  exit_code = regval >> 1;
  if (exit_code) $error("[SPI] FAILED: return code %0d", exit_code);
  else           $display("[SPI] SUCCESS");
endtask
