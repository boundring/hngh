#!/usr/bin/env python3
"""Doc-numbers guard: the README's check count must match the suite.

The README states "make test runs 8 reader-guard checks plus a suite
past N checks". N kept drifting by hand (2026-08-25 corrected it three
times). This guard recomputes the count from the actual suite and
fails the gate when the README does not name it, so the drift is caught
by make test instead of by a human. It only verifies — it never
rewrites the docs.
"""

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
README = ROOT / "README.md"


def suite_count():
    out = subprocess.run(
        ["sbcl", "--script", str(ROOT / "tests" / "run.lisp")],
        capture_output=True, text=True, cwd=ROOT,
    )
    match = re.search(r"(\d+) checks passed\.", out.stdout)
    if out.returncode != 0 or not match:
        print(f"doc-numbers guard: suite did not report a count "
              f"(exit {out.returncode})")
        return None
    return int(match.group(1))


def main():
    count = suite_count()
    if count is None:
        return 1
    text = README.read_text()
    expected = f"past {count:,} checks"
    if expected not in text:
        print(f"doc-numbers guard: README does not say '{expected}' "
              f"(actual suite count is {count}); docs drifted")
        return 1
    print(f"doc-numbers guard: README matches the live suite ({expected})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
