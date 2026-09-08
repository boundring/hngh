#!/usr/bin/env python3
"""Slow-unit rows from the time ledger (oversight-tick probe_time_ledger).

Flags units whose last wall exceeds max(2x trailing p50, 10s floor) —
unless the wall is inside the unit's design ENVELOPE: units whose runs
are timeout-capped upstream are bimodal BY DESIGN (quick skip-exit ~0.2s
/ bounded beat ~150-240s / session up to the cap), so the median rule
alone fired on every legitimate mode transition (44 false slow-unit
rows 2026-08-27..2026-09-01, routed as plan candidate
2026-09-01-routed-slow-unit-dropin-20-workbeat.sh). Inside the envelope
a wall is never slow; over it, BOTH rules flag (genuine anomaly:
something ran past the upstream cap).

Fail-closed: missing/unparsable ledger -> no rows, exit 1 (caller
skips the probe silently). argv[1] = path to time-ledger.json.
"""
import json
import sys

# cap = scripts/overnight-cycle.sh TIMEOUT_S (default 1800), the hard
# `timeout $TIMEOUT_S` on the delegated session; +60s margin = timeout
# kill-after (5s) + post-session audit tail (observed <1s). Both keys
# run the same overnight-cycle.sh (hourly drop-in, systemd ExecStart).
ENVELOPE = {
    "dropin:20-workbeat.sh": 1800.0 + 60.0,
    "hngh-overnight.service": 1800.0 + 60.0,
}


def flagged_rows(ledger_path):
    with open(ledger_path, encoding="utf-8") as f:
        units = json.load(f).get("units", [])
    rows = []
    for u in units:
        w, p = u.get("last_wall_s"), u.get("p50_s")
        if isinstance(w, (int, float)) and isinstance(p, (int, float)) \
                and w > max(2 * p, 10.0) \
                and w > ENVELOPE.get(u.get("unit"), 0.0):
            rows.append("%s wall=%.1fs median=%.1fs" % (u.get("unit", "?"), w, p))
    return rows


def main():
    try:
        rows = flagged_rows(sys.argv[1])
    except Exception:
        sys.exit(1)
    for row in rows:
        print(row)


if __name__ == "__main__":
    main()
