# LAGD Software Tests

This folder contains all tests for the LAGD chip in C program.

Note: please activate pixi environment first. Otherwise, it raises errors on incorrect gcc version. To activate pixi, run:

```bash
pixi shell
```

## HelloWorld test

File [helloworld.spm.c](./helloworld.spm.c) contains the most basic hello world test. Correctly finishing this program means the L2 memory is functional.

Command:

```[bash]
CORE_TESTED=0 ./ci/sys-run.sh --binary=sw/tests/helloworld.spm.elf
```

To explicitly choose the simulator, add the argument `--tool=[vsim | vcs]`. The default simulator is vsim.

## Register access test

File [lagd_reg.spm.c](./lagd_reg.spm.c) tests if all LAGD CSR can be accessed. It sweeps across entire CSR address region with continuous write and read operations.

Command:

```[bash]
CORE_TESTED=0 ./ci/sys-run.sh --binary=sw/tests/lagd_reg.spm.elf
```

## Normal computation test (single core)

File [lagd_scompute.spm.c](./lagd_scompute.spm.c) tests the Ising computation on selected single core. It loads necessary data under the folder [./data/default/](./data/default/) to start the computation, and outputs the final energy results.

Command:

```[bash]
CORE_TESTED=0 ./ci/sys-run.sh --binary=sw/tests/lagd_scompute.spm.elf
```

To test the extreme case (with maximal toggle rate) for power analysis, run:

```[bash]
CORE_TESTED=0 DATA_FOLDER=extreme ./ci/sys-run.sh --binary=sw/tests/lagd_scompute.spm.elf
```

## Normal computation test (dual core)

File [lagd_mcompute.spm.c](./lagd_mcompute.spm.c) tests the Ising computation on two cores. Similarly, it loads necessary data under the folder [./data/default/](./data/default/) to start the computation, and outputs the final energy results.

Command:

```[bash]
./ci/sys-run.sh --binary=sw/tests/lagd_dcompute.spm.elf
```

To test the extreme case (with maximal toggle rate) for power analysis, run:

```[bash]
DATA_FOLDER=extreme ./ci/sys-run.sh --binary=sw/tests/lagd_dcompute.spm.elf
```

Additionally, to start and stop at the compute phase, add:

```[bash]
--defines="VCD_START=fix.gen_dut_soc.dut.gen_cores[1].i_core.cmpt_en==1 VCD_STOP=fix.gen_dut_soc.dut.gen_cores[1].i_core.dgt_weight_raddr==10 END_SIM_AT_VCD_STOP=1"
```

Post-syn (26-03-02 netlist):

```[bash]
--defines="VCD_START=fix.gen_dut_chip.dut.i_lagd_soc.gen_cores_1__i_core.u_digital_macro.cmpt_en_i==1 VCD_STOP=fix.gen_dut_chip.dut.i_lagd_soc.gen_cores_1__i_core.u_digital_macro.dgt_weight_raddr_o==10 END_SIM_AT_VCD_STOP=1"
```

## Galena Data W/R test (for debugging)

File [lagd_debug_dt.spm.c](./lagd_debug_dt.spm.c) tests the data writing and data read operation of a single Galena macro.

Command:

```[bash]
CORE_TESTED=0 ./ci/sys-run.sh --binary=sw/tests/lagd_debug_dt.spm.elf
```

## Galena spin W/R test (for debugging)

File [lagd_debug_spin.spm.c](./lagd_debug_spin.spm.c) tests the spin writing and continuous spin reading of a single Galena macro.

Command:

```[bash]
CORE_TESTED=0 ./ci/sys-run.sh --binary=sw/tests/lagd_debug_spin.spm.elf
```
