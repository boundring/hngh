#!/usr/bin/env python3
"""scrub-pii.py — find and strip owner identifiers from a git-tracked tree.

Purpose
-------
A public-release guard: owner-identifying strings (home path, username,
hostname) leak into tracked docs when sessions/journals are written
carelessly. This finds the leaks and (optionally) applies a safe rewrite
(`/home/<user>/...` -> `~/...`), so the scrub is a procedural, repeatable
step instead of a search every session.

Scope
-----
Only TRACKED files (`git ls-files`) are checked — untracked build artifacts
and gitignored dirs (`.omo/`, `.fasl`, `bin/*`) don't ship and aren't leaks.
Fixtures are NOT touched: security-grep patterns and unit-test strings that
are *designed* to match are left alone unless the owner identifier itself
appears (a fixture saying `"sk-or-"` is fine; a fixture containing
`/home/<user>` is not). The default `--fix` rewrite is contextual to the
string: an owner home path becomes `~/...`; a bare owner username becomes
`<user>` only in obvious contexts.

Usage
-----
  scripts/scrub-pii.py [--user bricker] [--path /home/bricker]
      report-only; exit 1 if any tracked file contains the identifier

  scripts/scrub-pii.py --check
      same as report-only, but exit 0 even with hits (CI non-blocking)

  scripts/scrub-pii.py --fix [--user bricker] [--path /home/bricker]
      rewrite each hit: owner home path -> '~/', owner username alone -> '<user>'

Exit codes
----------
  0 — no hits (or --check with hits)
  1 — hits found (report/fix mode) or arg error

SPDX-License-Identifier: AGPL-3.0-or-later
SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>
"""

import argparse
import os
import re
import subprocess
import sys


def tracked_files():
    """Return the set of git-tracked files (relative paths)."""
    out = subprocess.run(
        ["git", "ls-files", "-z"], capture_output=True, text=True
    ).stdout
    return [p for p in out.split("\0") if p]


def run(args, paths):
    """Scrub PATHs for OWNER identifiers. Returns (hit_count, fixed_count)."""
    user = args.user or os.path.basename(os.path.expanduser("~"))
    home = args.path or os.path.expanduser("~")
    home = home.rstrip("/")
    hits = 0
    fixed = 0
    for rel in paths:
        try:
            with open(rel, "r", encoding="utf-8", errors="replace") as f:
                text = f.read()
        except OSError:
            continue
        found = False
        new_text = text
        # 1. owner home path -> '~/'
        #    matches /home/<user>/... (and bare /home/<user>) anywhere
        pat = re.compile(re.escape(home) + r"(/|(?=\s|[,;)\]>`]))")
        if pat.search(new_text):
            found = True
            if args.fix:
                # keep the separator: /home/user/x -> ~/x
                new_text = pat.sub(lambda mt: "~" + (mt.group(1) or ""), new_text)
        # 2. bare owner username -> '<user>' in prose contexts (only when the
        #    path form is absent to avoid rewriting inside the now-'~' paths)
        if (f"/{user}" not in new_text and
                re.search(r"(?<![\w./])" + re.escape(user) + r"(?![\w.-])", new_text)):
            found = True
            if args.fix:
                new_text = re.sub(
                    r"(?<![\w./])" + re.escape(user) + r"(?![\w.-])",
                    "<user>",
                    new_text,
                )
        if found:
            hits += 1
            if args.fix and new_text != text:
                with open(rel, "w", encoding="utf-8") as f:
                    f.write(new_text)
                fixed += 1
                print(f"[FIXED] {rel}")
            else:
                print(f"[HIT]   {rel}")
    return hits, fixed


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--user", help="owner username (default: current user)")
    ap.add_argument("--path", help="owner home path (default: $HOME)")
    ap.add_argument("--fix", action="store_true", help="apply ~/ rewrite")
    ap.add_argument("--check", action="store_true",
                    help="report but never fail CI")
    ns = ap.parse_args(argv)
    files = tracked_files()
    if not files:
        print("not a git repo")
        return 2
    hits, fixed = run(ns, files)
    if hits:
        print(f"{hits} tracked file(s) contain the owner identifier"
              + (f"; {fixed} fixed" if fixed else "; nothing fixed"))
        return 0 if ns.check else 1
    print("clean")
    return 0


if __name__ == "__main__":
    sys.exit(main())