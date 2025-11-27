# Energy Monitor Testbench

## Description

This testbench is for testing the function and performance of energy monitor module. The module calculates the Hamiltonian energy results for a given spin and weight/bias matrix.

The executed formula is as below:

$$
H = \sum_{i} \sum_{j} w_{ij} \sigma_i \sigma_j + \sum_i h_{sfc} \cdot h_i \sigma_i
$$

In the formula, each weight $w_{ij}$ and bias $h_i$ is a signed integer in 2's complement format. $\sigma_i$ is a 1-bit variable. The scaling factor $h_{sfc}$ is an unsigned integer in the power of 2.

## Testbench parameters

*test_mode:* test mode, like S1W1H1_TEST, S0W1H1_TEST, S0W0H0_TEST, S1W0H0_TEST, MaxPosValue_TEST, MaxNegValue_TEST, RANDOM_TEST

*NUM_TEST:* tested number of cases.

*CLKCYCLE:* clock cycle time (unit: ns).

*MEM_LATENCY:* expected weight memory latency (unit: cycle) per read access.

*SPIN_LATENCY:* expected spin latency interval (unit: cycle) for each two *spin_valid_i*.

*MEM_LATENCY_RANDOM:* if memory latency is random. If true, it is a random value sampled from [0, *MEM_LATENCY*]. If false, it is fixed at *MEM_LATENCY*.

*SPIN_LATENCY_RANDOM:* if spin latency is random. If true, it is a random value sampled from [0, *SPIN_LATENCY*]. If false, it is fixed at *SPIN_LATENCY*.

*LITTLE_ENDIAN:* if the data format is little-endian (True: 1, False: 0).

*PIPESINTF:* the pipeline depth at the module input interface.

*PIPESMID:* the pipeline depth at the input interface of the middle adder trees.

## Testcases

### The following testcases have been verified (with PIPES = 0/1/2).

| Testcase Name | Description                                         | Parameters                                                     |
|:-------------:|:---------------------------------------------------:|:--------------------------------------------------------------:|
| S1W1H1_TEST        | 100 successive tests, all spin, weight, bias are 1| $\sigma = [1]$, $w = [1]$, $h = [1]$, $h_{sfc} = 1$, NUM_TEST=100, LITTLE_ENDIAN=0/1, PARALLELISM=4, PIPESINTF=0/1/2, PIPESMID=0/1/2 |
| S0W1H1_TEST        | 100 successive tests, all spin are 0, weight/bias are 1 | $\sigma = [0]$, $w = [1]$, $h = [1]$, $h_{sfc} = 1$, NUM_TEST=100, LITTLE_ENDIAN=0/1, PARALLELISM=4, PIPESINTF=0/1/2, PIPESMID=0/1/2 |
| S0W0H0_TEST        | 100 successive tests, all spin are 0, weight/bias are -1 | $\sigma = [0]$, $w = [-1]$, $h = [-1]$, $h_{sfc} = 1$, NUM_TEST=100, LITTLE_ENDIAN=0/1, PARALLELISM=4, PIPESINTF=0/1/2, PIPESMID=0/1/2 |
| S1W0H0_TEST        | 100 successive tests, all spin are 1, weight, bias are -1 | $\sigma = [1]$, $w = [-1]$, $h = [-1]$, $h_{sfc} = 1$, NUM_TEST=100, LITTLE_ENDIAN=0/1, PARALLELISM=4, PIPESINTF=0/1/2, PIPESMID=0/1/2 |
| MaxPosValue_TEST        | 100 successive tests, all spin are 1, weight, bias are in positive maximum | $\sigma = [1]$, $w = [7]$, $h = [7]$, $h_{sfc} = 16$, NUM_TEST=100, LITTLE_ENDIAN=0/1, PARALLELISM=4, PIPESINTF=0/1/2, PIPESMID=0/1/2 |
| MaxNegValue_TEST        | 100 successive tests, all spin are 0, weight, bias are in negative maximum | $\sigma = [0]$, $w = [-7]$, $h = [-7]$, $h_{sfc} = 16$, NUM_TEST=100, LITTLE_ENDIAN=0/1, PARALLELISM=4, PIPESINTF=0/1/2, PIPESMID=0/1/2 |
| RANDOM_TEST        | 1,000,000 successive tests, all spin, weight, bias are in random | $\sigma = [0,1]$, $w = [-8,7]$, $h = [-8,7]$, $h_{sfc} = 1/2/4/8/16$, NUM_TEST=1_000_000, LITTLE_ENDIAN=0/1, PARALLELISM=4, PIPESINTF=0/1/2, PIPESMID=0/1/2 |

## Register: the following registers are configurable

| Register Name           | Bit Width   | Interface Signal       | Need Valid Signal | Address |
|:-----------------------:|:-----------:|:----------------------:|:--:|:--:|
| config counter          | 8           | config_counter_i       | Y | TBD |


## Further Possible Improvements

- Currently weight fetching happens after the spin handshake. It can also happen in parallel so can save one cycle per iteration.
- STATICA feature is not added yet (only compute the spin part that differs with previous case).
- Sparsity feature is not added yet.
