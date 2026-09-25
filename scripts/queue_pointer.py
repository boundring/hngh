#!/usr/bin/env python3
"""queue_pointer — the one clock for the queue ## Next pointer.

P3 of the refoundation plan: rotation becomes a watcher, not operator
memory. Every picker (run-autonomous, schedule-heartbeat, omp-bridge)
calls ensure_current() before reading the pointer; an expired pointer
is demoted to a cause line, the next queued row is advanced with a
fresh set= stamp, and the stall is reported (crumb + report row).

Pointer shape in docs/project/queue.md ## Next:

    - **<id>** — next queued set=YYYY-MM-DD ttl=<days> (prose...)

set= absent or unparsable: no demotion (a pointer that was never
stamped cannot age; fresh hand-edits without tokens are left alone).
ttl absent: default 7 days.
"""

import os
import re
import subprocess
import sys
import tempfile
from datetime import date, datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
QUEUE = ROOT / "docs" / "project" / "queue.md"
DEFAULT_TTL_DAYS = 7

NEXT_RE = re.compile(r"## Next\s*\n(?P<body>(?:(?!## ).*\n?)*)")
SET_RE = re.compile(r"set=(\d{4}-\d{2}-\d{2})")
TTL_RE = re.compile(r"ttl=(\d+)")


def pointer(text):
    """Parse the ## Next block: (id, set_date, ttl_days) or (None, ...)."""
    m = NEXT_RE.search(text)
    if not m:
        return None, None, DEFAULT_TTL_DAYS
    for line in m.group("body").splitlines():
        bold = re.match(r"- \*\*(?P<id>[^*\n]+)\*\*(?P<rest>.*)", line)
        if not bold:
            continue
        s = SET_RE.search(bold.group("rest"))
        t = TTL_RE.search(bold.group("rest"))
        set_date = date.fromisoformat(s.group(1)) if s else None
        ttl = int(t.group(1)) if t else DEFAULT_TTL_DAYS
        return bold.group("id").strip(), set_date, ttl
    return None, None, DEFAULT_TTL_DAYS


def age_days(set_date, today=None):
    today = today or datetime.now(timezone.utc).date()
    return (today - set_date).days


def _atomic_write(path, text):
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix=".queue-ptr.")
    try:
        with os.fdopen(fd, "w") as fh:
            fh.write(text)
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def _next_queued_id(text):
    for line in text.splitlines():
        parts = line.split("\t")
        if len(parts) == 4 and parts[1] == "queued":
            return parts[0].strip()
    return None


def demote_and_advance(text, today=None):
    """Rewrite queue.md text on stall. Returns (new_text, old_id, new_id, age) or None."""
    old_id, set_date, ttl = pointer(text)
    if not old_id or set_date is None:
        return None
    age = age_days(set_date, today)
    if age <= ttl:
        return None
    today = today or datetime.now(timezone.utc).date()
    m = NEXT_RE.search(text)
    block = m.group("body")
    # drop the stale pointer bullet (first bold bullet), keep the rest
    kept, dropped = [], False
    in_bullet = False
    for line in block.splitlines(keepends=True):
        if not dropped and re.match(r"- \*\*", line):
            dropped = True
            in_bullet = True
            continue
        if in_bullet:
            if line.startswith("  ") or not line.strip():
                if line.strip():
                    continue
                in_bullet = False
                continue
            in_bullet = False
        kept.append(line)
    rest = "".join(kept)
    new_id = _next_queued_id(text)
    stamp = today.isoformat()
    if new_id:
        fresh = (f"- **{new_id}** — next queued set={stamp} ttl={ttl} "
                 f"(advanced from {old_id}: cause=ttl-expired)\n")
        cause = (f"- {old_id} — re-queued {stamp} with cause: ttl-expired "
                 f"(set {set_date.isoformat()}, {age} days)\n")
        new_block = fresh + cause + rest
    else:
        cause = (f"- {old_id} — re-queued {stamp} with cause: ttl-expired "
                 f"(set {set_date.isoformat()}, {age} days); queue empty past it\n")
        new_block = cause + rest
    new_text = text[:m.start("body")] + new_block + text[m.end("body"):]
    return new_text, old_id, new_id, age


def notify(old_id, age, automation_root=None):
    """Crumb + one report row (identity queue-next:<id>, window 7d). Fail-open:
    a reporting fault must not block the rotation itself."""
    detail = f"{old_id} set-stale age={age}d"
    try:
        auto = automation_root or os.environ.get("HNGH_AUTOMATION_ROOT") or str(ROOT / "automation")
        subprocess.run(
            [sys.executable, str(Path(auto) / "lib" / "crumbs.py"),
             "queue", "next-stalled", detail],
            capture_output=True, timeout=15, check=False)
        subprocess.run(
            [str(ROOT / "scripts" / "report-queue"), "--add", "alert",
             "--identity", f"queue-next:{old_id}", "--window", "604800",
             f"queue pointer stalled: {old_id} ({age} days past set=, ttl expired); "
             f"re-queued with cause=ttl-expired, advanced to next queued row"],
            capture_output=True, timeout=15, check=False)
    except Exception:
        pass


def ensure_current(queue_path=None, today=None):
    """Demote a stalled pointer in place. Returns (old_id, new_id, age) or None."""
    path = queue_path or QUEUE
    text = path.read_text()
    result = demote_and_advance(text, today)
    if result is None:
        return None
    new_text, old_id, new_id, age = result
    _atomic_write(path, new_text)
    notify(old_id, age)
    return old_id, new_id, age


if __name__ == "__main__":
    # queue-pointer check CLI: exit 0 current, 3 stalled (and fixed), 2 unparsable
    res = ensure_current()
    if res is None:
        pid, set_date, _ = pointer(QUEUE.read_text())
        sys.exit(0 if pid else 2)
    print(f"demoted {res[0]} (age {res[2]}d), advanced to {res[1]}")
    sys.exit(3)
