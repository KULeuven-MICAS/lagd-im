# Flip Manager

## Description

This module maintains the flipping operation for each trail.

Note: the module assumes the flip memory exactly takes 1 clock cycle.

## Performance

For each transaction starting with energy handshake, this module takes 3 cycles in average to output a new spin vector.

## Configurable Module Parameters

*DATASPIN:* [int] the number of spins  (default: 256)

*SPIN_DEPTH:* [int] depth (entries) of internal spin/energy FIFOs

*ENERGY_TOTAL_BIT:* [int] bit precision of total energy output (i.e. $H$) (default: 32)

*FLIP_ICON_DEPTH:* [int] number of entries in the flip icon memory
