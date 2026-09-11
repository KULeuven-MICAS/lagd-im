# Known issues: `hemaia_axi_spi_slave`

Author: Jiacong Sun

Date: 2026/08/27

Two behaviours of the chip's SPI slave that are **not bugs in our code** and are
**not fixed**. Both were found by connecting the real FPGA Quad-SPI master RTL
(from the sibling `lagd-meas` repo) to the real chip slave RTL — see
[`hw/tb/spi_cosim/`](../hw/tb/spi_cosim/), if that testbench still exists.

They are recorded here rather than in the RTL because `hemaia_axi_spi_slave` is a
**vendored Bender checkout** (`.bender/git/checkouts/hemaia_axi_spi_slave-*`): any
comment added there is wiped by the next dependency update.

Neither affects the SPI link itself, which is verified working on hardware. They
matter because this IP is going into the tapeout.

---

## 1. Speculative AXI reads past the end of every read burst

**Measured:** 2935 AXI reads served for 2845 requested words across 15 read
transactions — exactly **6 extra reads per read burst**.

**Cause:** `spi_slave_axi_plug.sv` advances `Data -> AxiAddr` after every word
handshake and only returns to `Idle` when CS rises. Between the last requested
word and the rising CS edge it keeps issuing reads at incrementing addresses.

**Why it matters on silicon.** The testbench backs the slave with a flat memory
model, so the extra reads are invisible there. On the real SoC they are issued
onto the Cheshire AXI crossbar at real addresses beyond the requested range:

* **Unmapped space** — the crossbar returns a decode error (`0xBADCAB1E`). The
  data is discarded, so this is harmless.
* **A read-sensitive peripheral register** — the read *happens*. Anything that
  changes state when read (a FIFO pop, a clear-on-read status bit) is disturbed
  by a transaction no software asked for.

The exposure is narrow — the burst must end within 6 words (24 bytes) below such
a register — but the failure would be intermittent and would look like a software
bug, not a bus bug.

**Suggested check before tapeout:** confirm no read-sensitive register sits within
24 bytes above any address range the SPI loader writes or reads. If one does,
either pad the map or stop the burst short.

---

## 2. `wrap_length` is never programmed and works by underflow

**Cause:** the slave's `wrap_length` (registers `reg2`/`reg3`) resets to 0, and
the driver never writes it. Every wrap comparison is therefore
`tx_counter == wrap_length - 1`, i.e. `0 - 1` = `0xFFFF`.

**Effect:** integer underflow makes this behave as "never wrap", which is the
desired behaviour for every burst under 65536 words — so it works today by
accident rather than by intent.

**Where it breaks:** at exactly **65536 words** (256 KiB) in a single frame, the
counter reaches `0xFFFF`, wraps, and the address snaps back to the base — silently
overwriting the start of the transfer.

**Why it has not bitten us:** the SPI program loader splits at `MAX_BURST_WORDS`
(0xFFFF = 65535 words), one below the threshold. That is a coincidence of the
16-bit length field, not a deliberate guard.

**Suggested fix:** program `reg2`/`reg3` explicitly at init instead of relying on
the underflow, so the behaviour is stated rather than inferred.
