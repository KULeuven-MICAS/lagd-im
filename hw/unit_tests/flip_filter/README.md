# Flip Filter Testbench

# Description

This testbench verifies the function of the `flip_filter` module. The flip
filter compares each incoming (upstream) spin vector against the currently
selected baseline spin vector, detects which spins have flipped, and streams out
one read address per `PARALLELISM`-wide block that contains at least one flipped
spin. It also passes the upstream spin vector downstream and exposes the selected
baseline energy/spin.

Enter the command below to run the testbench:

```
./ci/ut-run.sh --test=flip_filter
```

## What is checked

For every transaction the self-checking scoreboard verifies:

- **Flip detection** – expected flipped bits are computed as
  `spin_baseline[baseline_idx] ^ spin_upstream` once the baseline is valid, and
  `all-ones` before that (flip detection disabled / baseline not yet valid).
- **Address stream** – exactly one address is generated for every block that
  contains a flipped bit, with no missing, extra, or duplicate addresses
  (`raddr_o` is mapped back to the logical block via `LITTLE_ENDIAN`).
- **`block_bits_flipped_o`** – matches the flipped bits of the granted block.
- **`empty_o`** – asserted iff no spin flipped; on an empty transaction no read
  address is generated and `raddr_last_one_o` is asserted.
- **Downstream passthrough** – `spin_downstream_o` equals the upstream spins and
  `spin_downstream_valid_o` tracks the (non-empty) handshake.
- **Baseline outputs** – `spin_baseline_o` / `energy_baseline_o` equal the
  baseline slice selected by the internal `baseline_idx` counter.

## Testbench parameters (applied value)

*NUM_SPIN* (256): number of spins.

*ENERGY_TOTAL_BIT* (32): bit precision of the baseline energy value.

*PARALLELISM* (4): spins processed per block / read address.

*SPIN_DEPTH* (2): number of stored baselines.

*LITTLE_ENDIAN* (0): address ordering (0 = MSB-first, 1 = LSB-first).

*PIPESINTF* (0): interface pipeline stages.

*PIPES_IN_ARBITER* (0): arbiter pipeline stages.

*CLKCYCLE* (2): clock cycle time (unit: ns).

*RANDOM_TEST* (1): use random stimulus (0 = fixed deterministic patterns).

*RADDR_BACKPRESSURE* (1): apply random backpressure on the read-address channel.

*NUM_WARMUP_TESTS* (6): transactions run to bring `curr_baseline_valid` high.

*NUM_RANDOM_TESTS* (40): main randomized transactions.

*NUM_EMPTY_TESTS* (4): transactions where upstream equals baseline (empty case).

## Testcases

### The following testcases have been verified (with the default configuration).

| Testcase Name | Description                          | Input Parameters                        |
|:-------------:|:------------------------------------:|:---------------------------------------:|
| Random        | Random stimulus with backpressure    | RANDOM_TEST=1, RADDR_BACKPRESSURE=1     |
| Fixed         | Deterministic pattern stimulus       | RANDOM_TEST=0                           |
| Empty         | Upstream matches baseline (no flips) | NUM_EMPTY_TESTS>0                        |
