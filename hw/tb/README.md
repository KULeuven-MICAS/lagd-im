This folder is for the SoC verification.

To run the simulation, enter command:

```
./ci/sys-run.sh --binary=sw/tests/lagd_scompute.spm.elf |& tee hw/tb/sim.log
```

Note:
- **Temporary fix in `vip_cheshire_soc.sv`** (`.bender/git/checkouts/cheshire-4912d4aca2fac633/target/sim/src/vip_cheshire_soc.sv`, line 344): The `jtag_elf_preload` loop uses `i <= sec_len` (inclusive), which causes one extra 64-bit write to `sec_addr + sec_len` after the last valid byte. For the last ELF section `.l1f_data_c1` at `0x90018000` (32 KB), this extra write targets `0x90020000`, which is unmapped in the AXI crossbar, causing a DECERR → `[JTAG] System bus error!`. Fix: wrap the two `jtag_write` calls inside `if (i < sec_len) begin ... end` to skip the write while preserving the final 100% progress display.