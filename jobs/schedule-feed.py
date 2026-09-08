#!/usr/bin/env python3
"""schedule-feed — build dashboard/schedule.json: one unified timeline source
for the Schedule view.

recurring: Hngh + system operations that repeat —
  - systemd --user timers (NEXT/LAST parsed from list-timers --all)
  - cadence drop-ins (cadence/<tier>/*.sh, run by the cadence tick)
  - config-backup lanes (git-back-dots parity jobs, 'gbd-lane')
oneoff: queued lanes from readout.json with the honest estimate chain
  (ledger p50 -> loadout time-limit x0.5 -> default 30m) and depends-on.

Each row carries hngh:true/false — the view compacts system units into a
backdrop band (never hidden, just densified). Fail-closed per source: a
source that fails is dropped and named in degraded[]; prior schedule.json is
kept when readout (the oneoff source) is unreadable. Display only — this
feed never feeds governance input.
"""
import glob
import json
import os
import re
import subprocess
import time
from datetime import datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
READOUT = os.path.join(ROOT, "dashboard", "readout.json")
SESSIONS = os.path.join(ROOT, "dashboard", "sessions.json")
LEDGER = os.path.join(ROOT, "dashboard", "time-ledger.json")
OUT = os.path.join(ROOT, "dashboard", "schedule.json")
CADENCE_DIR = os.path.join(ROOT, "cadence")
CONFIG_BACKUP = os.path.join(ROOT, "jobs", "config-backup.sh")

# Hngh-owned operations (any hngh-* unit); everything else is system backdrop
HNGH_PREFIXES = ("hngh",)
DEFAULT_EST_S = 30 * 60

TIER_BY_DIR = {"1m": 60, "5m": 300, "10m": 600, "hour": 3600,
               "day": 86400, "week": 604800, "month": 2592000}


def is_hngh(name):
    return any(name.startswith(p) for p in HNGH_PREFIXES)


def tier_of(interval_s):
    if not interval_s:
        return None
    if interval_s <= 90:
        return "1m"
    if interval_s <= 450:
        return "5m"
    if interval_s <= 900:
        return "10m"
    if interval_s <= 2100:
        return "30m"
    if interval_s <= 5400:
        return "hour"
    if interval_s <= 64800:
        return "day"
    return "quarter"


def parse_iso_local(s):
    """'Thu 2026-08-27 14:02:00 EDT' -> local epoch (tz name dropped: the
    dashboard renders in local time anyway). None on anything else."""
    try:
        parts = s.split()
        return datetime.strptime(parts[1] + " " + parts[2], "%Y-%m-%d %H:%M:%S").timestamp()
    except Exception:
        return None


def parse_duration(s):
    """systemd duration ('4d 1h 8min 20.847041s', '1d', '15min') -> seconds."""
    if not s:
        return None
    units = {"us": 1e-6, "ms": 1e-3, "s": 1, "min": 60, "h": 3600,
             "d": 86400, "w": 604800, "month": 2592000, "y": 31536000}
    total = 0.0
    for n, u in re.findall(r"(\d+(?:\.\d+)?)\s*(us|ms|s|min|h|d|w|month|y)", str(s)):
        total += float(n) * units[u]
    return total or None


def parse_calendar_interval(spec):
    """Quick interval read off an OnCalendar spec; None when not simple.
    '*:*:00'->60  '*-*-* *:0/5:00'->300  '*-*-* 00,04,..:00:00'->4h
    '*-*-* *:00:00'->3600  'Mon *-*-* 06:00:00'->week  '*-*-01 ..'->month"""
    if not spec:
        return None
    f = str(spec).split()
    if len(f) == 3:      # weekday-pinned -> weekly
        return 604800
    if len(f) != 2:
        return None
    date, clock = f
    hh, mm, _ss = (clock.split(":") + ["00", "00"])[:3]
    if date == "*-*-*":
        if re.fullmatch(r"\*/(\d+)", mm):
            return int(mm[2:]) * 60
        if re.fullmatch(r"0/(\d+)", mm):
            return int(mm[2:]) * 60
        hours = [h for h in hh.split(",") if h != "*"]
        if len(hours) > 1:
            hs = [int(h) for h in hours]
            step = hs[1] - hs[0]
            if step > 0 and all(b - a == step for a, b in zip(hs, hs[1:])):
                return step * 3600
        if mm in ("00", "0") and hh == "*":
            return 3600
        if hh not in ("*", ""):
            return 86400
    if re.fullmatch(r"\*-\d{2}-\d{2}", date):
        return 2592000  # pinned month-day -> monthly
    return None


def systemd_timers(ledger):
    """Recurring rows from `systemctl --user list-timers --all` (UNIT column
    = second-to-last token, spacing-proof) with next/last/OnCalendar read
    off one `systemctl show` call. Fail-closed: raises on any systemctl
    failure."""
    out = subprocess.run(
        ["systemctl", "--user", "list-timers", "--all", "--no-pager"],
        capture_output=True, text=True, timeout=20, check=True).stdout
    names = []
    for line in out.splitlines():
        toks = line.split()
        if len(toks) < 2 or toks[0] == "NEXT":
            continue
        unit = toks[-2]  # UNIT column, right before ACTIVATES
        if not unit.endswith(".timer"):
            continue  # drops the "N timers listed." footer
        if unit not in names:
            names.append(unit)
    # facts from the timer units themselves (one call, all units)
    try:
        show = subprocess.run(
            ["systemctl", "--user", "show", "--no-pager",
             "--property=Id,TimersCalendar,TimersMonotonic,LastTriggerUSec"] + names,
            capture_output=True, text=True, timeout=20, check=True).stdout
    except Exception:
        show = ""
    info = {}  # unit -> {interval_s, interval_hint, next_epoch, last_epoch}
    for block in show.split("\n\n"):
        unit, hint, cal_spec, nxt, last, iv_monotonic = None, None, None, None, None, None
        for line in block.splitlines():
            if line.startswith("Id="):
                unit = line[3:].strip()
            m = re.search(r"TimersCalendar=\{\s*OnCalendar=(.*?)\s*;.*?next_elapse=(.*?)\s*\}", line)
            if m:
                cal_spec = m.group(1)
                hint = "OnCalendar " + cal_spec
                nxt = parse_iso_local(m.group(2))
            m = re.search(r"TimersMonotonic=\{\s*OnUnitActiveUSec=(.*?)\s*;", line)
            if m:
                iv_monotonic = parse_duration(m.group(1))
                hint = "OnUnitActiveSec " + m.group(1)
                m2 = re.search(r"next_elapse=(.*?)\s*\}", line)
                if m2:
                    d = parse_duration(m2.group(1))
                    nxt = time.time() + d if d else None
            if line.startswith("LastTriggerUSec="):
                last = parse_iso_local(line.split("=", 1)[1])
        if unit:
            info[unit] = {"interval_s": iv_monotonic or parse_calendar_interval(cal_spec),
                          "interval_hint": hint,
                          "next_epoch": nxt, "last_epoch": last}
    out_rows = []
    for unit_name in names:
        name = unit_name[:-6] if unit_name.endswith(".timer") else unit_name
        f = info.get(unit_name, {})
        interval_s = f.get("interval_s")
        m = re.search(r"cadence-(\w+)", name)  # name token beats spec parsing
        if m and m.group(1) in TIER_BY_DIR:
            interval_s = TIER_BY_DIR[m.group(1)]
        if interval_s is None and (ledger_runs(name, ledger) or 0) > 1:
            interval_s = 86400.0 / ledger_runs(name, ledger)  # observed cadence, last resort
        out_rows.append({
            "name": name, "unit": name, "cadence": None,
            "tier": tier_of(interval_s),
            "interval_hint": f.get("interval_hint") or
                             (("%ds" % interval_s) if interval_s else None),
            "interval_s": interval_s,
            "next_epoch": f.get("next_epoch"),
            "last_epoch": f.get("last_epoch"),
            "last_wall_s": ledger_last_wall(name, ledger),
            "p50_s": ledger_p50(name, ledger),
            "runs_24h": ledger_runs(name, ledger),
            "source": "systemd timer",
            "hngh": is_hngh(name),
        })
    return out_rows


def load_json(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def ledger_join(unit_name, ledger):
    for u in ledger.get("units") or []:
        if u.get("unit") == unit_name or u.get("unit") == unit_name + ".service":
            return u
    return None


def ledger_last_wall(unit_name, ledger):
    u = ledger_join(unit_name, ledger)
    return u.get("last_wall_s") if u else None


def ledger_p50(unit_name, ledger):
    u = ledger_join(unit_name, ledger)
    return u.get("p50_s") if u else None


def ledger_runs(unit_name, ledger):
    u = ledger_join(unit_name, ledger)
    return u.get("runs_24h") if u else None


def cadence_dropins():
    """Recurring rows from cadence/<tier>/*.sh."""
    rows = []
    for tier_dir in sorted(glob.glob(os.path.join(CADENCE_DIR, "*"))):
        tier = os.path.basename(tier_dir)
        if tier not in TIER_BY_DIR or not os.path.isdir(tier_dir):
            continue
        for path in sorted(glob.glob(os.path.join(tier_dir, "*.sh"))):
            name = os.path.splitext(os.path.basename(path))[0]
            interval_s = TIER_BY_DIR[tier]
            rows.append({
                "name": name, "unit": None, "cadence": tier,
                "tier": tier_of(interval_s),
                "interval_hint": "cadence " + tier,
                "interval_s": interval_s,
                "next_epoch": None, "last_epoch": None,
                "last_wall_s": None, "p50_s": None, "runs_24h": None,
                "source": "cadence drop-in", "hngh": True,
            })
    return rows


def gbd_lanes():
    """config-backup lanes (git-back-dots parity jobs). Operator-run spike
    slice: no fixed schedule yet — honest interval_hint, no invented cadence."""
    try:
        with open(CONFIG_BACKUP, encoding="utf-8") as f:
            text = f.read()
    except Exception:
        return []
    names = sorted(set(re.findall(
        r'\n\s+([a-z0-9._-]+)\)\s+echo "\$HOME/\.local/state/git-back-dots', text)))
    return [{
        "name": "config-backup " + n, "unit": None, "cadence": None,
        "tier": None, "interval_hint": "operator-run (gbd parity lane)",
        "interval_s": None, "next_epoch": None, "last_epoch": None,
        "last_wall_s": None, "p50_s": None, "runs_24h": None,
        "source": "gbd-lane", "hngh": True,
    } for n in names]


# ---------- one-off: the existing gantt estimate chain, ported ----------

def ledger_unit_for(lane_id, ledger):
    """Token match lane -> ledger unit (same chain as gantt.js)."""
    toks = [t for t in re.split(r"[^a-z0-9]+", str(lane_id).lower()) if len(t) >= 4]
    stop = ["hngh", "automation", "service", "timer", "path", "shutdown", "dashboard"]
    for u in ledger.get("units") or []:
        un = str(u.get("unit") or "").lower()
        if u.get("unit") and any(t in un for t in toks if t not in stop):
            return u
    return None


def estimate_for(lane_id, ledger, sessions):
    u = ledger_unit_for(lane_id, ledger)
    if u and u.get("p50_s") is not None:
        return float(u["p50_s"]), "ledger p50 " + u["unit"]
    for s in sessions or []:
        if lane_id.lower() not in str(s.get("mission") or "").lower():
            continue
        tl = re.search(r":TIME-LIMIT (\d+)", (s.get("detail") or {}).get("tail") or "")
        if tl:
            return int(tl.group(1)) * 0.5, "loadout time-limit %ss x0.5 (%s)" % (tl.group(1), s.get("id"))
    return DEFAULT_EST_S, "default 30m"


def oneoff_rows(ledger, sessions):
    readout = load_json(READOUT)
    queue = readout.get("queue") or []
    etas = readout.get("etas") or {}
    ids = {r.get("id") for r in queue if isinstance(r, dict) and r.get("id")}
    rows = []
    for r in queue:
        if not isinstance(r, dict) or r.get("id") is None or r.get("status") == "done":
            continue
        lane = r["id"]
        est_s, est_src = estimate_for(lane, ledger, sessions)
        dep = None
        m = re.search(r"after\s+([a-z0-9._-]+)", str(etas.get(lane, "")), re.I)
        if m:
            d = m.group(1).rstrip(".,;")
            if d in ids:
                dep = d
            elif len(d) < 4:
                dep = None  # "after a full session" -> token "a" is not a lane
            else:
                hits = [i for i in sorted(ids) if i.startswith(d)]
                if len(hits) == 1:
                    dep = hits[0]
        rows.append({"name": lane, "depends_on": dep, "estimate_s": est_s,
                     "estimate_source": est_src, "status": r.get("status"),
                     "placeholder": est_src == "default 30m"})
    return rows


def main():
    degraded = []
    ledger = {}
    try:
        ledger = load_json(LEDGER)
    except Exception as e:
        degraded.append({"source": "time-ledger.json", "error": str(e)})

    recurring, oneoff = [], []
    try:
        recurring += systemd_timers(ledger)
    except Exception as e:
        degraded.append({"source": "systemd timer", "error": str(e)})
    try:
        recurring += cadence_dropins()
    except Exception as e:
        degraded.append({"source": "cadence drop-in", "error": str(e)})
    try:
        recurring += gbd_lanes()
    except Exception as e:
        degraded.append({"source": "gbd-lane", "error": str(e)})

    try:
        sessions = load_json(SESSIONS).get("sessions") or []
    except Exception as e:
        sessions, _ = [], degraded.append({"source": "sessions.json", "error": str(e)})
    try:
        oneoff = oneoff_rows(ledger, sessions)
    except Exception as e:
        degraded.append({"source": "readout.json (oneoff)", "error": str(e)})

    feed = {
        "generated": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "recurring": recurring,
        "oneoff": oneoff,
        "degraded": degraded,
    }
    # per-PID tmp — never share a tmp across processes (see sessions-feed.py)
    tmp = "%s.%d.tmp" % (OUT, os.getpid())
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(feed, f, indent=2)
    os.replace(tmp, OUT)
    sys_n = sum(1 for r in recurring if not r["hngh"])
    print("schedule.json: recurring %d (hngh %d, system %d), oneoff %d, degraded %d"
          % (len(recurring), len(recurring) - sys_n, sys_n, len(oneoff), len(degraded)))


if __name__ == "__main__":
    main()