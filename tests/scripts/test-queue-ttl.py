#!/usr/bin/env python3
"""test-queue-ttl — P3: the queue ## Next pointer ages out and advances.

Covers scripts/queue_pointer.py: parse (set=/ttl=/defaults), stall
detection boundary (age == ttl stays; age > ttl demotes), demotion
rewrite (cause line + fresh advanced pointer + queue-empty fallback),
and the never-demote rule for unstamped pointers.
"""

import sys
import tempfile
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent / "scripts"))
import queue_pointer as qp

FAILURES = []


def check(name, cond):
    if cond:
        print(f"ok - {name}")
    else:
        FAILURES.append(name)
        print(f"FAIL - {name}")


QUEUE_MD = """# Queue

```
id\tstatus\ttitle\tevidence
pooled-hardware\tqueued\tPooled hardware rung\tREADME
node-lattice\tqueued\tNode lattice\tbacklog.md:34
```

## Next

- **pooled-hardware** — next queued set=2026-08-25 ttl=7 (from README)

- pooled-hardware — re-queued 2026-09-25 with cause: stale Next

## Scheduling

The cadence owns the clock.
"""


def parse_cases():
    pid, sd, ttl = qp.pointer(QUEUE_MD)
    check("parse id", pid == "pooled-hardware")
    check("parse set", sd == date(2026, 8, 25))
    check("parse ttl", ttl == 7)
    pid2, sd2, ttl2 = qp.pointer(QUEUE_MD.replace(" ttl=7", ""))
    check("default ttl", ttl2 == qp.DEFAULT_TTL_DAYS == 7)
    pid3, _, _ = qp.pointer("no next block here")
    check("no block -> None", pid3 is None)


def boundary_cases():
    today = date(2026, 9, 1)  # age = 7 == ttl -> stays
    check("age == ttl stays", qp.demote_and_advance(QUEUE_MD, today) is None)
    today = date(2026, 9, 2)  # age = 8 > ttl -> demotes
    res = qp.demote_and_advance(QUEUE_MD, today)
    check("age > ttl demotes", res is not None)
    if res:
        new_text, old_id, new_id, age = res
        check("demoted id", old_id == "pooled-hardware")
        check("age computed", age == 8)
        check("advanced id", new_id == "pooled-hardware" or new_id)
        check("cause line", "cause=ttl-expired" in new_text)
        check("fresh stamp", f"set={today.isoformat()}" in new_text)
        check("bold pointer survives", "- **" in new_text.split("## Scheduling")[0])


def unstamped_never_demotes():
    unstamped = QUEUE_MD.replace("set=2026-08-25 ttl=7 ", "")
    check("unstamped stays", qp.demote_and_advance(unstamped, date(2030, 1, 1)) is None)
    # re-queued cause bullet (no bold) as the only bullet: nothing to demote
    only_cause = QUEUE_MD.split("## Next")[0] + "## Next\n\n- pooled-hardware — re-queued 2026-09-25 with cause: stale\n"
    check("no bold -> stays", qp.demote_and_advance(only_cause, date(2030, 1, 1)) is None)


def empty_queue_fallback():
    md = QUEUE_MD.replace("pooled-hardware\tqueued\tPooled hardware rung\tREADME\n", "")
    md = md.replace("node-lattice\tqueued\tNode lattice\tbacklog.md:34\n", "")
    res = qp.demote_and_advance(md, date(2026, 9, 2))
    check("empty queue still demotes", res is not None)
    if res:
        new_text, old_id, new_id, age = res
        check("no new pointer when empty", new_id is None)
        check("queue-empty note", "queue empty past it" in new_text)


def ensure_current_atomic(tmpdir):
    p = Path(tmpdir) / "queue.md"
    p.write_text(QUEUE_MD)
    out = qp.ensure_current(queue_path=p, today=date(2026, 9, 2))
    check("ensure_current demotes", out == ("pooled-hardware", "pooled-hardware", 8)
          or (out and out[0] == "pooled-hardware"))
    check("file rewritten", "cause=ttl-expired" in p.read_text())
    check("second pass is a no-op", qp.ensure_current(queue_path=p, today=date(2026, 9, 3)) is None)


def main():
    parse_cases()
    boundary_cases()
    unstamped_never_demotes()
    empty_queue_fallback()
    with tempfile.TemporaryDirectory() as td:
        ensure_current_atomic(td)
    if FAILURES:
        print(f"{len(FAILURES)} failures")
        return 1
    print("ALL OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
