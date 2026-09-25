#!/usr/bin/env python3
"""filing_budget - the shared one-filing-per-cause-per-day counter plus
the filing-about-filing demotion check (refoundation P7b).

One append-only counter file: automation/state/filing-budget.tsv, rows

    <family>:<cause-token>\t<UTC-date YYYY-MM-DD>

flock-locked on append (last row per key wins). allow() consumes the
day's single filing for a family:cause key: True the first time on a
UTC day, False on every later same-day call. Families: fail | patrol |
synth | followon | routed. The cause token is the normalized slug
(lowercase; every run of non-[a-z0-9] -> single '-'; trimmed) already
used at each mint seam (P6's norm-slug).

Filing-about-filing: a subject/question whose text equals, or is
contained in, an existing disposition verdict (research-dispositions.tsv
column 3) is the machine filing about its own filings - always a crumb,
never a row (--check-disposition, exit 1 = demote).

Shell seam (fail-open: any python/OS fault = allowed / not-demoted):
    python3 lib/filing_budget.py --family <f> --cause <token>   # rc0 allowed, rc1 over
    python3 lib/filing_budget.py --check-disposition --text <t> # rc1 = demote
Seams: HNGH_FILING_STATE (state dir), HNGH_DISPOSITIONS_TSV.
"""
import argparse
import fcntl
import os
import re
import sys
from datetime import datetime, timezone

AUTO_ROOT = (os.environ.get("HNGH_AUTOMATION_ROOT")
             or os.environ.get("AUTOMATION_ROOT")
             or os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def norm_slug(text):
    """Normalized cause token (P6 definition, mirrors lib/causes.sh)."""
    return re.sub(r"[^a-z0-9]+", "-", (text or "").lower()).strip("-")


def state_path(state_dir=None):
    d = state_dir or os.environ.get("HNGH_FILING_STATE") or \
        os.path.join(AUTO_ROOT, "state")
    return os.path.join(d, "filing-budget.tsv")


def dispositions_path():
    return os.environ.get("HNGH_DISPOSITIONS_TSV") or \
        os.path.join(AUTO_ROOT, "research-dispositions.tsv")


def allow(family, cause, state_dir=None, today=None):
    """One filing per family:cause per UTC day. True (and appends
    today's row) when allowed; False when the key already filed today."""
    token = norm_slug(cause)
    if not family or not token:
        return True  # nothing nameable: nothing to budget
    day = today or datetime.now(timezone.utc).strftime("%Y-%m-%d")
    key = "%s:%s" % (family, token)
    path = state_path(state_dir)
    last = None
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            for ln in fh:
                parts = ln.rstrip("\n").split("\t")
                if len(parts) == 2 and parts[0] == key and parts[1]:
                    last = parts[1]
    except OSError:
        last = None
    if last == day:
        return False
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "a", encoding="utf-8") as fh:
        fcntl.flock(fh.fileno(), fcntl.LOCK_EX)
        fh.write("%s\t%s\n" % (key, day))
        fh.flush()
        fcntl.flock(fh.fileno(), fcntl.LOCK_UN)
    return True


def is_disposition_text(text, disp_path=None):
    """True when TEXT equals, or is contained in, any disposition
    verdict (column 3 of research-dispositions.tsv)."""
    text = (text or "").strip().lower()
    if not text:
        return False
    try:
        with open(disp_path or dispositions_path(), encoding="utf-8",
                  errors="replace") as fh:
            for i, ln in enumerate(fh):
                if i == 0 and ln.startswith("line\t"):
                    continue  # header
                parts = ln.rstrip("\n").split("\t")
                if len(parts) > 2 and text in parts[2].lower():
                    return True
    except OSError:
        return False
    return False


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--family")
    ap.add_argument("--cause")
    ap.add_argument("--check-disposition", action="store_true")
    ap.add_argument("--text")
    ap.add_argument("--state-dir")
    ap.add_argument("--today")
    args = ap.parse_args()
    try:
        if args.check_disposition:
            return 1 if is_disposition_text(args.text) else 0
        if args.family:
            return 0 if allow(args.family, args.cause, args.state_dir,
                              args.today) else 1
    except Exception:
        return 0  # fail-open: a budget fault never blocks a mint seam
    return 2


if __name__ == "__main__":
    sys.exit(main())
