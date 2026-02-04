# LAGD CORE REG

## Description

This folder contains the register interface module for a LAGD core. The file is auto-generated using [regtool](https://github.com/lowRISC/opentitan/blob/master/util/regtool.py) from opentitan. Its manual can be found [here](https://opentitan.org/book/util/reggen/index.html).

The input file is [`lagd_core_regs.hjson`](./lagd_core_regs.hjson), where the registers are defined.

The command to generate `lagd_core_reg_top.sv`, `lagd_core_reg_pkg.sv` and `lagd_core_reg.h` is:

```
make all
```

