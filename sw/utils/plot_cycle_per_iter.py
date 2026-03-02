#!/usr/bin/env python3
# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author: Jiacong Sun <jiacong.sun@kuleuven.be>
#
# Parse a simulation/UART log file and plot cc_iter and cc_cmpt vs fm_rx_cnt_l7b.
# Usage: python3 plot_cycle_per_iter.py [logfile]

import re
import sys
import matplotlib.pyplot as plt

# config
LOG_FILE = sys.argv[1] if len(sys.argv) > 1 else "sim1.log"

# Matches lines like:
#   # [UART] idx/cmpt_idle/fm_rx_cnt_l7b/cc_iter/cc_cmpt for core 1: 572 0 127 16 25043
PATTERN = re.compile(
    r"idx/cmpt_idle/fm_rx_cnt_l7b/cc_iter/cc_cmpt for core \d+:\s+"
    r"(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)"
)

# parse
fm_rx, cc_iter, cc_cmpt = [], [], []

fm_offset = 0
prev_fm_rx = 0
with open(LOG_FILE) as f:
    for line in f:
        m = PATTERN.search(line)
        if m:
            curr_fm_rx = int(m.group(3))
            if curr_fm_rx < prev_fm_rx:
                fm_offset += 128  # fm_rx_cnt_l7b is 7-bit, so it wraps around after 127
            prev_fm_rx = curr_fm_rx
            # idx, cmpt_idle, fm_rx_cnt_l7b, cc_iter, cc_cmpt
            fm_rx.append(curr_fm_rx + fm_offset)
            cc_iter.append(int(m.group(4)))
            cc_cmpt.append(int(m.group(5)))

if not fm_rx:
    print(f"No data found in {LOG_FILE}")
    sys.exit(1)

print(f"Parsed {len(fm_rx)} samples from {LOG_FILE}")

# plot
fig, ax_left = plt.subplots(figsize=(10, 5))
ax_right = ax_left.twinx()

sc1 = ax_left.scatter(fm_rx, cc_iter, s=10, color="steelblue", alpha=0.7, label="Cycle/Iteration")
sc2 = ax_right.scatter(fm_rx, cc_cmpt, s=10, color="tomato", alpha=0.7, label="Cycle/Computation")

ax_left.set_xlabel("Iteration counts", fontsize=12, fontweight="bold")
ax_left.set_ylabel("Cycle/Iteration", color="steelblue", fontsize=12, fontweight="bold")
ax_right.set_ylabel("Cycle/Computation", color="tomato", fontsize=12, fontweight="bold")
ax_left.tick_params(axis="y", labelcolor="steelblue")
ax_right.tick_params(axis="y", labelcolor="tomato")

lines = [sc1, sc2]
labels = [s.get_label() for s in lines]
ax_left.legend(lines, labels, loc="upper left", fontsize=10)

plt.title(f"Cycle counts vs Iteration counts  ({LOG_FILE})", fontsize=14, fontweight="bold")
fig.tight_layout()

out = LOG_FILE.rsplit(".", 1)[0] + "_cycle_plot.png"
plt.savefig(out, dpi=150)
print(f"Saved plot to {out}")
plt.show()
