# Galena testcases

## Digital pin inputs

| Signal | Width | Reset value | Register |
|--------|-------|------------ | -------- |
| `wbl` | `<1023:0>` | 0 | `debug_wbl_config` |
| `wblb` | `<1023:0>` | 1 | NOT `debug_wbl_config` |
| `wbl_floating` | `<1023:0>` | 0 ⚠️ | `wbl_floating` |
| `wwl` | `<256:0>` | 0 | `debug_j_one_hot_wwl` + `global_cfg_2.debug_h_wwl` (bit 256) |
| `wwl_vdd` | `<256:0>` | 0 | `wwl_vdd_cfg` + `global_cfg_1.wwl_vdd_cfg_256` (bit 256) |
| `wwl_vread` | `<256:0>` | 0 | `wwl_vread_cfg` + `global_cfg_1.wwl_vread_cfg_256` (bit 256) |
| `write_spin` | `<255:0>` | 0 | `spin_wwl_strobe` |
| `feedback` | `<255:0>` | 0 | `spin_feedback_cfg` |


## Digital pin outputs

| Signal | Width | Register |
|--------|-------|----------|
| `wbl_read_o` | `<1023:0>` | `debug_wbl_read_data` |
| `wblb_read_o` | `<1023:0>` | `debug_wblb_read_data` |
| `bct_read_o` | `<255:0>` | `debug_aw_spin_out` (also flip mem / `spin_fifo_data_*`) |


## PCB analog controls

| Control | Off | Max | Default operating point |
|---------|-----|-----|----------------------|
| `j_up` | 0 mA | 5 mA | 250 µA |
| `j_dn` | 0 mA | 5 mA | 250 µA |
| `h_up` | 0 mA | 5 mA | 250 µA |
| `h_dn` | 0 mA | 5 mA | 250 µA |
| `vread` | 0 V | 750 mV | 400 mV |

The bias currents are divided down by on-chip current mirrors, so the current the array
actually sees is not the value forced on the pin:

```
I_cu_internal = I_cu / 64      # 250 µA in  ->  ~4 µA on-chip
I_hu_internal = I_hu / 2       # 250 µA in  ->  ~16*4 µA on-chip
```


---

# Controlling the galena interface from registers

Everything below was traced directly in the RTL. Line references are to
`im/hw/rtl/` and are given as `file:line` so each claim can be re-checked.

## The galena instance

`ising_core_wrap.sv:428-446` instantiates the analog macro. This is the ground
truth for what "a galena pin" means:

```systemverilog
galena u_galena (
    .wbl_i          (wbl_in_analog          ),  // 1024b
    .wblb_i         (wblb_in_analog         ),  // 1024b
    .wbl_floating_i (wbl_floating_in_analog ),  // 1024b
    .wwl_i          ({h_wwl, j_one_hot_wwl} ),  //  257b  <- concatenation!
    .wwl_vdd_i      (wwl_vdd_analog         ),  //  257b
    .wwl_vread_i    (wwl_vread_analog       ),  //  257b
    .write_spin_i   (spin_wwl               ),  //  256b
    .feedback_i     (spin_feedback_in_analog),  //  256b
    .wbl_read_o     (wbl_out_analog         ),  // 1024b
    .wblb_read_o    (wblb_out_analog        ),  // 1024b
    .bct_read_o     (spin_out_analog        ),  //  256b
    .j_vup_aio, .j_vdn_aio, .h_vup_aio, .h_vdn_aio, .vread_aio  // PCB analog
);
```

Widths come from `hw/rtl/include/lagd_define.svh:57-59`: `NUM_SPIN=256`,
`BIT_J=BIT_H=4`, so the WBL-family vectors are `256*4 = 1024` bits.

**`wwl_i` is a concatenation, not one register.** `wwl[255:0] = j_one_hot_wwl`
and `wwl[256] = h_wwl`. They come from different registers and are driven by
different logic — see the `wwl` section below.

## The two-layer model

Software never drives a galena pin directly. Each pin is fed by a *shadow*
(bottom-layer) flop inside `analog_macro_wrap` / its debug submodules. A CSR
write only lands on the pin when the matching **commit** signal fires. Three
commit styles exist, and mixing them up is the main source of "I wrote the
register and nothing happened":

| style | behaviour | how software drives it |
|---|---|---|
| **level** | shadow flop tracks the CSR continuously *while the bit is high*, freezes when it drops | set the bit, leave it set while you write the data, then clear |
| **posedge** | edge-detected to a 1-cycle internal pulse; starts a timed state machine | set the bit then clear it (the `enable_x(); disable_all_debug()` idiom in `lagd_common.h` is correct and deliberate) |
| **level+posedge** | staged by a level bit, then pushed to the pin by a posedge bit | do both, in order |

The posedge detectors are explicit in the RTL: `analog_macro_wrap.sv:152-162`
(`debug_j_write_en_posedge`, `debug_j_read_en_posedge`,
`debug_spin_write_en_posedge`, `debug_spin_compute_en_posedge`,
`debug_spin_read_en_posedge`) and `digital_macro.sv:270-271`
(`config_valid_aw_posedge`, `dt_cfg_enable_posedge`).

### Global gate: `en_aw`

`analog_macro_wrap.en_i` is `en_aw` = `global_cfg_1[1]` (`ising_core_wrap.sv:234`,
`digital_macro.sv:617`). It is **1 at reset**, but almost every commit below is
`en_i & <commit>`, so if `en_aw` is ever cleared, none of these paths work.

> One asymmetry worth knowing: the WBL staging flop in `analog_dt_debug.sv:77`
> loads on bare `configure_enable_i` (**no** `en_i` term), while the equivalent
> flop in `analog_spin_debug.sv:72,106` uses `en_i & configure_enable_i`.
> Staging WBL data therefore works even with `en_aw=0`; pushing it to the pin
> does not.

### Register addressing

Per-core register block base is `IC_REGS_BASE_ADDR + core * IC_NUM_REGS`
= `0x3000_0000 + core * 0x1000` (`lagd_define.svh:44,55`).

All wide vectors are little-endian across their multireg words
(`ising_core_wrap.sv:289-307`): `vector[i*32 +: 32] = reg[i]`. So

```
bit b  ->  word index b / 32 , bit position b % 32
```

Setting a whole vector to all-ones is just N full-word writes of `0xFFFFFFFF`
(no read-modify-write needed); setting a single bit needs RMW on one word.

---

## Input pins

### `wbl` / `wblb`

`wbl_o` is a 3-way mux (`analog_macro_wrap.sv:182-183`):

```systemverilog
wbl_o = (~debug_analog_dt_w_idle) ? debug_wbl_dt_write   // dt debug write
      : (~debug_spin_w_idle     ) ? debug_wbl_spin       // spin debug write
      :                             wbl_write_output;    // normal datapath
```

so there are **two independent ways** to drive WBL from software, plus the
normal compute path (`wbl_write_output = dt_cfg_idle ? wbl_spin_expanded : wbl_dt`,
line 194 — J/h onloading or live spin, neither software-controlled directly).

**Path A — data/weight debug write (the one `lagd_debug_dt.spm.c` uses)**

- CSR: `debug_wbl_config[0..31]` (1024b)
- Stage: `debug_dt_configure_enable` (`global_cfg_1[8]`, **level**) loads
  `wbl_dt_reg` (`analog_dt_debug.sv:77`)
- Commit: `debug_j_write_en` (`global_cfg_1[15]`, **posedge**) loads
  `wbl_o` from `wbl_dt_reg` (`analog_dt_debug.sv:74`)
- Poll: `output_status.debug_analog_dt_w_idle` (bit 5) returns to 1 when done
- Auto-clears: both flops are cleared by `wwl_low_counter_maxed`, i.e. WBL
  returns to 0 at the end of the pulse. **This is not a static drive.**

**Path B — spin debug write**

- CSR: `debug_wbl_config[0..31]` again — *the same register feeds both paths*
  (`analog_macro_wrap.sv:356` vs `:388`)
- Stage: `debug_spin_configure_enable` (`global_cfg_1[9]`, level) loads
  `wbl_spin_reg` (`analog_spin_debug.sv:106`)
- Commit: `debug_spin_write_en` (`global_cfg_1[17]`, posedge)
- Poll: `output_status.debug_spin_w_idle` (bit 7)

**`wblb` cannot be set independently.** It is derived (`analog_macro_wrap.sv:184-185`):

| active path | `wblb_o` |
|---|---|
| dt debug write | `~wbl_o` (true complement) |
| spin debug write | **hard-wired to 0** — `wblb_spin_o = 'd0` (`analog_spin_debug.sv:97`) |
| normal | `~wbl_write_output` |

⚠️ Note the middle row: during a *spin* debug write, WBLB is 0, **not** the
complement. The doc table's "reset value 1" for `wblb` only describes the
normal/dt path.

### `wbl_floating`

- CSR: `wbl_floating[0..31]` (1024b)
- Commit: `debug_dt_configure_enable` **only** — pure level passthrough
  (`analog_macro_wrap.sv:189`); no posedge stage, no idle bit
- Output is the shadow flop directly (`analog_macro_wrap.sv:178`)

⚠️ **Reset value is all-ones, not 0**: the `FFL` reset argument is
`{NUM_SPIN*BITDATA{1'b1}}` (`analog_macro_wrap.sv:189`). The "Digital pin inputs"
table above is flagged with ⚠️ for exactly this reason.

There is no `config_valid_aw` path for this signal — it is debug-only.

### `wwl` (= `j_one_hot_wwl[255:0]` + `h_wwl[256]`)

Mux (`analog_macro_wrap.sv:149-150`):

```systemverilog
j_one_hot_wwl_o = (~debug_analog_dt_idle) ? debug_j_write_wwl : j_one_hot_wwl_cfg_output;
h_wwl_o         = (~debug_analog_dt_idle) ? debug_h_write_wwl : h_wwl_cfg_out;
```

Note this uses `debug_analog_dt_idle` (write **or** read busy), so WWL is driven
by the debug path during *both* debug write and debug read.

- CSR (bits 0-255): `debug_j_one_hot_wwl[0..7]`
- CSR (bit 256): `debug_h_wwl` = **`global_cfg_2[7]`**
- Commit: `debug_j_write_en` (posedge) for a write, `debug_j_read_en`
  (`global_cfg_1[16]`, posedge) for a read
- Poll: `debug_analog_dt_w_idle` / `debug_analog_dt_r_idle`
- Timing: WWL is asserted for `cycle_per_wwl_high` cycles then de-asserted
  (`analog_dt_debug.sv:72-73`, cleared on `wwl_high_counter_maxed`); WBL stays
  a further `cycle_per_wwl_low` cycles. Both counters come from
  `counter_cfg_1`/`counter_cfg_2`.

⚠️ The "+1 bit" is **not** in the same place as for `wwl_vdd`/`wwl_vread` — those
put bit 256 in `global_cfg_1`, `wwl` puts it in `global_cfg_2`. Do not assume a
uniform layout across the three 257-bit vectors.

### `wwl_vdd` / `wwl_vread`

- CSR (bits 0-255): `wwl_vdd_cfg[0..7]` / `wwl_vread_cfg[0..7]`
- CSR (bit 256): `wwl_vdd_cfg_256` = `global_cfg_1[28]`,
  `wwl_vread_cfg_256` = `global_cfg_1[29]` (`ising_core_wrap.sv:298-299`)
- Commit — **two independent paths OR'd together** (`analog_macro_wrap.sv:199-200`):
  ```systemverilog
  `FFL(wwl_vdd_reg, wwl_vdd_i,
       (en_i & (analog_wrap_configure_enable_i | debug_dt_configure_enable_i)), 'b0, ...)
  ```
  - `config_valid_aw` (`global_cfg_2[1]`) → edge-detected to
    `config_valid_aw_posedge` (`digital_macro.sv:270,618`) — **one-shot latch**
  - `debug_dt_configure_enable` — **level passthrough**
- Poll: none. Shadow reset value is 0.
- These are static once latched (no auto-clear), unlike WBL/WWL.

### `write_spin`  *(resolved — it is `spin_wwl_strobe`)*

`galena.write_spin_i` ← `spin_wwl` ← `analog_macro_wrap.spin_wwl_o`
(`ising_core_wrap.sv:435,541`), which muxes (`analog_macro_wrap.sv:180`):

```systemverilog
spin_wwl_o = (~debug_spin_w_idle) ? debug_spin_wwl : spin_wwl_rx_output;
```

and `debug_spin_wwl` = `w_busy_status ? spin_wwl_strobe_reg : 'd0`
(`analog_spin_debug.sv:94`), with
`` `FFL(spin_wwl_strobe_reg, spin_wwl_strobe_i, config_cond, ...) `` (line 104).

- CSR: **`spin_wwl_strobe[0..7]`** (256b) — *not* `config_spin_initial_*`
- Stage: `debug_spin_configure_enable` (`global_cfg_1[9]`, level)
- Commit: `debug_spin_write_en` (`global_cfg_1[17]`, posedge)
- Poll: `output_status.debug_spin_w_idle` (bit 7)
- Held for `cycle_per_spin_write` cycles (`counter_cfg_2[31:16]`), then returns
  to 0 (`analog_spin_debug.sv:99,118-123`)

`config_spin_initial_0/1` is a different thing entirely: it feeds the flip
manager's spin FIFO (`digital_macro.sv:583`), never galena's `write_spin_i`.

The normal-compute path uses the *same* `spin_wwl_strobe` CSR via `analog_rx`
(`analog_rx.sv:74`, staged by `config_valid_aw` instead).

### `feedback`

`galena.feedback_i` ← `spin_feedback_in_analog` ← `analog_macro_wrap.spin_feedback_o`
(`analog_macro_wrap.sv:181`):

```systemverilog
spin_feedback_o = ((~debug_spin_feedback_idle) | (~debug_spin_r_idle))
                ? debug_spin_feedback : spin_feedback_rx_output;
```

with `debug_spin_feedback` = `(feedback_busy_status | r_busy_status) ? spin_feedback_reg : 'd0`
(`analog_spin_debug.sv:95`).

- CSR: `spin_feedback_cfg[0..7]` (256b)
- Stage: `debug_spin_configure_enable` (level) — `analog_spin_debug.sv:105`
- Commit: `debug_spin_compute_en` (`global_cfg_1[18]`, posedge) **or**
  `debug_spin_read_en` (`global_cfg_1[19]`, posedge) — the feedback value is
  applied for the duration of either operation
- Poll: `output_status.debug_spin_cmpt_idle` (bit 9) / `debug_spin_r_idle` (bit 8)
- Held for `cycle_per_spin_compute` cycles (`counter_cfg_3[15:0]`) in the
  compute case (`analog_spin_debug.sv:100,126-140`)

The normal path stages the same CSR through `analog_rx` (`analog_rx.sv:75`,
gated by `config_valid_aw`).

---

## Reading pins back

### `wbl_read_o` / `wblb_read_o`

Both come back through **one shared synchronizer**, `u_analog_tx_wbl`
(`analog_macro_wrap.sv:315-336`), which is an `analog_tx` instance parameterised
to `2*NUM_SPIN*BITDATA` = 2048 bits carrying `{wblb_read_i, wbl_read_i}` and
splitting into `{debug_wblb_read_data_o, debug_wbl_read_data_o}`.

Sequence:

1. Stage the pattern and pipe depth: set `debug_dt_configure_enable` (level).
   This also loads `synchronizer_wbl_pipe_num` (`global_cfg_1[31:30]`) into the
   synchronizer (`analog_tx.sv:65`, `tx_configure_enable_i` = the same bit).
2. Pulse `debug_j_read_en` (posedge).
3. The capture strobe is `debug_dt_sync_en = r_busy_status & wwl_high_counter_maxed`
   (`analog_dt_debug.sv:66`) — i.e. the sample is taken when the WWL-high counter
   expires, *during* the read.
4. `debug_wbl_read_data_valid_o` rises → mirrored into
   `output_status.debug_wbl_read_data_valid` (bit 4, `ising_core_wrap.sv:315,359`)
   and used as the `.de` write-enable for the data registers
   (`ising_core_wrap.sv:418-421`).
5. Read `debug_wbl_read_data[0..31]` and `debug_wblb_read_data[0..31]` (1024b each).

`spin_ready_i` is tied to `1'b1` on this instance (`analog_macro_wrap.sv:332`),
so the capture never back-pressures — the registers always hold the most recent
sample.

Existing helpers: `lagd_print_debug_wbl_read_data()` /
`lagd_check_debug_wbl_read_data()` in `im/sw/include/lagd_common.h`.

### `bct_read_o`  *(resolved — it IS readable, three ways)*

`bct_read_o` → `spin_out_analog` → `digital_macro.spin_analog_i` →
`u_analog_tx_spin` synchronizer → `analog_spin` (`digital_macro.sv:658`).
Capture strobe (`analog_macro_wrap.sv:187`):

```systemverilog
analog_macro_cmpt_finish = debug_spin_read_addr_busy ? debug_spin_sync_en
                                                     : analog_macro_cmpt_finish_rx_out;
```

From `analog_spin`, three readback routes exist:

**(a) Direct register snapshot — `debug_aw_spin_out[0..7]` (256b)**

`debug_aw_spin_out_o = analog_spin` (`digital_macro.sv:285`), captured into the
register whenever **`ctnus_dgt_debug`** (`global_cfg_2[15]`) is set
(`ising_core_wrap.sv:405`). This is the most direct "read the BCT pins" path and
needs no debug-spin sequencing — just set `ctnus_dgt_debug` and read the register.
There is no `lagd_*` helper for this yet.

**(b) Bulk capture into flip memory — debug spin read**

Pulsing `debug_spin_read_en` (`global_cfg_1[19]`) sets `debug_spin_read_addr_busy`
(`analog_macro_wrap.sv:190`) and starts an address counter loaded with
`debug_spin_read_num` (`counter_cfg_4[15:0]`). While busy, each synchronized
sample is written **into L1 flip memory** at `debug_spin_waddr`
(`ising_core_wrap.sv:596-612` — the flip-memory request mux switches to *write*
mode). Sample rate is `debug_cycle_per_spin_read` (`counter_cfg_3[31:16]`).

Software then reads the samples as **memory**, not registers — that is what
`lagd_print_l1_f_mem()` / `lagd_check_l1_f_mem()` in `lagd_common.h` are for.
Poll `output_status.debug_spin_r_idle` (bit 8) for completion.

⚠️ This **overwrites the flip-icon memory contents**, so it cannot be mixed with
a live annealing run.

**(c) Normal compute output — `spin_fifo_data_0/1[0..7]`**

In ordinary operation the synchronized spins flow through the flip manager and
land in `spin_fifo_data_0/1`, captured (`.de`) on `cmpt_idle_posedge | (ctnus_dgt_debug &
spin_fifo_update) | ctnus_fifo_read` (`ising_core_wrap.sv:402-403`) — so besides
the normal `cmpt_idle` posedge / `ctnus_fifo_read` capture, the register also
updates whenever `ctnus_dgt_debug` is set and `spin_fifo_update` pulses (the
same continuous-digital-debug capture strobe used for `energy_fifo_data_0/1`,
line 327-328). This is the path `lagd_print_spin_fifo_data()` and
`lagd_check_spin_fifo_data()` use.

---

## Worked recipes

### Write a WBL pattern into the array and read it back

```
1. wwl_vdd_cfg[0..7] + global_cfg_1.wwl_vdd_cfg_256   = pattern   (or wwl_vread_*)
2. counter_cfg_1.cycle_per_wwl_high / counter_cfg_2.cycle_per_wwl_low = timing
3. debug_wbl_config[0..31]      = WBL data
   debug_j_one_hot_wwl[0..7]    = row select (one-hot)
   global_cfg_2.debug_h_wwl     = 1 to address the h row instead
4. global_cfg_1.debug_dt_configure_enable = 1     // level: stage + latch wwl_vdd/vread
   global_cfg_1.debug_dt_configure_enable = 0
5. global_cfg_1.debug_j_write_en = 1 ; = 0        // posedge: run the timed write
6. poll output_status.debug_analog_dt_w_idle == 1
7. wbl_floating[0..31] = float mask
   global_cfg_1.debug_dt_configure_enable = 1 ; = 0
8. global_cfg_1.debug_j_read_en = 1 ; = 0         // posedge: run the timed read
9. poll output_status.debug_wbl_read_data_valid
10. read debug_wbl_read_data[0..31], debug_wblb_read_data[0..31]
```

This is exactly the sequence in `im/sw/tests/lagd_debug_dt.spm.c`.

### Read the BCT pins

```
global_cfg_2.ctnus_dgt_debug = 1
read debug_aw_spin_out[0..7]
```

---

## Summary table

| galena pin | CSR | stage (level) | commit (posedge) | poll |
|---|---|---|---|---|
| `wbl` (dt) | `debug_wbl_config[0..31]` | `debug_dt_configure_enable` | `debug_j_write_en` | `debug_analog_dt_w_idle` |
| `wbl` (spin) | `debug_wbl_config[0..31]` | `debug_spin_configure_enable` | `debug_spin_write_en` | `debug_spin_w_idle` |
| `wblb` | — (derived) | — | — | — |
| `wbl_floating` | `wbl_floating[0..31]` | `debug_dt_configure_enable` | — | — |
| `wwl[255:0]` | `debug_j_one_hot_wwl[0..7]` | — | `debug_j_write_en` / `debug_j_read_en` | `debug_analog_dt_w_idle` / `_r_idle` |
| `wwl[256]` | `global_cfg_2.debug_h_wwl` | — | same as above | same as above |
| `wwl_vdd[255:0]` | `wwl_vdd_cfg[0..7]` | `debug_dt_configure_enable` | `config_valid_aw` | — |
| `wwl_vdd[256]` | `global_cfg_1.wwl_vdd_cfg_256` | same | same | — |
| `wwl_vread[255:0]` | `wwl_vread_cfg[0..7]` | `debug_dt_configure_enable` | `config_valid_aw` | — |
| `wwl_vread[256]` | `global_cfg_1.wwl_vread_cfg_256` | same | same | — |
| `write_spin` | `spin_wwl_strobe[0..7]` | `debug_spin_configure_enable` | `debug_spin_write_en` | `debug_spin_w_idle` |
| `feedback` | `spin_feedback_cfg[0..7]` | `debug_spin_configure_enable` | `debug_spin_compute_en` / `debug_spin_read_en` | `debug_spin_cmpt_idle` / `_r_idle` |
| `wbl_read_o` | `debug_wbl_read_data[0..31]` (RO) | — | `debug_j_read_en` | `debug_wbl_read_data_valid` |
| `wblb_read_o` | `debug_wblb_read_data[0..31]` (RO) | — | `debug_j_read_en` | `debug_wbl_read_data_valid` |
| `bct_read_o` | `debug_aw_spin_out[0..7]` (RO) | — | `ctnus_dgt_debug` (level) | — |

## Gotchas

1. **WBL and WWL auto-clear.** Both are cleared by the pulse-end counters
   (`analog_dt_debug.sv:72-74`), so a debug write is a *pulse*, not a static
   drive. `wwl_vdd`/`wwl_vread`/`wbl_floating` shadow flops do persist.
2. **`wbl_floating` resets to all-ones**, not zero (`analog_macro_wrap.sv:189`).
3. **`wblb` is 0 (not `~wbl`) during a spin debug write** (`analog_spin_debug.sv:97`).
4. **The 257th bit lives in different registers** for `wwl` (`global_cfg_2[7]`)
   vs `wwl_vdd`/`wwl_vread` (`global_cfg_1[28]`/`[29]`).
5. **`debug_wbl_config` is shared** by the dt-debug and spin-debug write paths.
6. **Debug-spin read destroys flip memory** — it writes samples over the flip
   icons (`ising_core_wrap.sv:605-612`).
7. **`en_aw` (`global_cfg_1[1]`) gates almost everything**; it is 1 at reset but
   `lagd_configure_global_cfg_1()` rewrites the whole word from `GCFG1_*`
   constants, so check `lagd_reg_params.h` before assuming.
8. **Interlocks:** within each debug module a new request is ignored while busy
   (`analog_dt_debug.sv:57-58`, `analog_spin_debug.sv:77-79`), and there is a
   fixed priority (write > compute > read). Always poll the idle bit rather than
   issuing back-to-back pulses.

## Still open

- The `bct_read_o` → `debug_aw_spin_out` path (route **a**) is inferred from the
  RTL wiring and is not exercised by any existing `lagd_*` helper or test, so it
  is unverified on silicon. Worth a bring-up check before relying on it.
