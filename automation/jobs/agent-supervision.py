#!/usr/bin/env python3
"""agent-supervision — the ONE Hngh subagent supervision plane (P4
refoundation, 2026-09-25; supersedes and retires jobs/agent-watchdog.sh
and jobs/beat-watchdog.py, deleted this day).

Sources (same specimen dirs as sessions-feed.py):
  - bridge store record.lisp runs whose newest :STATE is non-terminal;
  - omp transcripts (~/.omp/agent/sessions/**.jsonl) modified in the last
    MAX_TRACKED_AGE_S eviction horizon (main sessions + per-agent jsonl);
  - the crumbs journal (lib/crumbs-db.py export) and agent-handoffs.md,
    for the virtual orchestrator session `overnight-lead` (the folded
    beat-watchdog rules).

Per session per tick (300s cadence pacing) one supervision state:
  active      evidence (transcript growth) aged <= 2 ticks (ACTIVE_S)
              and no watchdog detection fired;
  slow-valid  evidence fresh but tool-call count flat >
              STALL_TOOLCALL_MIN (20m) — ONE progress row suggesting a
              cheaper-tier re-queue; never kill/replace/steer;
  stalled     no evidence for 2 consecutive ticks, or a ported watchdog
              detection fired (trailing identical-tool-loop, or a final
              errish toolResult with no corrective step for
              watchdog-error-grace-min). Steer-once-then-die: first
              miss appends ONE `session-drop ... stalled: steer:` row
              plus a report row; the second consecutive miss dies the
              session. Bridge runs keep the roguelike replace path
              (hngh close-run dead + rotate + omp-bridge --run-start)
              now with cause= from lib/causes.sh classify_cause on the
              record; omp transcripts stay advisory (handoff + report
              rows, never a kill). cause=unknown is banned on
              transitions: unclassifiable deaths read
              cause=unclassified.

The overnight-lead virtual session folds the beat-watchdog rules over
crumbs export + handoff rows (legacy `overnight-lead ... dead` rows and
this die path's rows): launch-plane stall (>= beat-stall-n consecutive
failed results), trailing same-cause deaths (>= blocker-escalate-n, one
beat-blockers.tsv row, parked), and beat silence (newest overnight-done
older than beat-stall-silence-hours while cadence ticks kept arriving).

Findings are report-queue rows with identity supervision:<session>:<state>
(window 604800): alert kind for stalled/die and the overnight-lead rules,
progress for slow-valid and the recovered flap (identity-deduped xN).

Fail-closed: every source error degrades to skip; the tick always exits 0.
Healthy ticks are silent. State: dashboard/agent-supervision-state.json
(rolling, cap 100 ids). Env overrides for tests: SUPERVISION_STATE,
SUPERVISION_SOURCES (comma-separated dirs/files for omp transcripts),
OMP_BRIDGE_STORE (same var sessions-feed honors), SUPERVISION_REPORT_QUEUE,
SUPERVISION_HANDOFFS, SUPERVISION_BLOCKERS, SUPERVISION_PARAMS,
HNGH_CRUMBS_DB, SUPERVISION_CAUSES_SH.
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
sys.path.insert(0, os.path.join(ROOT, "lib"))
import report_queue  # the shared report-queue row shim (lib/report_queue.py)

STATE_FILE = os.environ.get(
    "SUPERVISION_STATE", os.path.join(ROOT, "dashboard", "agent-supervision-state.json"))
BRIDGE_STORE = os.environ.get(
    "OMP_BRIDGE_STORE",
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "bridge"))
REPORT_QUEUE = os.environ.get(
    "SUPERVISION_REPORT_QUEUE",
    os.path.join(os.environ.get("HNGH_REPO",
                                os.path.expanduser("~/Projects/etc/hngh")),
                 "scripts", "report-queue"))
HNGH_BIN = os.environ.get(
    "HNGH_BIN",
    os.path.join(ROOT, "..", "scripts", "hngh"))
OMP_BRIDGE_BIN = os.environ.get(
    "OMP_BRIDGE_BIN",
    os.path.join(ROOT, "..", "scripts", "omp-bridge"))
HANDOFFS = os.environ.get(
    "SUPERVISION_HANDOFFS", os.path.join(ROOT, "agent-handoffs.md"))
BLOCKERS = os.environ.get(
    "SUPERVISION_BLOCKERS",
    os.path.join(ROOT, "state", "beat-blockers.tsv"))
CRUMBS_DB = os.environ.get("HNGH_CRUMBS_DB",
                           os.path.join(ROOT, "state", "crumbs.db"))
CRUMBS_DB_PY = os.path.join(ROOT, "lib", "crumbs-db.py")
PARAMS = os.environ.get("SUPERVISION_PARAMS",
                        os.path.join(ROOT, "cadence-params.tsv"))
CAUSES_SH = os.environ.get("SUPERVISION_CAUSES_SH",
                           os.path.join(ROOT, "lib", "causes.sh"))

STALL_TOOLCALL_MIN = 20   # last tool-call older than this => stalled
STALL_MINUTES = 15        # size+toolcalls unchanged this long => stalled
STALL_TICKS = 2           # ...or size unchanged across >2 ticks
MAX_TRACKED_AGE_S = 21600  # transcript session idle this long => evicted, not flagged
LIVE_S = 300              # mtime younger => omp session "live" (sessions-feed rule)
ACTIVE_S = 600            # evidence age <= 2 ticks (300s pacing) => active
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


def errish(t):
    """Failure-shaped result text (verbatim keyword set ported from the
    retired agent-watchdog.sh)."""
    t = (t or "").lower()
    return any(k in t for k in (
        "traceback", "fatal", "exception", "does not exist", "not found",
        "error:", "failed", "permission denied", "exit status",
        "assertionerror", "fail:"))


def get_param(key, default):
    """cadence-params.tsv row value (tab-split, first-column match);
    fail-open to the default."""
    try:
        with open(PARAMS, encoding="utf-8", errors="replace") as fh:
            for ln in fh:
                f = ln.rstrip("\n").split("\t")
                if len(f) > 1 and f[0] == key and f[1]:
                    return f[1]
    except OSError:
        pass
    return str(default)


def scan_transcript(path):
    """Activity stats for an omp jsonl. Asks is True when the LAST
    assistant text turn contains an ask-the-operator phrase (the session
    paused for a human). loop_sig/err_sig are the two detections ported
    from the retired agent-watchdog.sh (2026-09-25): a trailing
    watchdog-loop-n run of identical tool calls (name + canonical
    arguments), and a final errish toolResult left uncorrected for
    watchdog-error-grace-min. Fail-closed: returns None on any
    read/parse fault."""
    entries, toolcalls, last_tool_ts = 0, 0, None
    last_asst_line = None
    exited = False
    calls = []  # (name, canonical args) — trailing-loop check
    last_role, last_text, last_ts = None, "", None
    loop_n = max(2, int(get_param("watchdog-loop-n", 3)))
    grace_s = float(get_param("watchdog-error-grace-min", 2)) * 60.0
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
                if '"role":"' not in line:
                    continue
                try:
                    rec = json.loads(line)
                except ValueError:
                    continue
                msg = rec.get("message")
                if not isinstance(msg, dict):
                    continue
                m = TS_RE.search(line)
                last_ts = _iso_ts(m.group(1)) if m else None
                last_role = msg.get("role")
                if last_role == "assistant":
                    for c in (msg.get("parts") or msg.get("content") or []):
                        if isinstance(c, dict) and c.get("type") == "toolCall":
                            try:
                                args = json.dumps(c.get("arguments"),
                                                  sort_keys=True)
                            except (TypeError, ValueError):
                                args = str(c.get("arguments"))
                            calls.append((c.get("name"), args))
                elif last_role == "toolResult":
                    last_text = "".join(
                        c.get("text", "") for c in
                        (msg.get("parts") or msg.get("content") or [])
                        if isinstance(c, dict))
    except OSError:
        return None
    if entries == 0:
        return None
    asks = bool(last_asst_line and ASK_RE.search(last_asst_line))
    tail = calls[-loop_n:]
    loop_sig = None
    if len(tail) == loop_n and all(x == tail[0] for x in tail):
        loop_sig = "identical tool call x%d: %s" % (loop_n, tail[0][0])
    err_sig = None
    if (last_role == "toolResult" and errish(last_text)
            and last_ts is not None
            and time.time() - last_ts > grace_s):
        err_sig = ("hard error result, no corrective step: %s"
                   % last_text.strip().replace("\n", " ")[:160])
    return {"entries": entries, "toolcalls": toolcalls,
            "last_tool_ts": last_tool_ts, "asks": asks, "exited": exited,
            "loop_sig": loop_sig, "err_sig": err_sig}


def awaiting_stall(asks, quiet_min, live):
    """Transcript phase rule (pure — selfcheck fixture): a session that is
    no longer live and whose final assistant turn asks the operator
    something is STALLED (awaiting-operator), never terminal — the
    2026-09-02 stall was a session sitting on a push-confirmation
    question the standing authorization had already answered."""
    return bool(asks) and not live and quiet_min is not None \
        and quiet_min > STALL_MINUTES


def ts_utc(epoch=None):
    """UTC wall-clock stamp for handoff/blocker rows (ledger format)."""
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(epoch))


def append_handoff(line):
    """One agent-handoffs.md row — the ledger agent-respawn.sh and the
    overnight-lead same-cause rule read. Any fault is silent."""
    try:
        with open(HANDOFFS, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except OSError:
        pass


def classify_cause_py(log):
    """lib/causes.sh classify_cause over the session record/log.
    'unknown' is banned on transitions — unclassifiable reads
    cause=unclassified (the shim's own contract)."""
    if log and os.path.isfile(log):
        try:
            p = subprocess.run(
                ["bash", "-c", '. "$1" >/dev/null 2>&1; classify_cause "$2"',
                 "causes", CAUSES_SH, log],
                capture_output=True, text=True, timeout=30)
            out = (p.stdout or "").strip().splitlines()
            if out and out[-1] and out[-1] != "unknown":
                return out[-1]
        except Exception:
            pass
    return "unclassified"


def steer_reason(s):
    """Why this session missed its tick: the ported watchdog detections
    when they fired, else plain transcript silence."""
    return (s.get("loop_sig") or s.get("err_sig")
            or "no transcript evidence this tick")


def steer_stalled(s, now, cause=None):
    """First missed tick (steer-once-then-die): ONE handoff steer row +
    ONE report row. Never kills — die_session owns the second miss."""
    reason = steer_reason(s)
    suffix = " cause=%s" % cause if cause else ""
    append_handoff("session-drop | %s | supervision|%s | stalled: steer: "
                   "%s%s" % (ts_utc(now), s["id"], reason, suffix))
    report("alert",
           "agent-supervision: %s stalled (missed tick 1) — steer: %s%s"
           % (s["id"], reason, suffix),
           "supervision:%s:stalled" % s["id"], "604800")


def die_session(s, now, cause=None):
    """Second consecutive missed tick. Bridge runs keep the roguelike
    replace path (close-run dead + rotate + re-provision); omp
    transcripts are advisory — handoff + report rows, never a kill.
    cause= comes from lib/causes.sh classify_cause on the record, or
    is named by the caller (repeat-loop) when a non-miss driver owns
    the death."""
    cause = cause or classify_cause_py(s.get("path") or "")
    if s.get("source") == "bridge":
        text = ("agent-supervision: %s died after 2 missed ticks "
                "(stalled) cause=%s [%s]"
                % (s["id"], cause,
                   " | ".join(replace_stalled_bridge_run(s))))
    else:
        text = ("agent-supervision: %s died after 2 missed ticks (stalled; "
                "advisory — omp transcripts are never killed) cause=%s"
                % (s["id"], cause))
    if "overnight-lead" in s["id"]:
        # overnight-lead-scope deaths join the legacy row shape the
        # same-cause rule and agent-respawn.sh dead_rows read
        append_handoff("overnight-lead | %s | overnight-lead|%s | dead: "
                       "stalled past 2 ticks cause=%s"
                       % (ts_utc(now), s["id"], cause))
    else:
        append_handoff("session-drop | %s | supervision|%s | dead: stalled "
                       "past 2 ticks cause=%s"
                       % (ts_utc(now), s["id"], cause))
    report("alert", text, "supervision:%s:stalled" % s["id"], "604800")


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


def parse_results_crumbs(text):
    """overnight-done rows → [['ok'], ['failed', ...]] results lists
    (rule ported verbatim from the retired beat-watchdog.py)."""
    rows = []
    for ln in text.splitlines():
        m = re.search(r"results=([\w,]*)", ln)
        if m:
            rows.append(m.group(1).split(",") if m.group(1) else [])
    return rows


def trailing_failures(crumbs):
    """Consecutive 'failed' results from the end, across rows."""
    n = 0
    for row in reversed(crumbs):
        for r in reversed(row):
            if r == "failed":
                n += 1
            else:
                return n
    return n


def parse_dead_rows(text):
    """overnight-lead death rows → [(slug, cause)] — the legacy shape
    scripts/overnight-cycle.sh writes; run-N and this tick's omp sids
    both parse (relaxed fourth-field regex)."""
    rows = []
    for ln in text.splitlines():
        if not ln.startswith("overnight-lead | ") or " dead" not in ln:
            continue
        m = re.search(
            r"overnight-lead \| \S+ \| ([^|]+)\|([^|]+) \|", ln)
        c = re.search(r"cause=([\w-]+)", ln)
        if m and c:
            rows.append((m.group(1).strip(), c.group(1)))
    return rows


def trailing_same_cause(rows):
    """(slug, cause, n) for the trailing run of identical-cause deaths
    of one slug (rule ported verbatim)."""
    for i in range(len(rows)):
        slug, cause = rows[i]
        if all(s == slug and c == cause for s, c in rows[i + 1:]):
            return slug, cause, len(rows) - i
    return None


def beat_silence(text, now, hours):
    """True when the newest overnight-done crumb is >= `hours` old AND
    a later cadence tick exists (the beat is silent, not just idle).
    Timestamps parse from the row's first field via _iso_ts (UTC) —
    TZ-proof."""
    done, ticked_after = [], []
    for ln in text.splitlines():
        t = _iso_ts(ln.split(" | ", 1)[0].strip())
        if t is None:
            continue
        if "overnight-done" in ln:
            done.append(t)
        else:
            ticked_after.append(t)
    if not done:
        return False
    newest = max(done)
    return (now - newest >= hours * 3600
            and any(t > newest for t in ticked_after))


def blocker_row(scope):
    """Existing beat-blockers.tsv row for scope (second-field match:
    col0 is the blk- id, col1 the scope)."""
    try:
        with open(BLOCKERS, encoding="utf-8", errors="replace") as fh:
            for ln in fh:
                f = ln.rstrip("\n").split("\t")
                if len(f) > 1 and f[1].strip() == scope:
                    return f
    except OSError:
        pass
    return None


def append_blocker(scope, cause, active):
    """One beat-blockers.tsv row: id,scope,cause,first-seen,attempts,state."""
    try:
        with open(BLOCKERS, "a", encoding="utf-8") as f:
            f.write("%s\t%s\t%s\t%s\t%s\t%s\n" % (
                "blk-%s-%s" % (time.strftime("%Y%m%d", time.gmtime()),
                               re.sub(r"[^\w-]+", "-", scope)),
                scope, cause, ts_utc(), 1,
                "active" if active else "parked"))
    except OSError:
        pass


def crumbs_state_text():
    """Crumbs journal as text via lib/crumbs-db.py export — the
    overnight-lead silence rule's source. Fail-closed: '' on any fault."""
    try:
        p = subprocess.run(
            [sys.executable, CRUMBS_DB_PY, "export", "--db", CRUMBS_DB],
            capture_output=True, text=True, timeout=60)
        if p.returncode != 0:
            return ""
        return p.stdout or ""
    except Exception:
        return ""


def overnight_lead_checks(now):
    """The virtual `overnight-lead` session: beat-watchdog.py rules
    folded in (file retired 2026-09-25). (a) launch-plane stall —
    trailing failed overnight results >= beat-stall-n; (b) trailing
    same-cause deaths >= blocker-escalate-n — one beat-blockers.tsv
    row, parked; (c) beat silence — newest overnight-done older than
    beat-stall-silence-hours while cadence ticks kept arriving.
    Existing blocker rows silence their rule until cleared by hand."""
    try:
        with open(HANDOFFS, encoding="utf-8", errors="replace") as fh:
            handoffs = fh.read()
    except OSError:
        handoffs = ""
    state_text = crumbs_state_text()
    dets = []
    if trailing_failures(parse_results_crumbs(state_text)) \
            >= int(get_param("beat-stall-n", 4)):
        dets.append(("overnight", "bad-execution", 1, False,
                     "supervision:overnight-lead:launch-stall"))
    sc = trailing_same_cause(parse_dead_rows(handoffs))
    if sc:
        slug, cause, n = sc
        if n >= int(get_param("blocker-escalate-n", 3)):
            dets.append((slug, cause, n, True,
                         "supervision:overnight-lead:same-cause:%s" % cause))
    if beat_silence(state_text, now,
                    float(get_param("beat-stall-silence-hours", 12))):
        dets.append(("overnight-silence", "bad-execution", 1, False,
                     "supervision:overnight-lead:silence"))
    for scope, cause, attempts, active, ident in dets:
        if blocker_row(scope):
            continue
        append_blocker(scope, cause, active)
        report("alert",
               "overnight-lead orchestrator stall: scope=%s cause=%s "
               "attempts=%s%s" % (scope, cause, attempts,
                                  "" if active else " — parked"),
               ident, "604800")


def report(kind, text, identity, window):
    """report-queue add (lib/report_queue.py); any fault is silent
    (advisory, fail-closed)."""
    report_queue.report(kind, text, identity, window, binary=REPORT_QUEUE)


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
                    report("progress",
                           "agent-supervision: evicted-stale %s (idle %s)"
                           % (s["id"], fmt_age(tool_age_min)),
                       "supervision-evicted:%s" % s["id"], "604800")
                state[s["id"]] = {
                    "last_size": s["size"],
                    "last_toolcalls": s["toolcalls"],
                    "first_seen": prev.get("first_seen", int(now)),
                    "last_phase": "evicted",
                    "misses": 0,
                    "sup_state": "evicted",
                }
                continue
            if s.get("exited"):
                # terminal before the evidence machine: exited sessions are
                # dead, never stalled/slow-valid, never flagged again
                state[s["id"]] = {
                    "last_size": s["size"],
                    "last_toolcalls": s["toolcalls"],
                    "first_seen": prev.get("first_seen", int(now)),
                    "last_phase": "terminal",
                    "misses": 0,
                    "sup_state": "terminal",
                }
                continue
            quiet_min = max(0, (now - s["last_entry_ts"]) / 60.0)
            if (s.get("source") != "bridge"
                    and awaiting_stall(s.get("asks"), quiet_min,
                                       s["nonterminal"])):
                phase = "stalled"
            else:
                phase = classify(s["entries"], s["toolcalls"], prior_tools,
                                 s["size"], prior_size, unchanged_min,
                                 tool_age_min, s["nonterminal"])
            # evidence machine (P4): steer-once-then-die on missed ticks,
            # slow-valid one-row advisory on flat tool-calls, else active
            ev_age_s = max(0, now - s["last_entry_ts"])
            stuck = bool(s.get("loop_sig") or s.get("err_sig"))
            miss = ev_age_s > ACTIVE_S and not stuck
            tool_flat = (s["last_tool_ts"] is not None
                         and tool_age_min is not None
                         and tool_age_min > STALL_TOOLCALL_MIN)
            if stuck:
                # loop re-queue (refoundation P7c): a live looping
                # session was exempt from the miss machine and minted
                # no row — the loop path owns it now. First stuck tick
                # steers once with cause=repeat-loop; the second
                # consecutive stuck tick dies cause=repeat-loop (rubric:
                # interrupt-and-redirect,
                # docs/records/2026-08-26-loop-recognition.md).
                stuck_misses = int(prev.get("stuck_misses", 0)) + 1
                misses = 0
                if stuck_misses == 1:
                    steer_stalled(s, now, cause="repeat-loop")
                    report("progress",
                           "agent-supervision: re-queue %s cause=repeat-loop"
                           "; rubric: interrupt-and-redirect (docs/records/"
                           "2026-08-26-loop-recognition.md)" % s["id"],
                           "loop-requeue:%s" % s["id"], "86400")
                    try:
                        import crumbs  # journal-only (lib/)
                        crumbs.crumb("supervision", "loop-requeue",
                                     "%s cause=repeat-loop" % s["id"])
                    except Exception:
                        pass
                else:
                    die_session(s, now, cause="repeat-loop")
                sup = "loop"
            elif miss:
                misses = int(prev.get("misses", 0)) + 1
                if misses == 1:
                    steer_stalled(s, now)
                else:
                    die_session(s, now)
                sup = "stalled"
            elif tool_flat:
                misses = 0
                sup = "slow-valid"
                if prev.get("sup_state") != "slow-valid":
                    # one flap row: a long stretch with no NEW tool calls is
                    # legitimate (long-running command), never killed
                    report("progress",
                           "agent-supervision: %s slow-valid (last tool-call "
                           "%s ago) — re-queue at a cheaper tier if it "
                           "persists" % (s["id"], fmt_age(tool_age_min)),
                           "supervision:%s:slow-valid" % s["id"], "604800")
            else:
                misses = 0
                sup = "active"
                if prev.get("sup_state") in ("stalled", "slow-valid", "loop"):
                    # recovery: progress resumed — one flap row
                    report("progress", "agent-supervision: %s recovered"
                           % s["id"],
                           "supervision:%s:recovered" % s["id"], "604800")
            state[s["id"]] = {
                "last_size": s["size"],
                "last_toolcalls": s["toolcalls"],
                "first_seen": prev.get("first_seen", int(now)),
                "last_phase": phase,
                "misses": misses,
                "stuck_misses": stuck_misses if stuck else 0,
                "sup_state": sup,
            }
        except Exception:
            continue  # one bad session never takes the tick down
    overnight_lead_checks(now)
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
    # ported watchdog rules (folded 2026-09-25)
    assert errish("boom\nTraceback (most recent call last)") is True
    assert errish("all green, 3 files changed") is False
    assert trailing_failures([["ok"], ["failed", "failed"], ["failed"]]) == 3
    assert trailing_failures([["ok"], ["failed"], ["ok"]]) == 0
    assert trailing_same_cause([("s", "x"), ("s", "x")]) == ("s", "x", 2)
    assert trailing_same_cause([("s", "x"), ("s", "y")]) == ("s", "y", 1)
    assert trailing_same_cause([]) is None
    assert parse_dead_rows(
        "overnight-lead | 2026-09-25T00:00:00Z | slug-a|run-1 | "
        "rc=1 dead cause=bad-execution\n"
        "overnight-lead | 2026-09-25T01:00:00Z | slug-a|omp-abc-1f2e3d | "
        "dead: stalled past 2 ticks cause=bad-execution") == [
        ("slug-a", "bad-execution"), ("slug-a", "bad-execution")]
    now = time.time()
    old = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now - 13 * 3600))
    fresh = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now - 120))
    assert beat_silence("%s | overnight-cycle.sh | overnight-done | "
                        "results=ok\n" % old, now, 12.0) is False
    assert beat_silence("%s | overnight-cycle.sh | overnight-done | "
                        "results=ok\n%s | cadence-10m | mounted | tier beat\n"
                        % (old, fresh), now, 12.0) is True
    print("selfcheck ok: 7 fixtures + folded-rule asserts, phases %s"
          % sorted(set(phases)))


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
            # P4 seams: hermetic ledger/blockers/params/crumbs (params file
            # absent -> code defaults); record receipt doubles as the log
            # classify_cause reads
            "SUPERVISION_HANDOFFS": os.path.join(td, "agent-handoffs.md"),
            "SUPERVISION_BLOCKERS": os.path.join(td, "beat-blockers.tsv"),
            "SUPERVISION_PARAMS": os.path.join(td, "cadence-params.tsv"),
            "HNGH_CRUMBS_DB": os.path.join(td, "crumbs.db"),
            "SUPERVISION_CAUSES_SH": os.path.join(td, "no-causes.sh"),
        })
        for _ in range(2):  # tick 1 steers; tick 2 dies
            subprocess.run([sys.executable, os.path.abspath(__file__)],
                           env=env, capture_output=True, text=True,
                           timeout=120)
        log = open(argv_log).read()
        assert "close-run run-1 dead" in log, log
        assert log.count("--run-start") == 1, log
        assert "auto-replace" in log, log
        assert "supervision:run-1:stalled" in log, log
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
