# Digital Macro

## Description

This module is the top module of the digital logic for a single Ising core.

Depending on whether the parameter *ENABLE_FLIP_DETECTION* is set to 0 or 1, there are two version of the architecture overview.

When *ENABLE_FLIP_DETECTION* is 0, the module overview is provided in the picture below.
<p align="center">
<img src="../../../doc/digital_macro_overview_v1.png" width="100%" alt="Digital Macro Overview (V1)">
</p>

When *ENABLE_FLIP_DETECTION* is 1, the module overview is provided in the picture below.
<p align="center">
<img src="../../../doc/digital_macro_overview_v2.png" width="100%" alt="Digital Macro Overview (V2)">
</p>


**Note**: the module assumes all peripheral memories exactly take 1 clock cycle to return data.

## Performance

The module supports generally two different modes (only the regular mode is supported when *ENABLE_FLIP_DETECTION* is 0):

- **Regular mode**: the digital logic does the energy calculation step by step. For a 256-spin problem with 4-parallel adders, it takes ~66 cycles (256/4+1 pipeline in adder + 1 for applying flipping).

- **Smarter mode**: this mode is for when there is not much change in the spin state. The exact delay depends on the targeted problems and data. If there is no change in spin states, it takes {4+PIPESFLIPFILTER} cycles per iteration. If there is changes in spin states, it takes {9+PIPESFLIPFILTER+#Address} cycles per iteration, where #Address means the number of requested addresses to J memory. Please note that this cycle cost can be overlapped due to the pipeline when SPIN_DEPTH > 1, and the average cycle cost per iteration can be smaller (here is the inclusive upper bound). Tested using the data under the folder [./data](../../unit_tests/digital_macro/data/), the average cycle delay per energy calculation is 17 cycles. Please note that if there is always big change in the spin state, switching to this mode can be ~4 cycles slower than the regular mode.

## Module Parameters

*BITJ*: [int] bit precision of each signed weight (default: 4).

*BITH*: [int] bit precision of each signed bias (default: 4).

*NUM_SPIN*: [int] the number of spins, must be multiple of PARALLELISM  (default: 256).

*SCALING_BIT*: [int] bit precision of the $h_{sfc}$ (default: 5).

*PARALLELISM*: [int] parallelism of partial energy calculators (default: 4).

*LOCAL_ENERGY_BIT*: [int] bit precision of local energy, defined as $\sum_{j} w_{ij} \sigma_i \sigma_j + h_{sfc} \cdot h_i \sigma_i$ (default: 16).

*ENERGY_TOTAL_BIT*: [int] bit precision of total energy output (i.e. $H$) (default: 32).

*LITTLE_ENDIAN*: [int] whether the spin vector and bias vector follows little-endian format or not. Whatever endianness J vector follows does not matter as long as it matches with the spin vector.

*PIPESINTF*: [int] the pipeline depth at the module input interface of the energy monitor (default: 1).

*PIPESMID*: [int] the pipeline depth in the adder trees within the energy monitor module (default: 1).

*PIPESFLIPFILTER*: [int] the pipeline depth at the module input interface of the flip filter (default: 1).

*SPIN_DEPTH*: [int] depth (entries) of internal spin/energy FIFOs (default: 2, min: 1).

*FLIP_ICON_DEPTH*: [int] number of entries in the flip icon memory (default: 1024).

*COUNTER_BITWIDTH*: [int] counter bit width (default: 16).

*SYNCHRONIZER_PIPEDEPTH*: [int] maximal synchronizer depth (default: 3).

*SPIN_WBL_OFFSET*: [int] since WBL is used by both data onloading operation and spin onloading operation. This parameter defines which bit in WBL is used for spin onloading for every *BITDATA* bits. (default: 0).

*H_IS_NEGATIVE*: [int] whether H=-0.5*J*spin-h*spin, or H = 0.5*J*spin+h*spin (default: 1).

*ENABLE_FLIP_DETECTION*: [int] whether to implement the version supporting flip detection. If false, the flip filter module will not be generated.

*CC_COUNTER_BITWIDTH*: [int] bit width for performance counters (default: 32).