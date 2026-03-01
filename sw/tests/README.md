# LAGD Software Tests

This folder contains all tests for the LAGD chip in C program.

## HelloWorld test

File [helloworld.spm.c](./helloworld.spm.c) contains the most basic hello world test. Correctly finishing this program means the L2 memory is functional.

Command:

```
CORE_TESTED=0 ./ci/sys-run.sh --binary=sw/tests/helloworld.spm.elf
```

## Register access test

File [lagd_reg.spm.c](./lagd_reg.spm.c) tests if all LAGD CSR can be accessed. It sweeps across entire CSR address region with continuous write and read operations.

Command:

```
CORE_TESTED=0 ./ci/sys-run.sh --binary=sw/tests/lagd_reg.spm.elf
```

## Normal computation test

File [lagd_scompute.spm.c](./lagd_scompute.spm.c) tests the Ising computation on selected single core. It loads necessary data under the folder [./data/default/](./data/default/) to start the computation, and outputs the final energy results.

Command:

```
CORE_TESTED=0 ./ci/sys-run.sh --binary=sw/tests/lagd_scompute.spm.elf
```

To test the extreme case (with maximal toggle rate) for power analysis, run:

```
CORE_TESTED=0 DATA_FOLDER=extreme ./ci/sys-run.sh --binary=sw/tests/lagd_scompute.spm.elf
```

## Galena Data W/R test (for debugging)

File [lagd_debug_dt.spm.c](./lagd_debug_dt.spm.c) tests the data writing and data read operation of a single Galena macro.

Command:

```
CORE_TESTED=0 ./ci/sys-run.sh --binary=sw/tests/lagd_debug_dt.spm.elf
```

## Galena spin W/R test (for debugging)

File [lagd_debug_spin.spm.c](./lagd_debug_spin.spm.c) tests the spin writing and continusous spin reading of a single Galena macro.

Command:

```
CORE_TESTED=0 ./ci/sys-run.sh --binary=sw/tests/lagd_debug_spin.spm.elf
```
