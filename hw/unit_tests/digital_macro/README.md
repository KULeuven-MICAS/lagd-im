# Digital Macro Testbench

This folder is for function verification of the digital macro module.

## Description

This module is the top module of the digital logic for a single Ising core.

Enter the command below to run the testbench:

```
./ci/ut-run.sh --test=digital_macro --defines="DataFromFile=1 EnComparison=1 EnableFlipDetection=1 FlipDisable=0 EnableAnalogLoop=1"
```

Another option is to run the autotest script in python, by entering the command:

```
python utils/autotest_digital_macro.py
```

## Testbench parameters

*DataFromFile*: whether the input data is from the data file, or randomly generated.

*EnComparison*: whether to enable energy comparison before loading the new value into the energy and spin FIFO.

*EnableFlipDetection*: whether to enable flip detection feature to speed up the energy calculation speed.

*FlipDisable*: whether to disable the flip icon when generating the next spin output.

*EnableAnalogLoop*: whether to involve the analog macro wrap module into the datapath loop.

## Testcases

Per combination of all parameters (32 cases in total) has been tested and passed. All tested cases are tabulated as below, with abbreviations of:

- DF:  DataFromFile (DF0: input data is randomly generated. DF1: input data is read from files.)
- EC:  EnComparison (EC0: energy/spin FIFO keeps the next outcome. EC1: energy/spin FIFO keeps the best outcome.)
- EFD: EnableFlipDetection (EFD0: disable the smarter computation feature in RTL. EFD1: enable the smarter computation feature in RTL.)
- FD:  FlipDisable (FD0: apply flipping when generating next spin vector. FD1: no flipping when generating next spin vector.)
- EAL: EnableAnalogLoop (EAL0: disconnect the analog wrap module within the iteration loop. EAL1: connect the analog wrap module within the iteration loop.)

| Testcase Name | Parameters                                          |
|:-------------:|:---------------------------------------------------:|
|DF0_EC0_EFD0_FD0_EAL0|DF=0, EC=0, EFD=0, FD=0, EAL=0|
|DF0_EC0_EFD0_FD0_EAL1|DF=0, EC=0, EFD=0, FD=0, EAL=1|
|DF0_EC0_EFD0_FD1_EAL0|DF=0, EC=0, EFD=0, FD=1, EAL=0|
|DF0_EC0_EFD0_FD1_EAL1|DF=0, EC=0, EFD=0, FD=1, EAL=1|
|DF0_EC0_EFD1_FD0_EAL0|DF=0, EC=0, EFD=1, FD=0, EAL=0|
|DF0_EC0_EFD1_FD0_EAL1|DF=0, EC=0, EFD=1, FD=0, EAL=1|
|DF0_EC0_EFD1_FD1_EAL0|DF=0, EC=0, EFD=1, FD=1, EAL=0|
|DF0_EC0_EFD1_FD1_EAL1|DF=0, EC=0, EFD=1, FD=1, EAL=1|
|DF0_EC1_EFD0_FD0_EAL0|DF=0, EC=1, EFD=0, FD=0, EAL=0|
|DF0_EC1_EFD0_FD0_EAL1|DF=0, EC=1, EFD=0, FD=0, EAL=1|
|DF0_EC1_EFD0_FD1_EAL0|DF=0, EC=1, EFD=0, FD=1, EAL=0|
|DF0_EC1_EFD0_FD1_EAL1|DF=0, EC=1, EFD=0, FD=1, EAL=1|
|DF0_EC1_EFD1_FD0_EAL0|DF=0, EC=1, EFD=1, FD=0, EAL=0|
|DF0_EC1_EFD1_FD0_EAL1|DF=0, EC=1, EFD=1, FD=0, EAL=1|
|DF0_EC1_EFD1_FD1_EAL0|DF=0, EC=1, EFD=1, FD=1, EAL=0|
|DF0_EC1_EFD1_FD1_EAL1|DF=0, EC=1, EFD=1, FD=1, EAL=1|
|DF1_EC0_EFD0_FD0_EAL0|DF=1, EC=0, EFD=0, FD=0, EAL=0|
|DF1_EC0_EFD0_FD0_EAL1|DF=1, EC=0, EFD=0, FD=0, EAL=1|
|DF1_EC0_EFD0_FD1_EAL0|DF=1, EC=0, EFD=0, FD=1, EAL=0|
|DF1_EC0_EFD0_FD1_EAL1|DF=1, EC=0, EFD=0, FD=1, EAL=1|
|DF1_EC0_EFD1_FD0_EAL0|DF=1, EC=0, EFD=1, FD=0, EAL=0|
|DF1_EC0_EFD1_FD0_EAL1|DF=1, EC=0, EFD=1, FD=0, EAL=1|
|DF1_EC0_EFD1_FD1_EAL0|DF=1, EC=0, EFD=1, FD=1, EAL=0|
|DF1_EC0_EFD1_FD1_EAL1|DF=1, EC=0, EFD=1, FD=1, EAL=1|
|DF1_EC1_EFD0_FD0_EAL0|DF=1, EC=1, EFD=0, FD=0, EAL=0|
|DF1_EC1_EFD0_FD0_EAL1|DF=1, EC=1, EFD=0, FD=0, EAL=1|
|DF1_EC1_EFD0_FD1_EAL0|DF=1, EC=1, EFD=0, FD=1, EAL=0|
|DF1_EC1_EFD0_FD1_EAL1|DF=1, EC=1, EFD=0, FD=1, EAL=1|
|DF1_EC1_EFD1_FD0_EAL0|DF=1, EC=1, EFD=1, FD=0, EAL=0|
|DF1_EC1_EFD1_FD0_EAL1|DF=1, EC=1, EFD=1, FD=0, EAL=1|
|DF1_EC1_EFD1_FD1_EAL0|DF=1, EC=1, EFD=1, FD=1, EAL=0|
|DF1_EC1_EFD1_FD1_EAL1|DF=1, EC=1, EFD=1, FD=1, EAL=1|

## Functional verification script

A python functional verification script is made at [autotest_digital_macro.py](../../../utils/autotest_digital_macro.py). It does automatical function verification under all 32 cases. The script can be run by entering in terminal:

`
python utils/autotest_digital_macro.py
`
