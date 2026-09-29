#!/usr/bin/env python3
"""parked-care — parked items automated care.

Reads the report queue's parked rows (the same read the composer's
parked digest uses) and emits one `needs` TSV row per kin group: 2+
parked rows sharing a rare [a-z0-9]{4,} token. A rare token's row-set
IS the group — no transitive closure, which on a real shelf chains
everything into one blob through bridge words. The word "parked" itself
is not a relation (park* tokens excluded); card-class kin — the
composer digest affordance — is deliberately too weak to combine debt.
The cadence wrapper files each row as a crumbs-journal breadcrumb;
operator-item events (needs) feed the operator panel and the
disposition sweep sees combined debt instead of scattered singles.
Read-only: the queue is never mutated. Fail-closed: exit 0 with no
output on every expected path (absent/broken queue, malformed rows).

Seams (dashboard-introspect.py convention): HNGH_REPORT_QUEUE /
HNGH_REPORT_ROOT.
"""
import json
import os
import re
import subprocess
import sys
from collections import Counter

AUTOMATION_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPORT_QUEUE = os.environ.get(
    "HNGH_REPORT_QUEUE",
    os.path.join(AUTOMATION_ROOT, "..", "scripts", "report-queue"))
REPORT_ROOT = os.environ.get(
    "HNGH_REPORT_ROOT", os.path.dirname(AUTOMATION_ROOT))

PARK_RE = re.compile(r"\bpark", re.I)   # matches composer :653
TOKEN_RE = re.compile(r"[a-z0-9]{4,}")  # matches composer kin tokens
# The settled park templates ("filed as backlog debt; revisit at the
# next disposition sweep" / "expired as stale" / "suppressed as
# duplicate identity" / "acknowledged: <note>") are boilerplate, not
# relations: without this stop set every default-parked row would
# cluster with every other through "debt"/"revisit"/"sweep".
STOP = {"filed", "backlog", "debt", "revisit", "next", "disposition",
        "sweep", "stale", "expired", "suppressed", "duplicate",
        "identity", "acknowledged", "guidance", "note", "operator",
        "card",
        # function words are grammar, never a debt subject
        "into", "then", "until", "without", "across", "been", "were",
        "have", "that", "this", "from", "will", "when", "they", "them",
        "than", "only", "also", "some", "such", "each", "same", "still",
        "again", "both", "with"}
# Quoted pointers inside why texts — report ids ("...Z_01a0af81-...",
# hex tails like "2070c5"), ISO fragments ("...T13-14-39Z" -> "17t13",
# "298z") — chain unrelated rows transitively. Digits mark a pointer
# (id, hash, moment in time), never a keyword: kin is shared rare
# words, so any digit-bearing token is out.
DIGIT_RE = re.compile(r"\d")
WHY_PREVIEW = 80
TOKEN_PREVIEW = 4
KIN_DF_MAX = 8  # a token parked on more rows than this is vocabulary,
                # not kin: kin lives in the rarity band df 2..8
GROUPS_CAP = 8  # PARKED_CAP parity: the top groups per run, no spam


def parked_rows():
    """report-queue --json -> parked entries {id, ts, why}, newest
    first. why is whitespace-collapsed and ASCII-scrubbed (one line,
    print-safe). Fail-open: broken queue -> []."""
    try:
        p = subprocess.run(
            [REPORT_QUEUE, "--json"],
            capture_output=True, timeout=30, cwd=REPORT_ROOT)
        data = json.loads(p.stdout.decode("utf-8", "replace"))
        rows = data.get("reports") if isinstance(data, dict) else None
    except (OSError, subprocess.SubprocessError, ValueError):
        return []
    out = []
    for row in rows or []:
        if not isinstance(row, dict):
            continue
        first = " ".join((row.get("first") or "").split())
        if not PARK_RE.search(first):
            continue
        out.append({"id": str(row.get("id") or ""),
                    "ts": str(row.get("ts") or ""),
                    "why": "".join(c if ord(c) < 128 else "-"
                                   for c in first)})
    out.sort(key=lambda e: (e["ts"], e["id"]), reverse=True)
    return out


def token_groups(entries):
    """Rare shared tokens -> kin groups. Returns [(ids sorted, tokens
    sorted), ...] for groups of 2..KIN_DF_MAX rows; groups with
    identical member sets merge their tokens. Top GROUPS_CAP by size."""
    toks = {e["id"]: {t for t in TOKEN_RE.findall(e["why"].lower())
                      if not t.startswith("park") and t not in STOP
                      and not DIGIT_RE.search(t)}
            for e in entries}
    counts = Counter()
    for e in entries:
        counts.update(toks[e["id"]])
    common = {t for t, c in counts.items() if c > KIN_DF_MAX}
    bytoken = {}
    for e in entries:
        for t in toks[e["id"]]:
            if t not in common:
                bytoken.setdefault(t, []).append(e["id"])
    merged = {}
    for t, ids in bytoken.items():
        ids = sorted(set(ids))   # ledger resurrections repeat an id
        if not (2 <= len(ids) <= KIN_DF_MAX):
            continue
        merged.setdefault(tuple(ids), []).append(t)
    out = [(list(ids), sorted(hs)) for ids, hs in merged.items()]
    out.sort(key=lambda g: (-len(g[0]), g[0]))
    return out[:GROUPS_CAP]


def main():
    try:
        entries = parked_rows()
    except (KeyError, TypeError, ValueError):
        return 0
    byid = {e["id"]: e for e in entries}
    for ids, hot in token_groups(entries):
        whys = " -- ".join(byid[eid]["why"][:WHY_PREVIEW] for eid in ids)
        print("needs\tparked-kin %s: %s -- %s" % (
            ",".join(hot[:TOKEN_PREVIEW]) or "?",
            "+".join(ids), whys))
    return 0


if __name__ == "__main__":
    sys.exit(main())
