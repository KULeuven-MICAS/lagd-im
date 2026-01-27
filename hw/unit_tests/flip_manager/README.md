# Flip Manager Testbench

## Testbench parameters (applied value)

*NUM_SPIN* (256): number of spins.

*ENERGY_TOTAL_BIT* (32): bit precision of energy value.

*SPIN_DEPTH* (2): spin FIFO depth.

*FLIP_ICON_DEPTH* (1024): flip icon memory depth.

*CLKCYCLE* (2): clock cycle time (unit: ns)

*ENABLE_ENERGY_COMPARISON* (1): whether or not to enable energy comparison.

*FLIP_MEM_LATENCY* (1): memory latency of external flip icon memory (must be 1).

*ENERGY_MONITOR_LATENCY*: expected energy monitor latency.

*ANALOG_DELAY*: expected analog macro latency.

*RANDOM_TEST*: whether the data is random or not.

*FLUSH_NUM_TESTS*: number of flush tests.

## Testcases

### The following testcases have been verified (with default configration except PIPES = 0).

| Testcase Name | Description                                         | Input Parameters                                               |
|:-------------:|:---------------------------------------------------:|:--------------------------------------------------------------:|
Fixed | Fix patten test | RANDOM_TEST=0, FLUSH_NUM_TESTS=3 |
Random | Random test | RANDOM_TEST=1, FLUSH_NUM_TESTS=3 |

## Further Improvements TBD

- The energy fifo can not be read out from the configure channel yet.
- interface should be exposed to the host so that host can take over the flipping process.