# Flip Manager Testbench

## Description

This module maintains the flipping operation for each trail.

## Testbench parameters

*CLKCYCLE:* clock cycle time (unit: ns)

*MEM_LATENCY:* expected weight memory latency (unit: cycle) per read access

*SPIN_LATENCY:* expected spin latency interval (unit: cycle) for each two *spin_valid_i*

*RANDOM_TEST:* if use random generated data as inputs

*NUM_TEST:* tested number of cases

## Testcases

### The following testcases have been verified (with default configration except PIPES = 0).

| Testcase Name | Description                                         | Input Parameters                                               |
|:-------------:|:---------------------------------------------------:|:--------------------------------------------------------------:|


## Register address

| Register Name           | Bit Width   | Interface Signal       | Need Valid Signal | Address |
|:-----------------------:|:-----------:|:----------------------:|:--:|:--:|


## Further Improvement TBD

- The energy fifo can not be read out from the configure channel yet.
- flush_i should be added to energy monitor as well.
- interface should be exposed to the host so that host can take over the flipping process.