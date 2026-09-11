#!/usr/bin/env python3
"""beat-watchdog — orchestrator-level stall detector (as-above-so-below,
2026-09-11). The run domain models a stall as a dead run routed through
the bestiary; this is the same recognition at the orchestrator's own
level, over the records it already writes (no new daemon — mounted from
the 30m tier, cadence/30m/46-beat-watchdog.sh):

  (a) launch-plane stall: >= beat-stall-n consecutive `failed` tokens in
      STATE.md overnight-done breadcrumbs (results=failed,failed,... —
      the 2026-09-11 signature looked like ordinary degradation for 12h)
  (b) same-cause deaths: a plan/lane with >= blocker-escalate-n
      consecutive `overnight-lead ... dead ... cause=<same class>` rows
      in agent-handoffs.md -> escalation to parked
  (c) beat silence: newest overnight-done crumb older than
      beat-stall-silence-hours while cadence ticks kept arriving (the
      12h signature of the motivating incident)

On detection: one report-queue alert (identity beat-stall:<scope>) plus
a durable row in state/beat-blockers.tsv (the blocker ledger, written
via the same format lib/beat-blockers.sh owns). Rows the beat itself
already owns (a cycle-created row for that slug) are never touched here.
Fail-first on the detector itself: any fault exits 0 and breaks nothing.
"""
import os
import re
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STATE_FILE = os.environ.get("BEAT_STATE_FILE", os.path.join(ROOT, "STATE.md"))
HANDOFFS = os.environ.get("BEAT_HANDOFFS", os.path.join(ROOT, "agent-handoffs.md"))
BLOCKERS = os.environ.get("BEAT_BLOCKERS_FILE", os.path.join(ROOT, "state", "beat-blockers.tsv"))
PARAMS = os.path.join(ROOT, "cadence-params.tsv")
REPORT_QUEUE = os.environ.get(
    "REPORT_QUEUE_BIN", os.path.join(ROOT, "scripts", "report-queue"))


def get_param(key, default):
    """cadence-params.tsv row value (fail-open to the default)."""
    try:
        with open(PARAMS, encoding="utf-8", errors="replace") as fh:
            for ln in fh:
                f = ln.rstrip("\n").split("\t")
                if f and f[0] == key and len(f) > 1 and f[1]:
                    return f[1]
    except OSError:
        pass
    return str(default)


def parse_results_crumbs(state_text):
    """overnight-done detail tokens, chronological: [[ok,failed,...], ...]"""
    out = []
    for ln in state_text.splitlines():
        if "| overnight-done |" not in ln:
            continue
        m = re.search(r"results=([\w,]*)", ln)
        out.append([t for t in (m.group(1).split(",") if m else []) if t])
    return out


def trailing_failures(crumbs):
    """Consecutive `failed` tokens counting backwards across beats."""
    n = 0
    for row in reversed(crumbs):
        for tok in reversed(row):
            if tok != "failed":
                return n
            n += 1
    return n


def parse_dead_rows(handoffs_text):
    """[(slug, cause)] from `overnight-lead | ts | slug|run | rc=N dead ... cause=X`."""
    out = []
    for ln in handoffs_text.splitlines():
        if not ln.startswith("overnight-lead |"):
            continue
        if " dead " not in ln:
            continue
        m = re.match(r"overnight-lead \| \S+ \| ([^|]+)\|run-\d+ \|", ln)
        c = re.search(r"\bcause=([\w-]+)", ln)
        if m and c:
            out.append((m.group(1).strip(), c.group(1)))
    return out


def trailing_same_cause(dead_rows):
    """slug -> (cause, n) longest trailing same-cause run (pure — test table)."""
    best = {}
    for slug, cause in dead_rows:
        prev = best.get(slug)
        best[slug] = (cause, prev[1] + 1) if prev and prev[0] == cause else (cause, 1)
    return best


def _ts_epoch(s):
    """ISO UTC breadcrumb timestamp -> epoch seconds, or None."""
    try:
        return time.mktime(time.strptime(s, "%Y-%m-%dT%H:%M:%SZ")) - time.timezone
    except ValueError:
        return None


def beat_silence(state_text, now_s, silence_hours):
    """True when the newest overnight-done predates the silence window
    AND cadence ticks kept arriving after it (rule c — the 12h signature)."""
    newest = None
    for ln in state_text.splitlines():
        if "| overnight-done |" not in ln:
            continue
        ts = ln.split(" | ")[0].strip()
        e = _ts_epoch(ts)
        if e is not None and (newest is None or e > newest):
            newest = e
    if newest is None:
        return False
    later_tick = False
    for ln in state_text.splitlines():
        e = _ts_epoch(ln.split(" | ")[0].strip())
        if e is not None and e > newest:
            later_tick = True
            break
    return later_tick and (now_s - newest) >= silence_hours * 3600


def detect(state_text, handoffs_text, now_s=None, stall_n=None, escalate_n=None):
    """Pure rule pass -> [(scope, cause, attempts, parked)]."""
    now_s = time.time() if now_s is None else now_s
    stall_n = int(get_param("beat-stall-n", 3)) if stall_n is None else stall_n
    escalate_n = int(get_param("blocker-escalate-n", 2)) if escalate_n is None else escalate_n
    silence_h = float(get_param("beat-stall-silence-hours", 6))
    out = []
    # (a) launch-plane stall: the orchestrator did the thing wrong
    if trailing_failures(parse_results_crumbs(state_text)) >= stall_n:
        out.append(("overnight", "bad-execution", 1, False))
    # (b) same-cause deaths at plan level (respawn-guard semantics)
    for slug, (cause, n) in sorted(trailing_same_cause(parse_dead_rows(handoffs_text)).items()):
        if n >= escalate_n:
            out.append((slug, cause, n, True))
    # (c) beat silence: cadence ticks alive, overnight beats dead
    if beat_silence(state_text, now_s, silence_h):
        out.append(("overnight-silence", "bad-execution", 1, False))
    return out


def report_alert(text, scope):
    """report-queue alert; any fault is silent (advisory, fail-closed)."""
    try:
        subprocess.run(
            [REPORT_QUEUE, "--add", "alert", text,
             "--identity", "beat-stall:" + scope, "--window", "604800"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=30)
    except (OSError, subprocess.SubprocessError):
        pass


def blocker_row(scope):
    if not os.path.isfile(BLOCKERS):
        return None
    with open(BLOCKERS, encoding="utf-8", errors="replace") as fh:
        for ln in fh:
            f = ln.rstrip("\n").split("\t")
            if len(f) > 1 and f[1] == scope:
                return f
    return None


def apply(detections):
    """Alert + durable row per detection. Rows the overnight beat already
    owns (a cycle-created row for that slug) are never touched here — the
    remediation loop in overnight-cycle.sh owns attempts for those."""
    os.makedirs(os.path.dirname(BLOCKERS), exist_ok=True)
    for scope, cause, attempts, parked in detections:
        if blocker_row(scope) is not None:
            continue
        ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        bid = "blk-" + time.strftime("%Y%m%d", time.gmtime()) + "-" + \
            re.sub(r"[^a-zA-Z0-9._-]", "-", scope)
        with open(BLOCKERS, "a", encoding="utf-8") as fh:
            fh.write("\t".join([bid, scope, cause, ts, str(attempts),
                                "parked" if parked else "active"]) + "\n")
        report_alert(
            "orchestrator stall detected: scope=%s cause=%s attempts=%s%s"
            % (scope, cause, attempts, " - parked for operator" if parked else ""),
            scope)


def run(now_s=None):
    with open(STATE_FILE, encoding="utf-8", errors="replace") as fh:
        state_text = fh.read()
    try:
        with open(HANDOFFS, encoding="utf-8", errors="replace") as fh:
            handoffs_text = fh.read()
    except OSError:
        handoffs_text = ""
    apply(detect(state_text, handoffs_text, now_s=now_s))


if __name__ == "__main__":
    # fail-first on the detector itself: a detector crash must never break
    # the tick — every fault exits 0 quietly
    try:
        run()
    except Exception as exc:  # noqa: BLE001 — the tick must survive us
        print("beat-watchdog: suppressed %s" % exc, file=sys.stderr)
    sys.exit(0)