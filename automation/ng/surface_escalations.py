"""Surface cadence beat escalations to the operator ledger.

Reads the beat's event JSON on stdin and files each escalation.filed as a
report-queue alert row: identity escalation:<bead>:<reason>, 7-day window
(row expires on silence; re-fires bump the same row). The halt condition
is NOT here — it is the per-bead attempt cap in ng/cadence.py
(STATE.exhausted): a bead leaves the loop after one final
attempts-exhausted escalation, so this lane never piles rows on one neck.

Fail closed: malformed input or a missing queue path exits 0 without
filing anything (the beat's own escalation records stay in the ng ledger).
"""
import json
import subprocess
import sys


def main() -> None:
    try:
        events = json.load(sys.stdin)
    except Exception:
        return
    if not isinstance(events, list):
        return
    queue = sys.argv[1] if len(sys.argv) > 1 else "scripts/report-queue"
    for e in events:
        if not isinstance(e, dict) or e.get("kind") != "escalation.filed":
            continue
        p = e.get("payload", {})
        bead = p.get("bead") or "beat"
        reason = p.get("reason", "unknown")
        subprocess.run(
            ["python3", queue, "--add", "alert",
             "escalation %s: %s" % (bead, reason),
             "--identity", "escalation:%s:%s" % (bead, reason),
             "--window", "604800"],
            check=False)


if __name__ == "__main__":
    main()
