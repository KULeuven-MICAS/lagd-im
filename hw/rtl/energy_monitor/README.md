# Energy Monitor

## Description

This module calculates the Hamiltonian energy results for a given spin and weight/bias matrix.

The executed formula is as below:

$$
H = \sum_{i} \sum_{j} w_{ij} \sigma_i \sigma_j + \sum_i h_{sfc} \cdot h_i \sigma_i
$$

In the formula, each weight $w_{ij}$ and bias $h_i$ is a signed integer in 2's complement format. $\sigma_i$ is a 1-bit variable. The scaling factor $h_{sfc}$ is an unsigned integer in the power of 2.

The module overview is provided in the picture below.
<p align="center">
<img src="https://github.com/KULeuven-MICAS/lagd-im/tree/main/doc/energy_monitor_overview.png" width="100%" alt="energy monitor overview">
</p>

## Performance

For each transaction starting with spin handshake, this module takes DATASPIN/PARALLELISM+PIPESMID+1 cycles in average to output energy value.

## Module Parameters

*BITJ:* [int] bit precision of each signed weight (default: 4).

*BITH:* [int] bit precision of each signed bias (default: 4).

*DATASPIN:* [int] the number of spins, must be multiple of PARALLELISM  (default: 256).

*SCALING_BIT:* [int] bit precision of the $h_{sfc}$ (default: 5).

*PARALLELISM:* [int] parallelism of partial energy calculators (default: 4).

*LOCAL_ENERGY_BIT:* [int] bit precision of local energy, defined as $\sum_{j} w_{ij} \sigma_i \sigma_j + h_{sfc} \cdot h_i \sigma_i$ (default: 16).

*ENERGY_TOTAL_BIT:* [int] bit precision of total energy output (i.e. $H$) (default: 32).

*PIPESINTF:* [int] the pipeline depth at the module input interface (default: 0).

*PIPESMID:* [int] the pipeline depth at the input interface of the middle adder trees (default: 0).

## Module Interface

*clk_i:* clock input

*rst_ni:* active-low reset input

*en_i:* active-high module enable signal

*config_valid_i:* configuration valid input

*config_counter_i:* [$clog2(DATASPIN)-1 : 0] configuration counter value

*config_ready_o:* configuration ready

*spin_valid_i:* spin valid input

*spin_i:* [DATASPIN-1:0] spin input data

*spin_ready_o:* spin ready output

*weight_valid_i:* weight valid input

*weight_i:* [DATASPIN*BITJ-1:0] weight input data

*hbias_i:* [BITH-1:0] signed bias input

*hscaling_i:* [SCALING_BIT-1:0] unsigned scaling factor input

*weight_ready_o:* weight ready output

*energy_valid_o:* energy valid output

*energy_ready_i:* energy ready input

*energy_o:* [ENERGY_TOTAL_BIT-1:0] signed energy output

## Register: the following registers are configurable

| Register Name           | Bit Width   | Interface Signal       | Need Valid Signal | Address |
|:-----------------------:|:-----------:|:----------------------:|:--:|:--:|
| config counter          | 8           | config_counter_i       | Y | TBD |

## Further Possible Improvements

- Currently weight fetching happens after the spin handshake. It can also happen in parallel so can save one cycle per iteration.
- STATICA feature is not added yet (only compute the spin part that differs with previous case).
- Sparsity feature is not added yet.
