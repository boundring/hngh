#!/usr/bin/env python3
"""vault-freshness — flag vault credentials not rotated within the OLA.

The 1Password vault 'Hngh Secrets' is the freshness ledger: when the
operator rotates a key at the provider, they update the vault item, and
`updated_at` bumps. This job reads `op item list` (titles + timestamps
only — never values) and prints one finding per stale item:

    stale: <title> age=<N>d (OLA=<N>d)

Fail-closed per repo rules: any op error prints `error: ...` and exits 0
(the caller's alert seam turns findings into report rows; an op outage
must not silently pass).
"""
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime, timezone


def _parse_ts(ts: str) -> float:
    # op timestamps like 2026-09-21T19:22:22.77170705-04:00 (9-digit frac)
    m = re.match(r"(.*\.\d{1,6})\d*(Z|[+-]\d{2}:?\d{2})$", ts)
    if m:
        ts = m.group(1) + ("+00:00" if m.group(2) == "Z" else m.group(2))
    return datetime.fromisoformat(ts).astimezone(timezone.utc).timestamp()


def findings(ola_days: int, vault: str = "Hngh Secrets") -> list:
    env = dict(os.environ)
    r = subprocess.run(
        ["op", "item", "list", "--vault", vault, "--format", "json"],
        capture_output=True, text=True, timeout=120, env=env,
    )
    if r.returncode != 0:
        return [f"error: op item list failed rc={r.returncode}"]
    try:
        items = json.loads(r.stdout)
    except ValueError:
        return ["error: op item list returned non-JSON"]
    now = time.time()
    out = []
    for it in items:
        title = it.get("title", "?")
        try:
            age = (now - _parse_ts(it["updated_at"])) / 86400
        except (KeyError, ValueError):
            out.append(f"error: item '{title}' has no parsable updated_at")
            continue
        if age > ola_days:
            out.append(f"stale: {title} age={int(age)}d (OLA={ola_days}d)")
    return out


if __name__ == "__main__":
    ola = int(sys.argv[1]) if len(sys.argv) > 1 else 180
    for line in findings(ola):
        print(line)
    # self-check: exercise the parser on a known timestamp
    assert _parse_ts("2026-09-21T19:22:22.77170705-04:00") > 0
