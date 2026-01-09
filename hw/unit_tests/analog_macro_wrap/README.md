# Analog Macro Wrap Testbench

## Testbench parameters (applied value)

*NUM_SPIN* (256): number of spins.

*BITDATA* (4): bit precision of data (J and h).

*COUNTER_BITWIDTH* (16): counter bitwidth.

*SYNCHRONIZER_PIPE_DEPTH* (3): maximal synchronizer depth.

*PARALLELISM* (4): parallelism of Js in the memory.

*OnloadingTestNum* (100): number of tests for data onloading operations.

*CmptTestNum* (10000): number of tests for computation operations.

*CLKCYCLE* (2): clock cycle time (unit: ns)

## Testcases

### The following testcases have been verified (with default configration except PIPES = 0).

| Testcase Name | Description                                         | Input Parameters                                               |
|:-------------:|:---------------------------------------------------:|:--------------------------------------------------------------:|
Random | Random test | OnloadingTestNum=1_000_000, CmptTestNum=1_000_000 |

## Further Improvements TBD

