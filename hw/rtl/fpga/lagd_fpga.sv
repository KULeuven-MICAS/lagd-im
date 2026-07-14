// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Jiacong Sun <jiacong.sun@esat.kuleuven.be>
//
// FPGA top-level for LAGD (target: VCU128).
//
// This wrapper replaces the chip-level `lagd_chip` (pads + analog PLL + analog
// macro) and instantiates only the synthesizable digital SoC `lagd_soc`. Its
// purpose is to bring up and verify the SPI-slave, JTAG and UART interfaces
// against an external driver board.
//
// What is *not* deployed here (and why):
//   * IO pads          -> replaced by FPGA primitives (IBUFDS / IOBUF).
//   * Analog PLL        -> replaced by a Xilinx clk_wiz (MMCM/PLL) + RTC divider.
//   * `galena` macro    -> analog; its inout wires are terminated here. The
//                          `galena` instances *inside* the ising cores still
//                          need an FPGA black-box/stub at build time (the
//                          behavioural model is not synthesizable). See TODO.
//
// The signal set (which interfaces are real FPGA pins vs tied off) mirrors the
// chip top-level `lagd_chip` so the bring-up matches silicon behaviour.

`include "lagd_config.svh"

module lagd_fpga (
  // Board clock (VCU128: differential system clock on a clock-capable pin pair)
  input  logic        sys_clk_p,
  input  logic        sys_clk_n,

  // Board reset. On VCU128 the CPU reset button (pin BM29) is active-high.
  input  logic        sys_reset,

  // Real-time clock reference, driven by the external driver board (a slow
  // clock <= 32.768 kHz). Mirrors the chip's pad_rtc_i input.
  input  logic        rtc_i,

  // Boot strap inputs (DIP switches). Default to passive boot (boot_mode = 0)
  // so the SoC is preloaded over JTAG or SPI. Mirrors the chip boot_mode pads.
  input  logic [1:0]  boot_mode_i,

  // JTAG (debug access into Cheshire)
  input  logic        jtag_tck_i,
  input  logic        jtag_trst_ni,
  input  logic        jtag_tms_i,
  input  logic        jtag_tdi_i,
  output logic        jtag_tdo_o,

  // UART (Cheshire console). RTS/CTS exposed like the chip; the remaining
  // modem-status lines are tied off internally (see below), as on the chip.
  output logic        uart_tx_o,
  input  logic        uart_rx_i,
  output logic        uart_rts_no,
  input  logic        uart_cts_ni,

  // SPI slave (device under test) - driven by the external master board.
  // 4 bidirectional data lines (quad-capable), clock and chip-select in.
  input  logic        spi_sck_i,
  input  logic        spi_cs_i,
  inout  wire  [3:0]  spi_sd_io
);

  // test_mode is unused on the chip (left at 0 by lagd_chip); do the same here.
  logic test_mode;
  assign test_mode = 1'b0;

  ////////////////////////
  //  Clock generation  //
  ////////////////////////

  // soc_clk is produced by the clocking wizard at the rate set in the clk_wiz IP
  // (CLKOUT1_REQUESTED_OUT_FREQ in impl_ip.tcl), currently 50 MHz (cheshire's
  // reference rate, chosen for reliable CVA6 timing closure). The RTC reference
  // comes from an external pin (rtc_i), independent of soc_clk's rate.

  logic sys_clk;
  logic soc_clk;
  logic clk_locked;

  IBUFDS #(
    .IBUF_LOW_PWR ("FALSE")
  ) i_bufds_sys_clk (
    .I  ( sys_clk_p ),
    .IB ( sys_clk_n ),
    .O  ( sys_clk   )
  );

  // Xilinx clocking wizard: board clock -> SoC clock.
  // The IP (single output `clk_out1`) is created in the build flow. Its reset
  // is tied low so a button press does not drop the MMCM lock; the button only
  // resets the SoC via rstgen below.
  clkwiz i_clkwiz (
    .clk_in1  ( sys_clk    ),
    .reset    ( 1'b0       ),
    .locked   ( clk_locked ),
    .clk_out1 ( soc_clk    )
  );

  //////////////////
  //  Reset sync  //
  //////////////////

  logic rst_n;

  // Synchronize the (de)assertion of reset to the SoC clock. Hold the SoC in
  // reset until the clock is locked. `rstgen` comes from common_cells.
  rstgen i_rstgen (
    .clk_i        ( soc_clk                  ),
    .rst_ni       ( ~sys_reset & clk_locked  ),
    .test_mode_i  ( test_mode                ),
    .rst_no       ( rst_n                    ),
    .init_no      (                          )
  );

  ////////////////////////
  //  SPI slave  IOBUFs //
  ////////////////////////

  // The chip splits each bidirectional SPI data pad into (sdi, sdo, oen).
  // `spi_oen_o` is active-low output-enable: 0 => drive, 1 => high-Z (input),
  // which maps directly onto the IOBUF tristate control `.T`.
  logic [3:0] spi_sdi;   // pad -> SoC
  logic [3:0] spi_sdo;   // SoC -> pad
  logic [3:0] spi_oen;   // SoC output-enable (active low)

  for (genvar i = 0; i < 4; i++) begin : gen_spi_iobuf
    IOBUF #(
      .DRIVE        ( 12        ),
      .IBUF_LOW_PWR ( "FALSE"   ),
      .IOSTANDARD   ( "DEFAULT" ),
      .SLEW         ( "FAST"    )
    ) i_spi_sd_iobuf (
      .O  ( spi_sdi    [i] ),  // received from pad
      .IO ( spi_sd_io  [i] ),  // physical pad
      .I  ( spi_sdo    [i] ),  // value to drive out
      .T  ( spi_oen    [i] )   // 1 => high-Z (input)
    );
  end

  ////////////////////////////
  //  Galena analog wires    //
  ////////////////////////////

  // The `galena` analog macros live inside each `ising_core_wrap`. On the chip
  // these inout buses route to analog pads; on FPGA there is nothing to drive
  // them, so they are left floating here.
  //
  // TODO(build): the `galena` module itself is not synthesizable (behavioural
  // model uses file I/O). Provide an FPGA black-box/stub for `galena` via a
  // dedicated Bender target before synthesis.
  wire [`NUM_ISING_CORES-1:0] galena_j_vup;
  wire [`NUM_ISING_CORES-1:0] galena_j_vdn;
  wire [`NUM_ISING_CORES-1:0] galena_h_vup;
  wire [`NUM_ISING_CORES-1:0] galena_h_vdn;
  wire [`NUM_ISING_CORES-1:0] galena_vread;

  //////////////////
  //  LAGD SoC     //
  //////////////////

  lagd_soc i_lagd_soc (
    .clk_i        ( soc_clk      ),
    .rtc_i        ( rtc_i        ),
    .rst_ni       ( rst_n        ),
    .test_mode_i  ( test_mode    ),
    .boot_mode_i  ( boot_mode_i  ),
    // JTAG
    .jtag_tck_i   ( jtag_tck_i   ),
    .jtag_trst_ni ( jtag_trst_ni ),
    .jtag_tms_i   ( jtag_tms_i   ),
    .jtag_tdi_i   ( jtag_tdi_i   ),
    .jtag_tdo_o   ( jtag_tdo_o   ),
    // On the chip, tdo_oe is exported on a separate info pad and does NOT
    // tristate TDO (the TDO pad is a plain always-driven output). For a single
    // FPGA JTAG device, drive tdo directly and leave the OE unconnected.
    .jtag_tdo_oe_o(              ),
    // UART
    .uart_tx_o    ( uart_tx_o    ),
    .uart_rx_i    ( uart_rx_i    ),
    .uart_rts_no  ( uart_rts_no  ),
    .uart_cts_ni  ( uart_cts_ni  ),
    // Remaining modem-status lines: tied off exactly as in lagd_chip.
    .uart_dtr_no  (              ),
    .uart_dsr_ni  ( 1'b1         ),
    .uart_dcd_ni  ( 1'b1         ),
    .uart_rin_ni  ( 1'b1         ),
    // SPI slave
    .spi_sck_i    ( spi_sck_i    ),
    .spi_cs_i     ( spi_cs_i     ),
    .spi_oen_o    ( spi_oen      ),
    .spi_sdi_i    ( spi_sdi      ),
    .spi_sdo_o    ( spi_sdo      ),
    // Galena analog wires (terminated above)
    .galena_j_vup_i ( galena_j_vup ),
    .galena_j_vdn_i ( galena_j_vdn ),
    .galena_h_vup_i ( galena_h_vup ),
    .galena_h_vdn_i ( galena_h_vdn ),
    .galena_vread_i ( galena_vread )
  );

endmodule : lagd_fpga
