# Analog Macro Wrap Testbench

# Description

This testbench is for testing the function (normal and under debugging) and performance of the analog macro wrap module. Enter the command below to run the testbench:

`
./ci/ut-run.sh --test=analog_macro_wrap
`

## Testbench parameters (applied value)

*NUM_SPIN* (256): number of spins.

*BITDATA* (4): bit precision of data (J and h).

*COUNTER_BITWIDTH* (16): counter bitwidth.

*SYNCHRONIZER_PIPE_DEPTH* (3): maximal synchronizer depth.

*PARALLELISM* (4): parallelism of Js in the memory.

*OnloadingTestNum* (100): number of tests for data onloading operations.

*CmptTestNum* (10000): number of tests for computation operations.

*DebugTestNum* (100): number of debugging tests, with each test includes (in ordering) single J/h writing, single J/h reading, single spin writing, single spin computing, sequential spin reading.

*CLKCYCLE* (2): clock cycle time (unit: ns)

## Testcases

### The following testcases have been verified (with default configration except PIPES = 0).

| Testcase Name | Description                                         | Input Parameters                                               |
|:-------------:|:---------------------------------------------------:|:--------------------------------------------------------------:|
Random | Random test | OnloadingTestNum=10_000, CmptTestNum=10_000, DebugTestNum=100 |

## Further Improvements TBD

