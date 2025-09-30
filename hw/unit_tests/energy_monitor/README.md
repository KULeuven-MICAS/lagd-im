# Energy Monitor Testbench

## Description

This module calculates the Hamiltonian energy results for a given spin and weight/bias matrix.

The executed formula is as below:

$$
H = \sum_{i} \sum_{j} w_{ij} \sigma_i \sigma_j + \sum_i h_{sfc} \cdot h_i \sigma_i
$$

In the formula, each weight $w_{ij}$ and bias $h_i$ is a signed integer in 2's complement format. $\sigma_i$ is a 1-bit variable. The scaling factor $h_{sfc}$ is an unsigned integer in the power of 2.

## Configurable Module Parameters

*BITJ:* [int] bit precision of each signed weight (default: 4)

*BITH:* [int] bit precision of each signed bias (default: 4)

*DATASPIN:* [int] the number of spins  (default: 256)

*SCALING_BIT:* [int] bit precision of the $h_{sfc}$ (default: 5)

*LOCAL_ENERGY_BIT:* [int] bit precision of local energy, defined as $\sum_{j} w_{ij} \sigma_i \sigma_j + h_{sfc} \cdot h_i \sigma_i$ (default: 16)

*ENERGY_TOTAL_BIT:* [int] bit precision of total energy output (i.e. $H$) (default: 32)

*PIPES:* [int] the pipeline depth at the interface (default: 1)

## Testbench parameters

*CLKCYCLE:* clock cycle time (unit: ns)

*MEM_LATENCY:* expected weight memory latency (unit: cycle) per read access

*SPIN_LATENCY:* expected spin latency interval (unit: cycle) for each two *spin_valid_i*

*RANDOM_TEST:* if use random generated data as inputs

*NUM_TEST:* tested number of cases

## Module Interface

*clk_i:* clock input

*rst_ni:* active-low reset input

*en_i:* active-high module enable signal

*config_valid_i:* configuration valid input

*config_counter_i:* [$clog2(DATASPIN)-1 : 0] configuration counter input

*config_ready_o:* configuration ready output

*spin_valid_i:* spin valid input

*spin_i:* [DATASPIN-1:0] spin input data

*spin_ready_o:* spin ready output

*weight_valid_i:* weight valid input

*weight_i:* [DATASPIN*BITJ-1:0] weight input data

*hbias_i:* signed [BITH-1:0] bias input

*hscaling_i:* unsigned [SCALING_BIT-1:0] scaling factor input

*weight_ready_o:* weight ready output

*energy_valid_o:* energy valid output

*energy_ready_i:* energy ready input

*energy_o:* signed [ENERGY_TOTAL_BIT-1:0] energy output

*debug_en_i:* debug enable input

*accum_overflow_o:* accumulator overflow output

## Testcases

The following testcases have been verified (with default configration except PIPES = 0).

| Testcase Name | Description                                         | Input Parameters                                               |
|:-------------:|:---------------------------------------------------:|:--------------------------------------------------------------:|
| S1W1H1        | 3 successive tests, all spin, weight, bias are 1| $\sigma = [1]$, $w = [1]$, $h = [1]$, $h_{sfc} = 1$, NUM_TEST=3 |
| S0W1H1        | 3 successive tests, all spin are 0, weight/bias are 1 | $\sigma = [0]$, $w = [1]$, $h = [1]$, $h_{sfc} = 1$, NUM_TEST=3 |
| S0W0H0        | 3 successive tests, all spin are 0, weight/bias are -1 | $\sigma = [0]$, $w = [-1]$, $h = [-1]$, $h_{sfc} = 1$, NUM_TEST=3 |
| S1W0H0        | 3 successive tests, all spin, weight, bias are -1 | $\sigma = [0]$, $w = [-1]$, $h = [-1]$, $h_{sfc} = 1$, NUM_TEST=3 |
| MaxPosValue        | 3 successive tests, all spin, weight, bias are in positive maximum | $\sigma = [1]$, $w = [7]$, $h = [7]$, $h_{sfc} = 16$, NUM_TEST=3 |
| MaxNegValue        | 3 successive tests, all spin, weight, bias are in negative maximum | $\sigma = [0]$, $w = [-7]$, $h = [-7]$, $h_{sfc} = 16$, NUM_TEST=3 |
| Random        | 100 successive tests, all spin, weight, bias are in random | $\sigma = [0,1]$, $w = [-8,7]$, $h = [-8,7]$, $h_{sfc} = 1/2/4/8/16$, RANDOM_TEST=1, NUM_TEST=100 |

Test with pipes are tbd.

Test with debugging can be done later on.

## Register address

config counter register
