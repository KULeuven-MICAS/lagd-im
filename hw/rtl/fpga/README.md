# FPGA Top

## Description

This folder contains the top module of the FPGA imeplementation of the chip. Compared to the tapeout, the following changes are made intentionally:

- The PLL and analog module (galena) are excluded. A behavior module is imeplemented for the analog module, which connects the spin inputs to the outputs. A 50MHz SoC clock is set internally, which is directly drived by the clock on the FPGA.

- The JTAG interface is disabled by default.

- The CTS/RTS signals of the UART interface are dropped.

- The PADs are excluded.

- Two LED outputs are added to signal whether the clock is locked and whether the logic has been deployed on the FPGA (heartbeat).
