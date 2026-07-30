# LAGD Software Tests

This folder contains all tests for the LAGD chip in C program.

The data of each ising core lives in [./data/](./data/) under the folder selected with
`--data-folder=` (default: [./data/default/](./data/default/)). Core 0 uses `model_1`,
`clusters_1`/`clusters_2`, `states_in_1`/`states_in_2` and `states_out_1`/`states_out_2`; core 1
uses `model_2`, `clusters_3`/`clusters_4`, `states_in_3`/`states_in_4` and
`states_out_3`/`states_out_4`. The single-core tests select the core they drive with
`--core-tested=` (default: 0) and load the data of that core only; the multi-core tests always
drive every core with its own data and ignore the flag.

## HelloWorld test

File [helloworld.spm.c](./helloworld.spm.c) contains the most basic hello world test. Correctly finishing this program means the L2 memory is functional.

Command:

```[bash]
./ci/sys-run.sh --binary=sw/tests/helloworld.spm.elf
```

## Register access test

File [lagd_reg.spm.c](./lagd_reg.spm.c) tests if all LAGD CSR can be accessed. It sweeps across entire CSR address region with continuous write and read operations.

Command:

```[bash]
./ci/sys-run.sh --binary=sw/tests/lagd_reg.spm.elf
```

## Normal computation test (single core)

File [lagd_scompute.spm.c](./lagd_scompute.spm.c) tests the Ising computation on selected single core. It loads necessary data under the folder [./data/default/](./data/default/) to start the computation, and outputs the final energy results.

Command:

```[bash]
./ci/sys-run.sh --binary=sw/tests/lagd_scompute.spm.elf --core-tested=0
```

To drive core 1 instead, with the model of core 1:

```[bash]
./ci/sys-run.sh --binary=sw/tests/lagd_scompute.spm.elf --core-tested=1
```

To test the extreme case (with maximal toggle rate) for power analysis, run:

```[bash]
./ci/sys-run.sh --binary=sw/tests/lagd_scompute.spm.elf --data-folder=extreme --core-tested=0
```

## Normal computation test (dual core)

File [lagd_dcompute.spm.c](./lagd_dcompute.spm.c) tests the Ising computation on two cores. Similarly, it loads necessary data under the folder [./data/default/](./data/default/) to start the computation, and outputs the final energy results. Each core runs its own model, so `--core-tested=` does not apply here.

Command:

```[bash]
./ci/sys-run.sh --binary=sw/tests/lagd_dcompute.spm.elf
```

To test the extreme case (with maximal toggle rate) for power analysis, run:

```[bash]
./ci/sys-run.sh --binary=sw/tests/lagd_dcompute.spm.elf --data-folder=extreme
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
./ci/sys-run.sh --binary=sw/tests/lagd_debug_dt.spm.elf --core-tested=0
```

## Galena spin W/R test (for debugging)

File [lagd_debug_spin.spm.c](./lagd_debug_spin.spm.c) tests the spin writing and continuous spin reading of a single Galena macro.

Command:

```[bash]
./ci/sys-run.sh --binary=sw/tests/lagd_debug_spin.spm.elf --core-tested=0
```
