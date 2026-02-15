# Digital Macro Testbench

This folder is for function verification of the ising_core_wrap module.

To run the testbench, enter the command:

```
./ci/ut-run.sh --test=ising_core_wrap --defines="DATA_FROM_FILE=1"
```

There is no automatic checkers or scoreboards in the testbench. The final energy and spin results are manually checked to be the same as the one from the digital macro testbench.