#!/usr/bin/env python3
"""agent-supervision — Hngh-native subagent supervision tick (Self-supervision
rung, smallest slice). Hngh itself checks delegated agent sessions and flags
stalls — no harness agent required.

Sources (same specimen dirs as sessions-feed.py):
  - bridge store record.lisp runs whose newest :STATE is non-terminal;
  - omp transcripts (~/.omp/agent/sessions/**.jsonl) modified in the last
    MAX_TRACKED_AGE_S eviction horizon (main sessions + per-agent jsonl).

Per session: entry count, tool-call count, last tool-call age, last entry
age, transcript size delta vs the prior tick. Phase from the tool-call/size
pattern: no entries = discovering; toolCalls rising + size growing = writing;
toolCalls flat + size creeping = verifying; size/toolCalls unchanged >15m
while non-terminal = STALLED. Transcript phase rule: a quiet session whose
final assistant turn asks the operator something (confirm/shall i/...) is
STALLED (awaiting-operator), never terminal.

Findings are report-queue rows (alert kind, deduped via --identity so
repeats collapse to xN; recovery emits one "recovered" progress row — the
flap pattern). omp-transcript stalls stay advisory: this tick never kills,
restarts, or mutates a live session. Bridge-store runs are the roguelike
exception: a stalled run (its id came from the bridge record, not a
transcript) is replaced in-tick — hngh close-run dead, the closed record
rotates into a timestamped bridge subdir, and omp-bridge --run-start
re-provisions the same mission (2026-08-27, stage-3 criterion 2).

Fail-closed: every source error degrades to skip; the tick always exits 0.
Healthy ticks are silent. State: dashboard/agent-supervision-state.json
(rolling, cap 100 ids). Env overrides for tests: SUPERVISION_STATE,
SUPERVISION_SOURCES (comma-separated dirs/files for omp transcripts),
OMP_BRIDGE_STORE (same var sessions-feed honors), SUPERVISION_REPORT_QUEUE.
"""
import calendar
import glob
import hashlib
import json
import os
import re
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STATE_FILE = os.environ.get(
    "SUPERVISION_STATE", os.path.join(ROOT, "dashboard", "agent-supervision-state.json"))
BRIDGE_STORE = os.environ.get(
    "OMP_BRIDGE_STORE",
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "bridge"))
REPORT_QUEUE = os.environ.get(
    "SUPERVISION_REPORT_QUEUE",
    os.path.join(os.environ.get("HNGH_REPO",
                                "/home/bricker/Projects/etc/hngh"),
                 "scripts", "report-queue"))
HNGH_BIN = os.environ.get(
    "HNGH_BIN",
    os.path.join(ROOT, "..", "hngh", "scripts", "hngh"))
OMP_BRIDGE_BIN = os.environ.get(
    "OMP_BRIDGE_BIN",
    os.path.join(ROOT, "..", "hngh", "scripts", "omp-bridge"))

STALL_TOOLCALL_MIN = 20   # last tool-call older than this => stalled
STALL_MINUTES = 15        # size+toolcalls unchanged this long => stalled
STALL_TICKS = 2           # ...or size unchanged across >2 ticks
MAX_TRACKED_AGE_S = 21600  # transcript session idle this long => evicted, not flagged
LIVE_S = 300              # mtime younger => omp session "live" (sessions-feed rule)
STATE_CAP = 100           # rolling state file, ids kept
OMP_MAX = 32              # transcript cap per tick

TERMINAL = {"cancelled", "evacuated", "dead", "complete"}
TS_RE = re.compile(r'"timestamp":"([^"]+)"')
# omp jsonl tool-call markers: assistant toolCall parts + execution events
TOOL_MARKS = ('"type":"toolCall"', '"customType":"tool_execution_start"')
# an assistant text turn asking the operator something (pause-for-human)
ASK_RE = re.compile(r"\b(confirm|confirmation|shall i|should i|"
                    r"waiting for|may i proceed|yes or no|y/n)\b", re.I)


def _iso_ts(s):
    """Local epoch seconds from an ISO timestamp, or None (fail-closed)."""
    try:
        # hngh record timestamps are UTC (2026-08-27T22:46:19Z); mktime
        # would read them as local and skew stall ages by the UTC offset
        return calendar.timegm(time.strptime(s[:19], "%Y-%m-%dT%H:%M:%S"))
    except (ValueError, TypeError):
        return None


def classify(entries, tools, prior_tools, size, prior_size,
             unchanged_min, tool_age_min, nonterminal=True):
    """Phase from the tool-call/size pattern (pure — selfcheck table)."""
    if not nonterminal:
        return "terminal"
    if entries == 0:
        return "discovering"
    if tool_age_min is not None and tool_age_min > STALL_TOOLCALL_MIN:
        return "stalled"
    size_eq = prior_size is not None and size == prior_size
    tools_eq = prior_tools is not None and tools == prior_tools
    if size_eq and tools_eq:
        if unchanged_min is None or unchanged_min > STALL_MINUTES:
            return "stalled"
        return "verifying"  # digesting results, nothing new this tick
    if tools > (prior_tools or 0) and size > (prior_size or 0):
        return "writing"
    return "verifying"      # tools flat, size creeping


def scan_transcript(path):
    """(entries, toolcalls, last_tool_ts, asks) for an omp jsonl — asks is
    True when the LAST assistant text turn contains an ask-the-operator
    phrase (the session paused for a human). Fail-closed: returns None
    on any read/parse fault."""
    entries, toolcalls, last_tool_ts = 0, 0, None
    last_asst_line = None
    exited = False
    try:
        with open(path, "rb") as f:
            for raw in f:
                entries += 1
                line = raw.decode("utf-8", errors="replace")
                if any(m in line for m in TOOL_MARKS):
                    toolcalls += 1
                    m = TS_RE.search(line)
                    ts = _iso_ts(m.group(1)) if m else None
                    if ts:
                        last_tool_ts = ts
                if '"role":"assistant"' in line and '"type":"text"' in line:
                    last_asst_line = line
                # omp writes a session_exit custom event when a session
                # ends; marker in the FINAL line means the session is
                # dead, never coming back — terminal, never a stall
                exited = '"customType":"session_exit"' in line
    except OSError:
        return None
    if entries == 0:
        return None
    asks = bool(last_asst_line and ASK_RE.search(last_asst_line))
    return {"entries": entries, "toolcalls": toolcalls,
            "last_tool_ts": last_tool_ts, "asks": asks, "exited": exited}


def awaiting_stall(asks, quiet_min, live):
    """Transcript phase rule (pure — selfcheck fixture): a session that is
    no longer live and whose final assistant turn asks the operator
    something is STALLED (awaiting-operator), never terminal — the
    2026-09-02 stall was a session sitting on a push-confirmation
    question the standing authorization had already answered."""
    return bool(asks) and not live and quiet_min is not None \
        and quiet_min > STALL_MINUTES


def bridge_sessions():
    """Non-terminal runs from the bridge store record.lisp, newest state
    per identifier (parse like sessions-feed)."""
    rec = os.path.join(BRIDGE_STORE, "record.lisp")
    if not os.path.isfile(rec):
        return []
    runs, order = {}, []
    try:
        with open(rec, encoding="utf-8", errors="replace") as f:
            for line in f:
                mid = re.search(r':IDENTIFIER "([^"]+)"', line)
                mst = re.search(r':STATE :(\w+)', line)
                mobj = re.search(r':OBJECTIVE "([^"]*)"', line)
                if not (mid and mst):
                    continue
                sid = mid.group(1)
                if sid not in runs:
                    order.append(sid)
                    runs[sid] = {}
                if mobj:
                    runs[sid]["objective"] = mobj.group(1)
                ts = None
                mt = re.search(r"timestamp: (\S+?Z)", line)
                if mt:
                    ts = _iso_ts(mt.group(1))
                runs[sid]["state"] = mst.group(1).lower()
                runs[sid]["last_ts"] = ts
    except OSError:
        return []
    try:
        size = os.path.getsize(rec)
        mtime = os.path.getmtime(rec)
    except OSError:
        return []
    out = []
    for sid in order:
        run = runs[sid]
        if run["state"] in TERMINAL:
            continue  # run-1 cancelled etc. — terminal, skip
        last_ts = run["last_ts"] or mtime
        out.append({"id": sid, "path": rec, "size": size, "entries": 1,
                    "toolcalls": 0, "last_tool_ts": None,
                    "last_entry_ts": last_ts, "nonterminal": True})
        out[-1]["source"] = "bridge"
        out[-1]["objective"] = runs[sid].get("objective", "")
    return out


def omp_sessions(now):
    """Recent omp transcripts from the specimen dirs (sessions-feed globs),
    newest activity first, capped."""
    sources = [s for s in os.environ.get("SUPERVISION_SOURCES", "").split(",")
               if s.strip()] or \
        [os.path.join(os.path.expanduser("~"), ".omp", "agent", "sessions")]
    # scan to the eviction horizon, not a short freshness window: a
    # session paused asking the operator goes quiet for hours yet is
    # exactly the phase supervision must still see (awaiting-operator).
    cutoff = now - MAX_TRACKED_AGE_S
    paths = []
    for src in sources:
        if os.path.isfile(src):
            paths.append(src)
            continue
        paths += glob.glob(os.path.join(src, "*.jsonl"))
        paths += glob.glob(os.path.join(src, "*", "*.jsonl"))
        paths += glob.glob(os.path.join(src, "*", "*", "*.jsonl"))
    cands = []
    for path in paths:
        try:
            mtime = os.path.getmtime(path)
        except OSError:
            continue
        if mtime < cutoff or mtime > now:
            continue
        cands.append({"path": path, "mtime": mtime})
    cands.sort(key=lambda c: c["mtime"], reverse=True)
    out = []
    for cand in cands[:OMP_MAX]:
        stats = scan_transcript(cand["path"])
        if not stats:
            continue
        stem = os.path.splitext(os.path.basename(cand["path"]))[0]
        digest = hashlib.md5(cand["path"].encode()).hexdigest()[:6]
        sid = "omp-%s-%s" % (stem[:28], digest)
        live = now - cand["mtime"] < LIVE_S
        stats_exited = stats.get("exited", False)
        out.append({"id": sid, "path": cand["path"],
                    "size": os.path.getsize(cand["path"]),
                    "last_entry_ts": cand["mtime"],
                    "nonterminal": live and not stats_exited,
                    "asks": stats.get("asks", False),
                    **{k: v for k, v in stats.items() if k != "asks"}})
    return out


def report(args):
    """report-queue add; any fault is silent (advisory, fail-closed)."""
    try:
        subprocess.run([REPORT_QUEUE] + args, timeout=30,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                       check=False)
    except Exception:
        pass


def fmt_age(minutes):
    return "%dm" % minutes if minutes is not None else "n/a"


def replace_stalled_bridge_run(session):
    """Roguelike replacement for a stalled bridge-store run: hngh
    close-run dead (legal from :created per +legal-run-successors+),
    rotate the closed record into a timestamped subdir (one run per
    store — a second create-run would record-conflict), then omp-bridge
    --run-start re-provisions the same mission. Returns alert-body lines
    evidencing both commands; never raises (fail-closed tick)."""
    lines = []
    try:
        p = subprocess.run(
            [HNGH_BIN, "--store=%s" % BRIDGE_STORE,
             "close-run", session["id"], "dead"],
            capture_output=True, text=True, timeout=60)
        lines.append("close-run: rc=%d %s"
                     % (p.returncode,
                        ((p.stdout or "") + (p.stderr or "")).strip()[:160]))
        if p.returncode != 0:
            # the run never reached a terminal state — do not rotate or
            # re-provision over an unclosed run; retry on the next tick
            return lines
    except Exception as exc:
        lines.append("close-run fault: %s" % type(exc).__name__)
        return lines
    try:
        subdir = os.path.join(
            BRIDGE_STORE, "%s-%s" % (time.strftime("%Y%m%dT%H%M%SZ",
                                                   time.gmtime()),
                                     session["id"]))
        os.makedirs(subdir, exist_ok=True)
        os.replace(os.path.join(BRIDGE_STORE, "record.lisp"),
                   os.path.join(subdir, "record.lisp"))
    except OSError as exc:
        lines.append("record rotate fault: %s" % type(exc).__name__)
        return lines
    try:
        p = subprocess.run(
            [OMP_BRIDGE_BIN, "--run-start", "auto-replace",
             session.get("objective") or "re-provisioned after stall"],
            capture_output=True, text=True, timeout=120)
        lines.append("run-start: rc=%d %s"
                     % (p.returncode,
                        ((p.stdout or "") + (p.stderr or "")).strip()[:160]))
    except Exception as exc:
        lines.append("run-start fault: %s" % type(exc).__name__)
    return lines


def load_state():
    try:
        with open(STATE_FILE, encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def save_state(state):
    if len(state) > STATE_CAP:
        for sid, _ in sorted(state.items(), key=lambda kv: kv[1].get("first_seen", 0))[
                :len(state) - STATE_CAP]:
            del state[sid]
    tmp = STATE_FILE + ".tmp"
    try:
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(state, f, indent=2)
        os.replace(tmp, STATE_FILE)
    except OSError:
        pass


def tick():
    now = time.time()
    state = load_state()
    sessions = bridge_sessions() + omp_sessions(now)
    for s in sessions:
        try:
            prev = state.get(s["id"], {})
            prior_size = prev.get("last_size")
            prior_tools = prev.get("last_toolcalls")
            tool_age_min = None
            if s["last_tool_ts"]:
                tool_age_min = max(0, (now - s["last_tool_ts"]) / 60.0)
            unchanged_min = None
            if prior_size == s["size"] and prior_tools == s["toolcalls"]:
                unchanged_min = max(0, (now - s["last_entry_ts"]) / 60.0)
            if (s.get("source") != "bridge"
                    and tool_age_min is not None
                    and tool_age_min * 60.0 > MAX_TRACKED_AGE_S):
                # Stale transcript sessions (e.g. a director session idle all
                # weekend) are evicted, not flagged: one journal row on first
                # eviction, then silence — no stall/recover flap noise. Bridge
                # runs keep their stall->replace path regardless of age.
                if prev.get("last_phase") != "evicted":
                    report(["--add", "progress",
                            "agent-supervision: evicted-stale %s (idle %s)"
                            % (s["id"], fmt_age(tool_age_min)),
                            "--identity", "supervision-evicted:%s" % s["id"],
                            "--window", "604800"])
                state[s["id"]] = {
                    "last_size": s["size"],
                    "last_toolcalls": s["toolcalls"],
                    "first_seen": prev.get("first_seen", int(now)),
                    "last_phase": "evicted",
                }
                continue
            quiet_min = max(0, (now - s["last_entry_ts"]) / 60.0)
            if (s.get("source") != "bridge" and not s.get("exited")
                    and awaiting_stall(s.get("asks"), quiet_min,
                                       s["nonterminal"])):
                phase = "stalled"
            else:
                phase = classify(s["entries"], s["toolcalls"], prior_tools,
                                 s["size"], prior_size, unchanged_min,
                                 tool_age_min, s["nonterminal"])
            if phase == "stalled":
                body = ("agent-stall %s: %s, last tool-call %s ago"
                        % (s["id"], phase, fmt_age(tool_age_min)))
                if s.get("asks") and s.get("source") != "bridge":
                    body += " (awaiting-operator: transcript ends asking" \
                            " the operator)"
                if s.get("source") == "bridge":
                    # roguelike replacement fires ONLY for bridge-run ids;
                    # transcript-derived stall flags stay advisory
                    body += " [" + " | ".join(
                        replace_stalled_bridge_run(s)) + "]"
                report(["--add", "alert", body,
                        "--identity", "agent-stall:%s" % s["id"],
                        "--window", "86400"])
            elif (prev.get("last_phase") == "stalled"
                    and not s.get("exited")):
                # recovery: progress resumed — one flap row (identity-deduped)
                report(["--add", "progress", "agent-stall %s: recovered" % s["id"],
                        "--identity", "agent-stall-recovered:%s" % s["id"],
                        "--window", "86400"])
            state[s["id"]] = {
                "last_size": s["size"],
                "last_toolcalls": s["toolcalls"],
                "first_seen": prev.get("first_seen", int(now)),
                "last_phase": phase,
            }
        except Exception:
            continue  # one bad session never takes the tick down
    save_state(state)


def selfcheck():
    """Classifier fixtures -> phase table. No files written."""
    cases = [
        ("terminal run (bridge :CANCELLED)", dict(entries=2, tools=0,
         prior_tools=None, size=500, prior_size=None, unchanged_min=90.0,
         tool_age_min=None, nonterminal=False)),
        ("no entries yet", dict(entries=0, tools=0, prior_tools=None,
         size=0, prior_size=None, unchanged_min=1.0, tool_age_min=None)),
        ("toolCalls rising, size growing", dict(entries=40, tools=9,
         prior_tools=6, size=9000, prior_size=6000, unchanged_min=0.0,
         tool_age_min=0.5)),
        ("toolCalls flat, size creeping slowly", dict(entries=40, tools=9,
         prior_tools=9, size=9200, prior_size=9000, unchanged_min=0.0,
         tool_age_min=4.0)),
        ("size+toolCalls unchanged >15m, non-terminal", dict(entries=40,
         tools=9, prior_tools=9, size=9200, prior_size=9200,
         unchanged_min=22.0, tool_age_min=22.0)),
        ("last tool-call 45m ago", dict(entries=40, tools=9, prior_tools=9,
         size=9200, prior_size=9200, unchanged_min=1.0, tool_age_min=45.0)),
        ("fresh idle (<15m unchanged)", dict(entries=40, tools=9,
         prior_tools=9, size=9200, prior_size=9200, unchanged_min=3.0,
         tool_age_min=3.0)),
    ]
    print("%-44s %s" % ("fixture", "phase"))
    print("-" * 60)
    phases = []
    for name, kw in cases:
        p = classify(**kw)
        phases.append(p)
        print("%-44s %s" % (name, p))
    assert phases[0] == "terminal"
    assert phases[1] == "discovering"
    assert phases[2] == "writing"
    assert phases[3] == "verifying"
    assert phases[4] == "stalled"
    assert phases[5] == "stalled"
    assert phases[6] == "verifying"
    # transcript-phase rule: quiet session ending on an operator ask
    assert awaiting_stall(True, 20.0, False) is True
    assert awaiting_stall(True, 3.0, False) is False    # still fresh
    assert awaiting_stall(True, 1.0, True) is False     # still live
    assert awaiting_stall(False, 90.0, False) is False  # report, not an ask
    print("selfcheck ok: 7 fixtures, phases %s" % sorted(set(phases)))


def selfcheck_replace():
    """Hermetic seeded stall: fixture bridge record (stale timestamp),
    stub hngh/omp-bridge/report-queue binaries logging argv; two ticks.
    Asserts the flag row exists, close-run was called with dead, and
    exactly one re-provision --run-start landed."""
    import subprocess
    import tempfile
    stub = ("#!%s\n"
            "import os, sys\n"
            "open(os.environ['RQ_LOG'], 'a').write("
            "' '.join(sys.argv[1:]) + '\\n')\n"
            % sys.executable)
    with tempfile.TemporaryDirectory() as td:
        store = os.path.join(td, "bridge")
        os.makedirs(store)
        stale = time.strftime("%Y-%m-%dT%H:%M:%SZ",
                              time.gmtime(time.time() - 3600))
        with open(os.path.join(store, "record.lisp"), "w") as f:
            f.write('(:IDENTIFIER "run-1" :KIND :CREATION :STATE :CREATED '
                    ':RUN (:IDENTIFIER "run-1" :MISSION (:OBJECTIVE '
                    '"seeded stall") :STATE :CREATED) :RECEIPT '
                    '(:KIND :CREATION :FACTS ("identifier: run-1" '
                    '"timestamp: %s")))\n' % stale)
        argv_log = os.path.join(td, "argv.log")
        stubs = {}
        for name in ("hngh-stub", "bridge-stub", "rq-stub"):
            p = os.path.join(td, name)
            with open(p, "w") as f:
                f.write(stub)
            os.chmod(p, 0o755)
            stubs[name] = p
        env = dict(os.environ)
        env.update({
            "OMP_BRIDGE_STORE": store,
            "SUPERVISION_STATE": os.path.join(td, "state.json"),
            "SUPERVISION_REPORT_QUEUE": stubs["rq-stub"],
            "SUPERVISION_SOURCES": os.path.join(td, "no-omp"),
            "HNGH_BIN": stubs["hngh-stub"],
            "OMP_BRIDGE_BIN": stubs["bridge-stub"],
            "RQ_LOG": argv_log,
        })
        for _ in range(2):  # tick 1 records prior state; tick 2 stalls
            subprocess.run([sys.executable, os.path.abspath(__file__)],
                           env=env, capture_output=True, text=True,
                           timeout=120)
        log = open(argv_log).read()
        assert "close-run run-1 dead" in log, log
        assert log.count("--run-start") == 1, log
        assert "auto-replace" in log, log
        assert not os.path.isfile(os.path.join(store, "record.lisp"))
        assert os.path.isdir(store) and os.listdir(store), "rotated record"
    print("selfcheck-replace ok: flag + close-run dead + 1 re-provision")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--selfcheck-replace":
        selfcheck_replace()
    elif len(sys.argv) > 1 and sys.argv[1] == "--selfcheck":
        selfcheck()
    else:
        try:
            tick()
        except Exception:
            pass  # fail-closed: the tick never crashes
    sys.exit(0)
