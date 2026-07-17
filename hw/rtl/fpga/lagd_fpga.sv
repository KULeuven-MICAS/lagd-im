// Copyright 2025 KU Leuven.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Jiacong Sun <jiacong.sun@esat.kuleuven.be>
//
// FPGA top-level for LAGD.
//
// This wrapper replaces the chip-level `lagd_chip` (pads + analog PLL + analog
// macro) and instantiates only the synthesizable digital SoC `lagd_soc`. Its
// purpose is to bring up and verify the SPI-slave and UART interfaces against an
// external driver board. (RISC-V debug JTAG is present but deliberately held in
// reset on this board - see the lagd_soc instantiation below.)
//
// What is *not* deployed here (and why):
//   * IO pads          -> replaced by FPGA primitives (IBUFDS / IOBUF).
//   * Analog PLL       -> replaced by a Xilinx clk_wiz (MMCM/PLL). The RTC is
//                         NOT generated here: it arrives on rtc_i from the
//                         driver board, exactly as on the chip.
//   * `galena` macro   -> analog; its inout wires are terminated here. The
//                         `galena` instances *inside* the ising cores are built
//                         from hw/rtl/fpga/galena_fpga_stub.sv, selected by the
//                         bender `fpga` target (see Bender.yml).
//
// The signal set (which interfaces are real FPGA pins vs tied off) mirrors the
// chip top-level `lagd_chip` so the bring-up matches silicon behaviour.

`include "lagd_config.svh"

module lagd_fpga (
  // Board clock (differential system clock on a clock-capable pin pair)
  input  logic        sys_clk_p,
  input  logic        sys_clk_n,

  // Board reset, active high: the ZCU102's CPU_RESET push button (AM13, see
  // constraints/zcu102.xdc). Resets the SoC only - it does not disturb the FPGA
  // configuration, so it is also how you restart the bootrom to load a second
  // program (passive boot is one-shot; see the Cheshire bootrom's _exit).
  input  logic        sys_reset,

  // Real-time clock reference, driven by the external driver board (a slow
  // clock <= 32.768 kHz). Mirrors the chip's pad_rtc_i input. NOTE: the bootrom
  // measures the core frequency against this in clint_get_core_freq() before it
  // does anything else, so with rtc_i static the SoC never leaves that loop.
  input  logic        rtc_i,

  // Boot strap inputs. Driven by the external driver board over the FMC
  // (HPC0_LA09_P/N), mirroring the chip's boot_mode pads - these are NOT
  // on-board switches. They carry no pull, so they float if the cable is absent;
  // the driver ties them to 00 = passive boot (preload over SPI).
  input  logic [1:0]  boot_mode_i,

  // JTAG (RISC-V debug). Parked on on-board DIP switches and held in reset on
  // this board - see the lagd_soc instantiation below for why.
  input  logic        jtag_tck_i,
  input  logic        jtag_trst_ni,
  input  logic        jtag_tms_i,
  input  logic        jtag_tdi_i,
  output logic        jtag_tdo_o,

  // UART (Cheshire console). TX/RX only: they land on the ZCU102's on-board PL
  // USB-UART (F13/E13), which is the console used for bring-up.
  //
  // Unlike the chip, RTS/CTS are NOT exposed. The PL USB-UART (uart2_pl) brings
  // out only TX/RX, so on this board RTS/CTS had nowhere on-board to go and were
  // previously pinned to the FMC (HPC0_LA06_P/N) purely to satisfy the
  // "every port needs a LOC" rule. That spent two FMC pins and made the console
  // depend on the driver-board cable for no reason. They are now terminated
  // internally instead (see the lagd_soc instantiation below), which frees
  // LA06_P/N and drops the dependency. The console needs no flow control.
  output logic        uart_tx_o,
  input  logic        uart_rx_i,

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
  // The `galena` module itself is not synthesizable (the behavioural model uses
  // file I/O, real-valued delays and $urandom, and clocks off data buses), so
  // the bender `fpga` target swaps it for hw/rtl/fpga/galena_fpga_stub.sv. That
  // stub drives constant outputs (the ising compute is not modelled on FPGA);
  // it is enough for SPI/UART bring-up. See its header for why the spin path is
  // not modelled (it un-prunes the cores and the design fails to route).
  wire [`NUM_ISING_CORES-1:0] galena_j_vup;
  wire [`NUM_ISING_CORES-1:0] galena_j_vdn;
  wire [`NUM_ISING_CORES-1:0] galena_h_vup;
  wire [`NUM_ISING_CORES-1:0] galena_h_vdn;
  wire [`NUM_ISING_CORES-1:0] galena_vread;

  //////////////////
  //  JTAG clock   //
  //////////////////

  // jtag_tck_i is pinned to an on-board DIP switch, which sits in a High-Density
  // (HDIO) I/O bank. TCK is a clock and drives a BUFGCTRL clock-mux inside the
  // debug module; HDIO pins may only drive a BUFGCE directly, so a bare
  // HDIO -> BUFGCTRL path fails DRC (PLHDIO-3). Route TCK through a global buffer
  // first: HDIO -> BUFG (mapped to BUFGCE) -> BUFGCTRL is legal. The create_clock
  // on the jtag_tck_i port (see constraints/lagd.xdc) propagates through it.
  logic jtag_tck;
  BUFG i_jtag_tck_bufg (
    .I ( jtag_tck_i ),
    .O ( jtag_tck   )
  );

  //////////////////
  //  LAGD SoC     //
  //////////////////

  lagd_soc i_lagd_soc (
    .clk_i        ( soc_clk      ),
    .rtc_i        ( rtc_i        ),
    .rst_ni       ( rst_n        ),
    .test_mode_i  ( test_mode    ),
    .boot_mode_i  ( boot_mode_i  ),
    // JTAG - DISABLED on this board, deliberately and reversibly.
    //
    // The RISC-V debug JTAG is not routed here: the driver board does not carry
    // it and the FMC has no spare pins, so the jtag_* ports are parked on
    // on-board DIP switches (see constraints/zcu102.xdc). Bring-up preloads over
    // SPI (or the UART debug protocol) instead, so an idle TAP driven by hand
    // switches is only a source of noise.
    //
    // Holding trst_ni asserted keeps the TAP in Test-Logic-Reset, so dmactive
    // stays 0 and no debug access is possible regardless of what the DIP
    // switches do. tck/tms/tdi are deliberately left CONNECTED: tying tck to a
    // constant would let Vivado prune its IBUF/BUFG, and
    // constraints/zcu102_impl.xdc references that net by name
    // (jtag_tck_i_IBUF_inst/O) - set_property on an empty object list is an
    // error, so the build would fail. Leaving them wired also keeps every JTAG
    // constraint valid, so re-enabling is a one-line revert here.
    .jtag_tck_i   ( jtag_tck     ),
    .jtag_trst_ni ( 1'b0         ),
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
    // RTS/CTS are terminated here rather than pinned out (see the port list).
    // cts_ni is ACTIVE LOW, so 0 means "clear to send": the UART is permanently
    // allowed to transmit, which is what a console with no flow control wants.
    // Tying it high would wedge the transmitter. rts_no has no consumer.
    .uart_rts_no  (              ),
    .uart_cts_ni  ( 1'b0         ),
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
