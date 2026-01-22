# Digital Macro Testbench

This folder is for function verification of the digital macro module.

## Description

This module is the top module of the digital logic for a single Ising core.

## Testbench parameters

*DataFromFile*: whether the input data is from the data file, or randomly generated.

*EnComparison*: whether to enable energy comparison before loading the new value into the energy and spin FIFO.

*EnableFlipDetection*: whether to enable flip detection feature to speed up the energy calculation speed.

*FlipDisable*: whether to disable the flip icon when generating the next spin output.

*EnableAnalogLoop*: whether to involve the analog macro wrap module into the datapath loop.

## Testcases

Per combination of all parameters (32 cases in total) has been tested and passed.

## Functional verification script

A python functional verification script is made at [autotest_digital_macro.py](../../../utils/autotest_digital_macro.py). It does automatical function verification under all cases. The script can be run by entering in terminal:

`
python utils/autotest_digital_macro.py
`
