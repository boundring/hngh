#!/usr/bin/env python3
"""lint-parens.py — Detect and auto-fix unbalanced parentheses in Common Lisp.

Purpose
-------
Large or rushed Lisp edits frequently end with unmatched '(' or ')' — the
reader then reports a vague "READ error" / "end of file" deep in the file, and
the rest of the file is mis-nested. This catches it procedurally before a test
run, prints the offending lines, and (optionally) appends the needed ')' to
unclosed top-level forms.

Approach
--------
A single char-level pass with correct handling of:
  - string literals ("..." with \\ escapes)
  - line comments (';' to EOL)
  - character literals (#\\<char> and #\\<name> like #\\Space, #\\N, #\\\\(
  - everything else: '(' +1, ')' -1; '['/']' and '{'/'}' counted too
So punctuation inside strings, comments, and char literals does not count.

It does NOT parse Lisp or understand reader macros — it is a guard, not a
compiler. Known limitation: reader-macro forms that are self-balancing (e.g.
`#(...)` vectors) are counted as open+close normally (the '#' is ignored), so
they work out. Dispatch/loop constructs with unusual char counts may produce a
false positive; if that happens, prefer the compiler's error over this guard.

Usage
-----
  scripts/lint-parens.py path.lisp [...]     report only; exit 1 if unbalanced
  scripts/lint-parens.py --fix path.lisp     append ')' to unclosed forms
                                              (depth>0 at EOF); exit 0 when fixed

Exit codes: 0 ok / balanced; 1 unbalanced or unfixable.

SPDX-License-Identifier: AGPL-3.0-or-later
SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>
"""

import sys

OPEN = set("([{")
CLOSE = set(")]}")
ALNUM = set(
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+-*/_=<>!?"
)


def scan_lines(lines):
    """Return per-line running depth, handling Lisp syntax across lines.

    This is a SINGLE full-text pass (string state carries across line
    boundaries) so a multi-line docstring's bracketed prose is not counted
    as real parens. Returns a list of (line_no, depth_at_end_of_line).

    Syntax handled:
      - string literals ("..." with \\ escapes), spanning lines
      - line comments (';' to EOL)
      - character literals (#\\<char> / #\\<name> like #\\Space, #\\( )
      - everything else counted raw: '(' +1, ')' -1 (and [] {} likewise)
    """
    depth = 0
    trace = []
    line = 1
    i = 0
    text = "\n".join(lines)
    n = len(text)
    while i < n:
        c = text[i]
        if c == "\n":
            trace.append((line, depth))
            line += 1
            i += 1
            continue
        if c == '"':
            i += 1
            while i < n:
                if text[i] == "\\":
                    i += 2
                    continue
                if text[i] == "\n":
                    trace.append((line, depth))
                    line += 1
                    i += 1
                    continue
                if text[i] == '"':
                    i += 1
                    break
                i += 1
            continue
        if c == ";":
            while i < n and text[i] != "\n":
                i += 1
            continue
        if c == "#" and i + 1 < n and text[i + 1] == "\\":
            # character literal: #\X or #\Name
            i += 2  # past '#\'
            if i < n and text[i] in ALNUM:
                while i < n and text[i] in ALNUM:
                    i += 1
            else:
                i += 1  # single non-alnum char literal, e.g. #\(
            continue
        if c in OPEN:
            depth += 1
        elif c in CLOSE:
            depth -= 1
        i += 1
    # final line (no trailing newline)
    if not trace or trace[-1][0] != line or depth != trace[-1][1]:
        trace.append((line, depth))
    return trace


def analyze(path):
    """Return (ok, problems)."""
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        text = f.read()
    lines = text.split("\n")
    trace = scan_lines(lines)
    final_depth = trace[-1][1] if trace else 0
    min_depth = min((d for _, d in trace), default=0)
    problems = []
    if min_depth < 0:
        first_neg = next((ln for ln, d in trace if d < 0), None)
        problems.append(
            f"stray ')' — depth went negative at line {first_neg} "
            "(the reader will pinpoint the exact close)"
        )
    if final_depth > 0:
        first_open = next((ln for ln, d in trace if d > 0), None)
        problems.append(
            f"unclosed form: depth {final_depth} at EOF, opened near line "
            f"{first_open}"
        )
    return (not problems), problems, text


def check(path, fix=False):
    ok, problems, text = analyze(path)
    if ok:
        print(f"[OK] {path}")
        return True
    for p in problems:
        print(f"[{path}] {p}")
    # Auto-fix path: only safe when purely UNCLOSED (final_depth>0 and never
    # went negative). Append the needed ')' at EOF. Stray-close is ambiguous —
    # we never delete a paren blindly, so it stays a report.
    if fix:
        if all("stray" not in p for p in problems):
            final_depth = trace_depth(text)
            if final_depth and final_depth > 0:
                fixed = text.rstrip("\n") + ")" * final_depth + "\n"
                with open(path, "w", encoding="utf-8") as f:
                    f.write(fixed)
                print(f"[FIXED] {path}: appended {final_depth} ')'")
                return True
    return False


def trace_depth(text):
    r = scan_lines(text.split("\n"))
    return r[-1][1] if r else 0


def main(argv):
    if not argv:
        print(__doc__)
        return 2
    fix = False
    paths = []
    for a in argv:
        if a == "--fix":
            fix = True
        else:
            paths.append(a)
    ok = True
    for p in paths:
        if not check(p, fix=fix):
            ok = False
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
