#!/usr/bin/env python3
# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author: Jiacong Sun <jiacong.sun@kuleuven.be>
#
# Convert a SystemVerilog header (.svh) to a C header (.h).
#
# Usage:
#   python3 svh2h.py <input.svh> <output.h>
#
# Supported SV constructs:
#   `include "foo.svh"          -> #include "foo.h"
#   `ifndef / `define / `endif  -> #ifndef / #define / #endif
#   `define NAME 'hXX_YY       -> #define NAME 0xXXYYUL
#   `define NAME <expr>         -> #define NAME (<expr>)  (backticks stripped)
#   `define NAME $clog2(<expr>) -> #define NAME <int>     (evaluated in Python)
#
# Defines whose values cannot be evaluated (e.g. $clog2 with unresolvable
# arguments, or other SV-specific functions) are emitted as comments.

import re
import sys
import math
import os


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def sv_hex_to_int(s):
    """Convert a SV hex literal string ('hXXXX with optional underscores)
    to a Python int.  Returns None if not a pure hex literal."""
    m = re.fullmatch(r"'h([0-9A-Fa-f_]+)", s.strip())
    if m:
        return int(m.group(1).replace('_', ''), 16)
    return None


def int_to_c_literal(n, force_decimal=False):
    """Format a Python int as a C unsigned hex or decimal literal.
    Use force_decimal=True for values that are naturally decimal (e.g. $clog2
    results such as bit widths 6, 14, 16 — not meaningful as hex)."""
    if force_decimal:
        return f"{n}U"
    if n > 0xFFFF:
        return f"0x{n:X}UL"
    elif n > 9:
        return f"0x{n:X}U"
    else:
        return f"{n}U"


def strip_backtick_refs(expr):
    """Remove SV backtick prefix from macro references: `NAME -> NAME."""
    return re.sub(r'`(\w+)', r'\1', expr)


def _collect_raw_defines(lines):
    """Collect {name: raw_value_str} from a list of lines."""
    raw = {}
    for line in lines:
        stripped = line.strip()
        m = re.match(r'^`define\s+(\w+)\s+(.+)', stripped)
        if not m:
            continue
        name = m.group(1)
        value_str = m.group(2).strip()
        value_str = re.sub(r'\s*//.*$', '', value_str).strip()
        raw[name] = value_str
    return raw


def build_symbol_table(lines, src_dir):
    """
    First pass: evaluate every `define and return {name: int_value}.

    Follows `include directives so that symbols from included files are also
    available (important for $clog2 and cross-file macro references).

    Only defines whose values reduce to a concrete integer are stored;
    expressions with unresolvable references or SV-only functions are skipped.
    """
    raw = {}  # name -> raw value string (before evaluation)

    def collect_from_lines(file_lines, file_dir):
        for line in file_lines:
            stripped = line.strip()
            # Follow include directives
            m = re.match(r'^`include\s+"([^"]+)"', stripped)
            if m:
                inc_path = os.path.join(file_dir, m.group(1))
                if os.path.isfile(inc_path):
                    with open(inc_path, 'r') as f:
                        inc_lines = f.readlines()
                    collect_from_lines(inc_lines, os.path.dirname(inc_path))
                continue
            # Collect `define NAME value
            dm = re.match(r'^`define\s+(\w+)\s+(.+)', stripped)
            if dm:
                name = dm.group(1)
                value_str = dm.group(2).strip()
                value_str = re.sub(r'\s*//.*$', '', value_str).strip()
                raw[name] = value_str

    collect_from_lines(lines, src_dir)

    table = {}  # name -> int

    # Iteratively resolve: keep looping until no more progress
    changed = True
    while changed:
        changed = False
        for name, value_str in raw.items():
            if name in table:
                continue
            result = _try_eval(value_str, table)
            if result is not None:
                table[name] = result
                changed = True

    return table


def _try_eval(value_str, table):
    """
    Try to evaluate a SV value expression to a Python int.
    Returns the int on success, None otherwise.
    """
    # Handle $clog2(expr)
    m = re.fullmatch(r'\$clog2\((.+)\)', value_str.strip())
    if m:
        inner = _try_eval(m.group(1).strip(), table)
        if inner is not None and inner > 0:
            return math.ceil(math.log2(inner))
        return None

    # Substitute backtick macro references
    def sub_ref(m):
        ref = m.group(1)
        if ref in table:
            return str(table[ref])
        return m.group(0)  # unresolved — leave as-is

    substituted = re.sub(r'`(\w+)', sub_ref, value_str)

    # If there are still unresolved backtick refs, bail
    if '`' in substituted:
        return None

    # If there are still unresolved SV functions, bail
    if '$' in substituted:
        return None

    # Try to parse as a pure SV hex literal
    as_int = sv_hex_to_int(substituted)
    if as_int is not None:
        return as_int

    # Try to evaluate as a Python arithmetic expression
    # Only allow safe tokens: digits, operators, spaces, parentheses
    safe = re.sub(r'\s+', ' ', substituted)
    if re.fullmatch(r'[\d\s\+\-\*\/\(\)]+', safe):
        try:
            return int(eval(safe))  # safe: only arithmetic
        except Exception:
            return None

    return None


# ---------------------------------------------------------------------------
# Line-level SV -> C transformation
# ---------------------------------------------------------------------------

def transform_value(value_str, table, name):
    """
    Transform a raw SV value string to a C expression string.
    Returns (c_expr, was_clog2) where was_clog2 is True if $clog2 was
    resolved to a literal integer (so caller can add a comment).
    Returns (None, False) if the value cannot be translated.
    """
    value_str = value_str.strip()
    # Strip inline comment from value
    value_str = re.sub(r'\s*//.*$', '', value_str).strip()

    # $clog2: prefer resolved integer from symbol table (decimal — it's a bit width)
    if '$clog2' in value_str:
        if name in table:
            return int_to_c_literal(table[name], force_decimal=True), True
        # Could not resolve — emit as comment
        return None, False

    # Pure SV hex literal
    as_int = sv_hex_to_int(value_str)
    if as_int is not None:
        return int_to_c_literal(as_int), False

    # Expression with backtick macro references: strip backticks
    expr = strip_backtick_refs(value_str)

    # Wrap in parentheses if the expression contains operators
    if re.search(r'[\+\-\*\/]', expr):
        return f"({expr})", False

    # Simple identifier or literal
    return expr, False


def convert(src_path, dst_path):
    src_name = os.path.basename(src_path)
    src_dir = os.path.dirname(os.path.abspath(src_path))

    with open(src_path, 'r') as f:
        lines = f.readlines()

    # Build symbol table (first pass, follows includes)
    table = build_symbol_table(lines, src_dir)

    out = []

    # File header
    out.append(f"/* Auto-generated from {src_name} — DO NOT EDIT */\n")
    out.append(f"/* Source: {src_path} */\n")
    out.append("#pragma once\n")

    for line in lines:
        stripped = line.strip()

        # Single-line comments: pass through verbatim
        if stripped.startswith('//'):
            out.append('//' + line[line.index('//')+2:])
            continue

        # Blank line
        if not stripped:
            out.append('\n')
            continue

        # `include "foo.svh" -> #include "foo.h"
        m = re.match(r'^`include\s+"([^"]+)"', stripped)
        if m:
            inc = m.group(1)
            inc_h = re.sub(r'\.svh$', '.h', inc)
            out.append(f'#include "{inc_h}"\n')
            continue

        # `ifndef GUARD
        m = re.match(r'^`ifndef\s+(\w+)', stripped)
        if m:
            out.append(f'#ifndef {m.group(1)}\n')
            continue

        # `define GUARD (no value — include guard)
        m = re.match(r'^`define\s+(\w+)\s*$', stripped)
        if m:
            out.append(f'#define {m.group(1)}\n')
            continue

        # `define NAME value
        m = re.match(r'^`define\s+(\w+)\s+(.+)', stripped)
        if m:
            name = m.group(1)
            raw_value = m.group(2)
            # Preserve inline comment separately
            comment_m = re.search(r'\s*(//.*)', raw_value)
            comment = comment_m.group(1) if comment_m else ''
            raw_value_no_comment = re.sub(r'\s*//.*$', '', raw_value).strip()

            c_val, was_clog2 = transform_value(raw_value_no_comment, table, name)
            if c_val is None:
                # Cannot translate — emit as a comment
                out.append(f'/* Cannot translate: `define {name} {raw_value_no_comment} */\n')
            else:
                if was_clog2:
                    out.append(f'#define {name} {c_val}  /* $clog2 */\n')
                elif comment:
                    out.append(f'#define {name} {c_val}  {comment}\n')
                else:
                    out.append(f'#define {name} {c_val}\n')
            continue

        # `endif [// comment]
        m = re.match(r'^`endif', stripped)
        if m:
            comment_m = re.search(r'(//.*)', stripped)
            if comment_m:
                out.append(f'#endif {comment_m.group(1)}\n')
            else:
                out.append('#endif\n')
            continue

        # Anything else: pass through as a comment so nothing is silently lost
        if stripped:
            out.append(f'/* (skipped) {stripped} */\n')

    with open(dst_path, 'w') as f:
        f.writelines(out)

    print(f"svh2h: {src_path} -> {dst_path}  ({len(table)} symbols resolved)")


# ---------------------------------------------------------------------------
# Linker-script-safe output mode (--ld)
# ---------------------------------------------------------------------------

def int_to_ld_literal(n):
    """Format a Python int for use in GNU ld scripts.
    No C type suffixes (UL/U) — just plain hex or decimal."""
    if n > 0xFFFF:
        return f"0x{n:X}"
    elif n > 9:
        return f"0x{n:X}"
    else:
        return str(n)


def convert_ld(src_path, dst_path):
    """
    Convert SVH to a linker-script-preprocessable C header.

    Emits a flat '#define NAME value' file with ALL resolved symbols (from
    both the top-level SVH and any included SVH files).  Values have no C
    type suffixes so the file can be safely #include-d inside a linker-script
    template that is processed by 'gcc -E -P'.

    Usage:
        python3 svh2h.py --ld <input.svh> <output.h>
    """
    src_name = os.path.basename(src_path)
    src_dir = os.path.dirname(os.path.abspath(src_path))

    with open(src_path, 'r') as f:
        lines = f.readlines()

    table = build_symbol_table(lines, src_dir)

    guard = os.path.basename(dst_path).upper().replace('.', '_').replace('-', '_')

    out = []
    out.append(f"/* Auto-generated from {src_name} — DO NOT EDIT */\n")
    out.append(f"/* Source: {src_path} */\n")
    out.append(f"/* For linker-script preprocessing only — no C type suffixes. */\n")
    out.append(f"#ifndef {guard}\n")
    out.append(f"#define {guard}\n")
    out.append("\n")

    for name, value in sorted(table.items()):
        out.append(f"#define {name} {int_to_ld_literal(value)}\n")

    out.append(f"\n#endif /* {guard} */\n")

    with open(dst_path, 'w') as f:
        f.writelines(out)

    print(f"svh2h --ld: {src_path} -> {dst_path}  ({len(table)} symbols resolved)")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == '__main__':
    if len(sys.argv) == 4 and sys.argv[1] == '--ld':
        convert_ld(sys.argv[2], sys.argv[3])
    elif len(sys.argv) == 3:
        convert(sys.argv[1], sys.argv[2])
    else:
        print(f"Usage: {sys.argv[0]} [--ld] <input.svh> <output.h>", file=sys.stderr)
        sys.exit(1)
