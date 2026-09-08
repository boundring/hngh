#!/usr/bin/env bash
# time-ledger — one measurement tick for the self-optimization time ledger
# (backlog.md "Time ledger & delay flagging"). Single tick, no daemon.
#
# Wall-time source (the ONE source, deliberately): systemd's per-run
# journal resource line `...: Consumed Ns CPU time over M wall clock time,
# ...` (`journalctl --user -u <unit>`), emitted exactly once per completed
# run with the measured wall directly — no start/stop pairing (systemd
# suppresses repeated identical "Starting" messages, verified 2026-08-27:
# 15 Finished vs 1 Starting for hngh-cadence-5m in 24h) and no 24h-history
# loss (ExecMain*Monotonic properties cover only the most recent run).
# Runs below systemd's accounting threshold emit no line and are omitted
# (their walls are far under the 10s delay floor; failures emit no line
# and are other probes' domain).
#
# Writes dashboard/time-ledger.json:
#   { generated_at, units: [{unit, last_wall_s, runs_24h, p50_s, max_s}],
#     ceremonies: [{step, ms, ts}] }
# Rolling: 24h journal window, ceremonies capped at 200 (latest kept).
# Ceremony steps: hngh ceremony-drive `[ceremony-timing] <step> <N> ms`
# lines from the hngh-autonomy.service journal (24h window).
# Fail-closed: any expected condition (journalctl down, no runs, no
# ceremony lines) still exits 0 and keeps the prior ledger on disk.
set -u
. "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

LEDGER="$AUTOMATION_ROOT/dashboard/time-ledger.json"
WINDOW_H="${TIME_LEDGER_WINDOW_H:-24}"
MAX_CEREMONIES="${TIME_LEDGER_MAX_CEREMONIES:-200}"

if ! python3 - "$AUTOMATION_ROOT" "$WINDOW_H" "$MAX_CEREMONIES" >"$LEDGER.$$.tmp" <<'PYEOF'; then
import json, subprocess, sys
import re
import glob
import calendar
import os
import time
from datetime import datetime

root, window_h, max_cer = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])

def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True, timeout=60).stdout

# hngh timer units -> the services they activate (last column of list-timers)
units = []
for line in run(["systemctl", "--user", "list-timers", "--all", "--no-pager"]).splitlines():
    tok = line.split()
    if tok and tok[-1].endswith(".service") and "hngh" in tok[-1] and tok[-1] not in units:
        units.append(tok[-1])

since = f"-{window_h}h"
rows = []
for svc in sorted(units):
    walls = []
    conv = {"us": 1e-6, "µs": 1e-6, "ms": 1e-3, "s": 1.0, "min": 60.0, "h": 3600.0, "d": 86400.0}
    for line in run(["journalctl", "--user", "-u", svc, "--since", since,
                     "--no-pager"]).splitlines():
        # 2026-08-27T10:20:04 brickertop systemd[871]: hngh-cadence-5m.service:
        # Consumed 1.931s CPU time over 3.191s wall clock time, 98.8M memory peak.
        i = line.find(" over ")
        j = line.find(" wall clock time", i)
        if i < 0 or j < 0:
            continue
        try:
            span = line[i + 6:j]
            w = 0.0
            for n, u in re.findall(r"(\d+(?:\.\d+)?)\s*(us|µs|ms|s|min|h|d)\b", span):
                w += float(n) * conv[u]
        except Exception:
            continue
        walls.append(w)
    if walls:
        s = sorted(walls)
        n = len(s)
        p50 = s[n // 2] if n % 2 else (s[n // 2 - 1] + s[n // 2]) / 2
        rows.append({"unit": svc, "last_wall_s": round(walls[-1], 3),
                     "runs_24h": n, "p50_s": round(p50, 3), "max_s": round(max(s), 3)})

ceremonies = []
for line in run(["journalctl", "--user", "-u", "hngh-autonomy.service",
                 "--since", since, "--no-pager"]).splitlines():
    if "[ceremony-timing]" not in line:
        continue
    # ...: [ceremony-timing] create-run 123 ms
    body = line[line.index("[ceremony-timing]") + len("[ceremony-timing]"):].split()
    if len(body) >= 2 and body[-1] == "ms":
        try:
            ms = float(body[-2])
        except ValueError:
            continue
        ceremonies.append({"step": " ".join(body[:-2]) or "?", "ms": ms,
                           "ts": line.split()[0] if line else ""})
ceremonies = ceremonies[-max_cer:]

# --- drop-in lanes: logs/drop-in-timing.log lines <utc-ts>|<name>|<wall> ---
# (cadence-tick.sh appends one line per drop-in run; last 24h only)
try:
    log = open(os.path.join(root, "logs", "drop-in-timing.log"),
               encoding="utf-8").read().splitlines()
except OSError:
    log = []  # fail-closed: no log yet -> no dropin rows
cutoff = calendar.timegm(time.gmtime()) - window_h * 3600
per_name = {}
now_epoch = calendar.timegm(time.gmtime())
for line in log:
    parts = line.split("|")
    if len(parts) != 3:
        continue
    ts, name, wall = parts
    try:
        epoch = calendar.timegm(time.strptime(ts[:19], "%Y-%m-%dT%H:%M:%S"))
        wall = float(wall)
    except ValueError:
        continue
    if epoch < cutoff or epoch > now_epoch + 60:
        continue
    per_name.setdefault(name, []).append((epoch, wall))
for name, pairs in sorted(per_name.items()):
    walls = [w for _, w in pairs]
    s = sorted(walls)
    n = len(s)
    p50 = s[n // 2] if n % 2 else (s[n // 2 - 1] + s[n // 2]) / 2
    rows.append({"unit": "dropin:" + name, "last_wall_s": round(walls[-1], 3),
                 "runs_24h": n, "p50_s": round(p50, 3), "max_s": round(max(s), 3)})

# --- wrapped sessions: bridge record.lisp receipt pairs (closed runs only) ---
# creation receipt ts vs closing receipt ts; a run with no closing receipt
# contributes no wall (never guess)
def _slug4(objective):
    slug = re.sub(r"[^a-z0-9]+", "-", (objective or "").lower()).strip("-")
    return slug[:4] or "run"

recs = sorted(glob.glob(os.path.join(root, "bridge", "*", "record.lisp")))
cur = os.path.join(root, "bridge", "record.lisp")
if os.path.isfile(cur):
    recs.append(cur)
for rec in recs:
    try:
        text = open(rec, encoding="utf-8", errors="replace").read()
    except OSError:
        continue
    mobj = re.search(r':OBJECTIVE "([^"]*)"', text)
    made = None
    closed = None
    has_close = False
    for line in text.splitlines():
        if ":KIND :CLOSE" in line:
            has_close = True
            mt = re.search(r"timestamp: (\S+?Z)", line)
            if mt:
                try:
                    closed = calendar.timegm(time.strptime(mt.group(1)[:19],
                                                           "%Y-%m-%dT%H:%M:%S"))
                except ValueError:
                    pass
            continue
        mt = re.search(r"timestamp: (\S+?Z)", line)
        if not mt:
            continue
        try:
            ts = calendar.timegm(time.strptime(mt.group(1)[:19],
                                               "%Y-%m-%dT%H:%M:%S"))
        except ValueError:
            continue
        if made is None:
            made = ts  # first receipt = creation
    if has_close and closed is None:
        try:
            # hngh close receipts carry no timestamp fact; the close time is
            # the moment the close line was appended (file mtime)
            closed = os.path.getmtime(rec)
        except OSError:
            closed = None
    if made is None or closed is None or closed < made:
        continue  # open or corrupt run: no wall, never guess
    rows.append({"unit": "bridge:" + _slug4(mobj.group(1) if mobj else ""),
                 "last_wall_s": round(closed - made, 3),
                 "runs_24h": 1, "p50_s": round(closed - made, 3),
                 "max_s": round(closed - made, 3)})

out = {"generated_at": datetime.now().astimezone().isoformat(timespec="seconds"),
       "units": rows, "ceremonies": ceremonies}
print(json.dumps(out, indent=1))
PYEOF
 rm -f "$LEDGER.$$.tmp"
 breadcrumb "time-ledger.sh" "skip" "ledger generation failed; prior ledger kept"
 exit 0
fi
[ -s "$LEDGER.$$.tmp" ] || {
  rm -f "$LEDGER.$$.tmp"
 exit 0
}
mv "$LEDGER.$$.tmp" "$LEDGER"
breadcrumb "time-ledger.sh" "ledger" "time-ledger.json refreshed ($(wc -c <"$LEDGER") bytes)"
exit 0
