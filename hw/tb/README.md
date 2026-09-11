# This folder is for the SoC verification.

## Preload modes

How the test binary reaches memory before it runs, selected with
`./ci/sys-run.sh --preload=N` (also accepted by `./ci/regression-run.sh`):

| N | mode | needs the boot ROM? | notes |
|---|------|---------------------|-------|
| 0 | JTAG | no  | default. Halts the core, writes memory over the debug module, resumes. Bypasses the boot ROM entirely. |
| 1 | UART | yes | the boot ROM's UART debug protocol. |
| 2 | SPI  | yes | passive boot: the SPI slave writes memory as an AXI master while the boot ROM spins on SCRATCH_2. |

Modes 1 and 2 are *passive boot* — they need the LAGD boot ROM, which
`sys-run.sh` builds automatically (the stock cheshire one sets a stack pointer
outside LAGD's 16 KiB stack RAM).

`--preload=2` mirrors what the FPGA driver does on real hardware
(`lagd-meas/sw/tools/spi_program_loader.py`): preload the sections, write the
entry point to SCRATCH_0/1, then set the go bit in SCRATCH_2. The tasks live in
[`include/lagd_test/spi_test_lib.sv`](include/lagd_test/spi_test_lib.sv)
(`spi_elf_run` / `spi_wait_for_eoc`) and are modelled on cheshire's
`slink_elf_run`. Program output still arrives over UART — the VIP's monitor
prints it as `[UART] ...` in every mode, no extra call needed.

```
./ci/sys-run.sh --preload=2 --binary=sw/tests/helloworld.spm.elf
./ci/regression-run.sh --preload=2 --tests=helloworld
```

## Performance analysis
The cycles per iteration (CPI) is in this range:

```
Min:
CYCLE_PER_SPIN_WRITE + CYCLE_PER_SPIN_COMPUTE + GCFG2_SYNCHRONIZER_PIPE_NUM + 1 (+5 of J memory cost if there is spin change)

Max:
NUM_SPIN/PARALLELISM + PIPESMID + 1 (PIPESINTF is hidden in steady state because the new spin pre-fills the bp_pipe during the current EM computation)
```

To warm up the pipeline, the first iteration takes a cycle of:

```
5 + (NUM_SPIN/PARALLELISM + PIPESMID + 1) + (CYCLE_PER_SPIN_WRITE + CYCLE_PER_SPIN_COMPUTE + GCFG2_SYNCHRONIZER_PIPE_NUM + 1)
```

Sometimes the CPI is smaller than the Min above. This happens when the current spin has no change but the previous spin has changes, which makes the current spin's latency be hidden by the previous one.

**To run a simulation on the Ising core, enter command**:

```
CORE_TESTED=0 (or 1) ./ci/sys-run.sh --binary=sw/tests/lagd_scompute.spm.elf |& tee hw/tb/sim.log
```

The default datafile initializes the spin fifo to:
`47521d517cba6af282eee17c90f7d4a31b70229c92cc7d5ab9e5e0470fdd237171d8485a7215bf025678c39e8590fbc342d8322d746aa379cf993a7c2f92e5c9`

The corresponding final output is:

energy fifo: `fffff35a_fffff33e`

spin fifo:
`4921a38cdee0f1f04e59101a65352659adc19528c3c193091a34436f1041ad1371fb38f143d99c2ed3de57c53b53dda2999b40c73eb90991ee3658aef634f74a`

Note:
- **The patch in the makefile for `vip_cheshire_soc.sv`** (`.bender/git/checkouts/cheshire-4912d4aca2fac633/target/sim/src/vip_cheshire_soc.sv`, line 344): The `jtag_elf_preload` loop uses `i <= sec_len` (inclusive), which causes one extra 64-bit write to `sec_addr + sec_len` after the last valid byte. For the last ELF section `.l1f_data_c1` at `0x90018000` (32 KB), this extra write targets `0x90020000`, which is unmapped in the AXI crossbar, causing a DECERR → `[JTAG] System bus error!`. Fix: the makefile automatically change `i <= sec_len` to `if (i < sec_len) begin ... end` to skip the write.
- To propagate a top-level parameter (e.g. ENV VAR or make argument) from makefile into C code, pass it to the compiler in [sw/Makefile](../../sw/Makefile) via CHS_SW_INCLUDES: CHS_SW_INCLUDES += -DPARAM=$(PARAM). Guard the default in C with: #ifndef PARAM / #define PARAM <default> / #endif
