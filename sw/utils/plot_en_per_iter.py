#!/usr/bin/env python3
# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author: Jiacong Sun <jiacong.sun@kuleuven.be>
#
# Parse a simulation/UART log file and plot energy_fifo_data_sel vs fm_rx_cnt.
# Usage: python3 plot_en_per_iter.py [logfile] [--parity odd|even]

import re
import sys
import argparse
import math
import matplotlib.pyplot as plt

# config
parser = argparse.ArgumentParser(description="Plot energy_fifo_data_sel vs fm_rx_cnt.")
parser.add_argument("logfile", nargs="?", default="sim1.log", help="Log file to parse")
parser.add_argument(
    "--parity",
    choices=["odd", "even"],
    default=None,
    help="Only plot samples where fm_rx_cnt is odd or even (default: plot all)",
)
args = parser.parse_args()
LOG_FILE = args.logfile

# Matches lines like:
# [UART] idx/cmpt_idle/fm_rx_cnt/energy_fifo_data_sel for core 1: 233 0 277 f374
PATTERN = re.compile(
    r"idx/cmpt_idle/fm_rx_cnt/energy_fifo_data_sel for core \d+:\s+"
    r"(\d+)\s+(\d+)\s+(\d+)\s+([0-9a-f]+)"
)

# parse
fm_rx, energy_fifo_data_sel = [], []

with open(LOG_FILE) as f:
    for line in f:
        m = PATTERN.search(line)
        if m:
            curr_fm_rx = int(m.group(3))
            if args.parity == "odd" and curr_fm_rx % 2 == 0:
                continue
            if args.parity == "even" and curr_fm_rx % 2 != 0:
                continue
            # idx, cmpt_idle, fm_rx_cnt, energy_fifo_data_sel
            fm_rx.append(math.ceil(curr_fm_rx / 2) if args.parity else curr_fm_rx)
            hex_val = int(m.group(4), 16)
            energy_fifo_data_sel.append(hex_val if hex_val < 0x8000 else hex_val - 0x10000)

if not fm_rx:
    print(f"No data found in {LOG_FILE}")
    sys.exit(1)

print(f"Parsed {len(fm_rx)} samples from {LOG_FILE}")

# plot
fig, ax_left = plt.subplots(figsize=(10, 5))
ax_right = ax_left.twinx()

sc1 = ax_left.scatter(
    fm_rx,
    energy_fifo_data_sel,
    s=10,
    color="steelblue",
    alpha=0.7,
    label="Energy FIFO Data Sel",
)

ax_left.set_xlabel("Iteration counts", fontsize=12, fontweight="bold")
ax_left.set_ylabel("Energy FIFO Data Sel", color="steelblue", fontsize=12, fontweight="bold")
ax_left.tick_params(axis="y", labelcolor="steelblue")

lines = [sc1]
labels = [s.get_label() for s in lines]
ax_left.legend(lines, labels, loc="upper right", fontsize=10)

parity_suffix = f" [{args.parity} fm_rx only]" if args.parity else ""
plt.title(
    f"Energy FIFO Data Sel vs Iteration counts  ({LOG_FILE}){parity_suffix}",
    fontsize=14,
    fontweight="bold",
)
fig.tight_layout()

parity_tag = f"_{args.parity}" if args.parity else ""
out = LOG_FILE.rsplit(".", 1)[0] + f"_energy_fifo_data_sel_plot{parity_tag}.png"
plt.savefig(out, dpi=150)
print(f"Saved plot to {out}")
plt.show()
