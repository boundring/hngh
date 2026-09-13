#!/usr/bin/env python3
"""jcode session-cost capture: ~/.jcode/logs/jcode-*.log -> telemetry.

Mirrors jobs/session-cost.py (omp transcripts) for jcode's daily log files.
Parses "API call complete" lines ([ses:SID|prv:P|mod:M] ...(input=N output=M))
and ENV_SNAPSHOT lines (working_dir -> subject). Emits kind=session-cost
source=jcode, one event per session, idempotent via captured identities.
Cost is always 0.0 (jcode logs carry no pricing); the spend signal for jcode
is tokens (context-ratio classifies glm vs unsloth by model string).

Seams: JCODE_LOG_DIR overrides the log dir; HNGH_HOME_DIR overrides the
telemetry DB root (same as jobs/telemetry.py). Best-effort: always exit 0.
"""

import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

AUTOMATION_ROOT = Path(__file__).resolve().parent.parent
TELEMETRY = AUTOMATION_ROOT / "jobs" / "telemetry.py"
LOG_DIR = Path(os.environ.get("JCODE_LOG_DIR", Path.home() / ".jcode" / "logs"))
HOME_DIR = Path(os.environ.get("HNGH_HOME_DIR", Path.home() / ".hngh"))
DB = HOME_DIR / "db" / "telemetry.db"
LIVE_GRACE_S = 600

API_RE = re.compile(
    r"^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+)\] \[\w+\] "
    r"\[ses:([^\]|]+)\|prv:[^\]|]+\|mod:([^\]]+)\] "
    r"API call complete in [\d.]+s \(input=(\d+) output=(\d+)"
)
SNAPSHOT_RE = re.compile(r"ENV_SNAPSHOT (\{.*\})")


def _ts(line_ts: str) -> float:
    return time.mktime(time.strptime(line_ts.split(".")[0], "%Y-%m-%d %H:%M:%S"))


def parse_logs(paths):
    """-> {sid: {tokens_in, tokens_out, first, last, models, working_dir}}"""
    sessions = {}
    for p in paths:
        try:
            text = p.read_text(errors="replace")
        except OSError:
            continue
        for line in text.splitlines():
            snap = SNAPSHOT_RE.search(line)
            if snap:
                try:
                    data = json.loads(snap.group(1))
                    sid = data.get("session_id")
                    if sid and sid not in sessions:
                        sessions[sid] = {"tokens_in": 0, "tokens_out": 0,
                                         "first": None, "last": None,
                                         "models": {}, "working_dir": None}
                    if sid and data.get("working_dir"):
                        sessions[sid]["working_dir"] = data["working_dir"]
                except json.JSONDecodeError:
                    pass
                continue
            m = API_RE.match(line)
            if not m:
                continue
            ts, sid, model, tin, tout = m.groups()
            s = sessions.setdefault(sid, {"tokens_in": 0, "tokens_out": 0,
                                          "first": None, "last": None,
                                          "models": {}, "working_dir": None})
            n_in, n_out = int(tin), int(tout)
            if n_in or n_out:
                s["tokens_in"] += n_in
                s["tokens_out"] += n_out
                s["models"][model] = s["models"].get(model, 0) + 1
                t = _ts(ts)
                s["first"] = t if s["first"] is None else min(s["first"], t)
                s["last"] = t if s["last"] is None else max(s["last"], t)
    return sessions


def captured_identities():
    if not DB.exists():
        return set()
    import sqlite3
    try:
        with sqlite3.connect(f"file:{DB}?mode=ro", uri=True) as con:
            return {r[0] for r in con.execute(
                "SELECT DISTINCT identity FROM events WHERE kind='session-cost' "
                "AND source='jcode'")}
    except sqlite3.Error:
        return set()


def discover_logs():
    if not LOG_DIR.is_dir():
        return [], []
    now = time.time()
    fresh, ready = [], []
    for p in sorted(LOG_DIR.glob("jcode-*.log")):
        (fresh if now - p.stat().st_mtime < LIVE_GRACE_S else ready).append(p)
    return ready, fresh


def main(argv):
    dry_run = "--dry-run" in argv
    ready, fresh = discover_logs()
    if not ready and not fresh:
        print("jcode-session-cost: no logs")
        return 0
    captured = captured_identities()
    emitted, deferred, skipped = 0, sum(1 for _ in fresh), 0
    for sid, s in sorted(parse_logs(ready).items()):
        if sid in captured:
            skipped += 1
            continue
        if not s["tokens_in"] and not s["tokens_out"]:
            continue
        model = max(s["models"], key=s["models"].get) if s["models"] else "unknown"
        subject = (os.path.basename(s["working_dir"].rstrip("/"))
                   if s["working_dir"] else f"jcode:{sid[:24]}")
        wall = max(s["last"] - s["first"], 0.0) if s["last"] else 0.0
        data = json.dumps({"tokens_in": s["tokens_in"],
                           "tokens_out": s["tokens_out"], "cost_usd": 0.0})
        if dry_run:
            print(json.dumps({"identity": sid, "subject": subject,
                              "model": model, "wall_s": round(wall, 1),
                              "data": json.loads(data)}))
        else:
            subprocess.run(
                [sys.executable, str(TELEMETRY), "emit",
                 "--kind", "session-cost", "--source", "jcode",
                 "--identity", sid, "--subject", subject, "--model", model,
                 "--wall-s", f"{wall:.1f}", "--data", data],
                capture_output=True)
        emitted += 1
    print(f"jcode-session-cost: emitted {emitted}, deferred-live {deferred}, "
          f"already-captured {skipped}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
