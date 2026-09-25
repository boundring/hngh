#!/usr/bin/env python3
"""router-tick — route one alert occurrence to a plan candidate.

Implements the "Outcome tracking without kernel changes (2026-08-31)"
contract (hngh docs/research/2026-08-30-alert-to-work-routing-patterns-
closing-the-self-observation-loop.md, fields 1/2/6):

- pre-check before any report-queue --add: the same two greps the
  overnight selector uses (status=accepted front-matter, an unchecked
  `- [ ]` step); when the identity's named step is closed, skip the
  candidate add and file exactly one observable pair — a crumbs-journal
  breadcrumb `router | duplicate-skip | <identity> step already closed`
  plus a deduped alert row --identity router:dup-skip:<identity>
  --window 86400 (this is router-rearm-precheck's parked "one
  closed-step re-fire is demonstrably skipped");
- first fire (identity names no plan): check the plans dir for an
  existing routed plan with the same subject slug (any date prefix)
  that is non-terminal (not executed/rejected) and younger than the
  dedup window (HNGH_ROUTER_DEDUP_HOURS, default 12h). A live
  duplicate suppresses the candidate — the plan queue stays clean
  while the alert row still lands in reports.md — and counts the
  suppression in a crumbs-journal `router | plan-dedup` crumb; >=3 dedups
  in one day escalate a row to operator visibility once/day
  (loop-recognition lesson: a stuck loop must be visible, not
  silently swallowed). Terminal or window-aged candidates route
  fresh (suffixed slug, never an overwrite).
- first fire with no live duplicate: draft a routed candidate — a
  status=proposed plan file, front-matter tagged routed-from=<identity>
  (both parsers tolerate the trailing attribute: accept-plans.py:32-33,
  jobs/plan-feed.py:21-22) — and file the routed-at progress row
  --identity router:routed:<slug> --window 86400;
- critical classes park with an operator-facing alert, never a candidate.

Identity grammar (routing doc, thread 2): <class>[:...]:plan:<slug>[:step-N]
names a plan step; anything else is a first fire. No router-internal
state: the skip decision is re-derived from the plan file each run.
"""
import os
import re
import sqlite3
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone

sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
import crumbs  # the single STATE.md crumb writer (lib/crumbs.py)
import report_queue  # the shared report-queue row shim (lib/report_queue.py)

KERNEL = os.environ.get(
    "HNGH_HOME", os.path.expanduser("~/Projects/etc/hngh"))
AUTOMATION = os.environ.get(
    "HNGH_AUTOMATION_ROOT",
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PLANS = os.path.join(KERNEL, "docs", "project", "plans")
CRUMBS_DB = os.environ.get(
    "HNGH_CRUMBS_DB", os.path.join(AUTOMATION, "state", "crumbs.db"))
REPORT_QUEUE = os.environ.get(
    "HNGH_REPORT_QUEUE", os.path.join(KERNEL, "scripts", "report-queue"))
REPORT_ROOT = os.environ.get("HNGH_REPORT_ROOT", KERNEL)

IDENT_OK = re.compile(r"^[A-Za-z0-9._:-]+$")
STEP_SUFFIX = re.compile(r":step-(\d+)$")
# path-redaction scrub (2026-09-16 risk-dispositions-cred-argv family,
# extended 2026-09-17 GAP E wiki-health-wiring-reconcile::gate):
# pre-2026-09-16 alert identities were not path-redacted, so a dash-
# mangled absolute path ("home-bricker-Projects-...") can ride in through
# IDENT_OK and leak into public plan front-matter, filenames, and rows.
# Raw '/', '~', '$' identities already fail IDENT_OK (fail closed); the
# dash-mangled form is cut at the first pathy-stemmed token. Stems are
# home/Users, the deployment username (config.env seam, never hardcoded:
# HNGH_ROUTER_PATHY_STEMS env overrides the config default), 'tmp', and
# 'root'. A second token-level heuristic catches manglers that consumed
# the home/username segment upstream: a token whose dash-segments hit
# TWO consecutive PATH_COMPONENTS (repeated fragment or adjacent known
# component) is path-derived. False positives only truncate a subject
# word; false negatives would leak.
#
# 2026-09-17 single-source re-point: the dash-form stem family and the
# env seam live in lib/scrub.py (PATHY_STEMS / pathy_stems / 
# scrub_truncate_pathy) so the research id seams share the exact
# mechanism; PATHY_STEMS below is imported, not redefined. The
# PATH_COMPONENTS heuristic stays router-local (plan-class identity
# grammar is a router concern).
import importlib.util as _ilutil

_scrub_spec = _ilutil.spec_from_file_location(
    "hngh_scrub_router",
    os.path.join(os.path.dirname(os.path.dirname(
        os.path.abspath(__file__))), "lib", "scrub.py"))
_scrub_mod = _ilutil.module_from_spec(_scrub_spec)
_scrub_spec.loader.exec_module(_scrub_mod)
PATHY_STEMS = _scrub_mod.PATHY_STEMS
pathy_stems = _scrub_mod.pathy_stems
scrub_truncate_pathy = _scrub_mod.scrub_truncate_pathy
PATH_COMPONENTS = ("projects", "etc", "hngh", "dropbox", "documents",
                   "downloads", "desktop", "config", "src", "lib", "bin",
                   "docs", "tests", "opt", "usr", "var")
# username stem default lives in automation/config.env:
#   HNGH_ROUTER_PATHY_STEMS="${HNGH_ROUTER_PATHY_STEMS:-<username>}"
# (deployment data; tests override via the env var and stay hermetic).


def _token_two_consecutive_components(seg):
    """True when the token's dash-segments contain two CONSECUTIVE
    path-derived fragments: a repeated component ("Projects-etc") or
    two distinct PATH_COMPONENTS in a row. One fragment alone never
    trips it, so innocuous subject words pass."""
    parts = [p.lower() for p in seg.split("-") if p]
    for a, b in zip(parts, parts[1:]):
        if a == b and a in PATH_COMPONENTS:
            return True
        if a in PATH_COMPONENTS and b in PATH_COMPONENTS:
            return True
    return False


def scrub_pathy_identity(identity):
    """Scrub dash-mangled path fragments from an already-IDENT_OK
    identity so no path-derived token reaches the routed slug, plan
    front-matter, or progress-row identities. Returns None when the
    whole identity is path-derived (caller refuses it, fail closed)."""
    stems = pathy_stems()
    tokens = identity.split(":")
    if tokens[0].split("-", 1)[0].lower() in stems:
        return None
    for i, tok in enumerate(tokens):
        first = tok.split("-", 1)[0].lower()
        if i and (first in stems
                  or _token_two_consecutive_components(tok)):
            return ":".join(tokens[:i])
    return identity


# routing table (routing doc "Recommendation"): class key -> candidate shape
CRITICAL_KEYS = ("remote-posture", "budget")
NORMAL_SHAPES = [
    ("gate", ("Re-run the named gate, capture the failing check, fix or park",
              "both `make test` gates green; failing check captured")),
    ("tree-skew", ("Whitelist check + handoff/commit of the stalled edit",
                   "dirty-tree whitelist clean; stalled edit committed or handed off")),
    (("agent-stall", "loop-signal"),
     ("Stop the stalled session, write a handoff brief (last state + next "
      "action), start the replacement",
      "old session id gone from supervision state; handoff brief file "
      "exists; replacement session shows fresh tool activity")),
    (("ceremony-temp", "store"),
     ("Re-run the ceremony with a fresh per-run store (known recovery)",
      "ceremony completes rc=0 from a fresh /tmp/hngh-cer-* store")),
    ("review", ("Fix the review finding in docs/automation with a named verification",
                "the finding's own check passes; `make test` green")),
    ("readout", ("Feed-regen re-read step (fix already landed as precedent)",
                 "readout.json regenerates and parses")),
]
TERMINAL_STATUS = ("executed", "rejected")


def now_utc():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def breadcrumb(job, event, detail):
    """Crumbs journal row via the single writer (lib/crumbs.py), 4-field
    format identical to lib/breadcrumbs.sh."""
    if os.environ.get("DRY_RUN") == "1":
        print("[dry-run] crumb %s|%s|%s" % (job, event, detail))
        return
    crumbs.crumb(job, event, crumbs.scrub(detail))


def report(kind, text, ident, window):
    """File one report-queue row (lib/report_queue.py); a lost row must
    not block the tick."""
    if os.environ.get("DRY_RUN") == "1":
        print("[dry-run] row %s|%s|%s|%s" % (kind, text, ident, window))
        return
    report_queue.report(kind, text, ident, window,
                        binary=REPORT_QUEUE, root=REPORT_ROOT)


def ttl_s():
    """Routed-candidate TTL seconds before an unaccepted candidate is
    marked expired: env HNGH_ROUTER_TTL_HOURS, then the cadence-params
    row routed-candidate-ttl-hours, else 24h (env->tsv->default)."""
    v = os.environ.get("HNGH_ROUTER_TTL_HOURS")
    if not v:
        try:
            with open(os.path.join(AUTOMATION, "cadence-params.tsv"),
                      encoding="utf-8") as fh:
                for line in fh:
                    if line.startswith("#"):
                        continue
                    parts = line.rstrip("\n").split("\t")
                    if len(parts) > 1 and parts[0] == \
                            "routed-candidate-ttl-hours":
                        v = parts[1]
                        break
        except OSError:
            pass
    try:
        return max(0.0, float(v)) * 3600.0
    except (TypeError, ValueError):
        return 24 * 3600.0


def mark_expired(path, text):
    """Header rewrite status=<x> -> status=expired (plan file kept:
    plans are ceremony artifacts); atomic, mtime preserved."""
    st = os.stat(path)
    new = re.sub(r"(?<![\w-])status=\w+", "status=expired", text[:400],
                 count=1) + text[400:]
    tmp = tempfile.NamedTemporaryFile("w", delete=False, dir=PLANS,
                                      suffix=".tmp", encoding="utf-8")
    tmp.write(new)
    tmp.close()
    os.replace(tmp.name, path)
    os.utime(path, (st.st_atime, st.st_mtime))


def expire_stale_candidates(identity):
    """Expire every non-terminal routed candidate for this identity
    older than ttl_s(); files one router:routed-expired row per run
    (unlimited lookback -> later repeats never add rows). Returns the
    (slug, age_s, text) of the oldest expired candidate, else None."""
    ident = re.sub(r"[^A-Za-z0-9._-]+", "-", identity)
    dup_re = re.compile(r"^\d{4}-\d{2}-\d{2}-routed-%s(-\d+)?\.plan\.md$"
                        % re.escape(ident))
    ttl = ttl_s()
    oldest = None
    try:
        names = os.listdir(PLANS)
    except OSError:
        return None
    expired_any = False
    for name in names:
        if not dup_re.match(name):
            continue
        path = os.path.join(PLANS, name)
        try:
            with open(path, encoding="utf-8") as fh:
                text = fh.read()
        except OSError:
            continue
        m = re.search(r"(?<![\w-])status=(\w+)", text[:400])
        status = m.group(1) if m else "proposed"
        age = max(0.0, time.time() - os.path.getmtime(path))
        if status in TERMINAL_STATUS or status == "accepted":
            continue  # execution supply or disposed: never expired
        if age < ttl and status != "expired":
            continue
        if status != "expired":
            mark_expired(path, text)
            expired_any = True
        elif age < ttl:
            continue
        if oldest is None or age > oldest[1]:
            oldest = (name[:-8], age)
    if expired_any or oldest:
        # expiry itself must be visible; --window 0 keeps it one row
        report("alert", "router expired candidate %s (unaccepted %dh past "
               "routing; identity %s)" % (oldest[0] if oldest else "?",
                                          int(ttl // 3600), identity),
               "router:routed-expired:%s" % (oldest[0] if oldest else ident),
               0)
    return oldest


def dedup_window_s():
    """Dedup window seconds: HNGH_ROUTER_DEDUP_HOURS (default 12h)."""
    try:
        return abs(float(os.environ.get("HNGH_ROUTER_DEDUP_HOURS", "12"))) \
            * 3600.0
    except ValueError:
        return 12 * 3600.0


def plan_status_age(path):
    """(status, age_seconds) for a plan file; (None, None) unreadable."""
    try:
        with open(path, encoding="utf-8") as fh:
            m = re.search(r"status=(\w+)", fh.read(400))
        return ((m.group(1) if m else None),
                max(0.0, time.time() - os.path.getmtime(path)))
    except OSError:
        return None, None


def live_duplicate(identity, window_s):
    """Newest routed plan for this subject (any route suffix -N, across
    all date prefixes) that is non-terminal AND younger than window_s,
    else None — a duplicate candidate would only re-pollute the plan
    queue."""
    ident = re.sub(r"[^A-Za-z0-9._-]+", "-", identity)
    dup_re = re.compile(r"^\d{4}-\d{2}-\d{2}-routed-%s(-\d+)?\.plan\.md$"
                        % re.escape(ident))
    best = None
    try:
        names = os.listdir(PLANS)
    except OSError:
        return None
    for name in names:
        if not dup_re.match(name):
            continue
        path = os.path.join(PLANS, name)
        status, age = plan_status_age(path)
        if status in TERMINAL_STATUS or age is None or age >= window_s:
            continue  # terminal or window-aged: the alert routes fresh
        if best is None or age < best[1]:
            best = (name[:-8], age)
    return best


def dedup_count_today(identity):
    """Dedup occurrences for this identity today, including the one being
    decided — crumbs journal rows are the only counter (no router-internal
    state; the skip decision re-derives from files each run)."""
    today = now_utc()[:10]
    n = 1
    try:
        conn = sqlite3.connect("file:%s?mode=ro" % CRUMBS_DB, uri=True,
                               timeout=5)
        try:
            for ts, job, event, detail, writer in conn.execute(
                    "SELECT ts, job, event, detail, writer FROM crumbs"
                    " WHERE ts LIKE ? || '%'", (today,)):
                line = "%s | %s | %s | %s" % (
                    ts, job, event,
                    detail + (" [w=%s]" % writer if writer else ""))
                if "plan-dedup" in line and identity in line:
                    n += 1
        finally:
            conn.close()
    except sqlite3.Error:
        pass
    return n


def escalate_n():
    """Occurrence threshold before a zero-progress plan parks: env
    HNGH_ROUTER_ESCALATE_N, then the cadence-params.tsv inventory row,
    else 3 (same env->tsv->default pattern as jobs/research-feed.py)."""
    v = os.environ.get("HNGH_ROUTER_ESCALATE_N")
    if not v:
        try:
            with open(os.path.join(AUTOMATION, "cadence-params.tsv"),
                      encoding="utf-8") as fh:
                for line in fh:
                    if line.startswith("#"):
                        continue
                    parts = line.rstrip("\n").split("\t")
                    if len(parts) > 1 and parts[0] == "router-escalate-n":
                        v = parts[1]
                        break
        except OSError:
            pass
    try:
        return max(1, int(float(v)))
    except (TypeError, ValueError):
        return 3


def router_reroute_max():
    """Re-route bound for one identity: env HNGH_ROUTER_REROUTE_MAX,
    then the cadence-params.tsv row router-reroute-max, else 3 (same
    env->tsv->default pattern as escalate_n)."""
    v = os.environ.get("HNGH_ROUTER_REROUTE_MAX")
    if not v:
        try:
            with open(os.path.join(AUTOMATION, "cadence-params.tsv"),
                      encoding="utf-8") as fh:
                for line in fh:
                    if line.startswith("#"):
                        continue
                    parts = line.rstrip("\n").split("\t")
                    if len(parts) > 1 and parts[0] == "router-reroute-max":
                        v = parts[1]
                        break
        except OSError:
            pass
    try:
        return max(1, int(float(v)))
    except (TypeError, ValueError):
        return 3


def chain_live_count(identity):
    """Unworked chain members for this identity (any date, any route
    suffix - the same dup_re shape live_duplicate/expire_stale use).
    Everything except executed/rejected counts: parked and expired
    corpses must be visible here, or the corpse loop walks past the
    bound."""
    ident = re.sub(r"[^A-Za-z0-9._-]+", "-", identity)
    dup_re = re.compile(r"^\d{4}-\d{2}-\d{2}-routed-%s(-\d+)?\.plan\.md$"
                        % re.escape(ident))
    n = 0
    try:
        names = os.listdir(PLANS)
    except OSError:
        return 0
    for name in names:
        if not dup_re.match(name):
            continue
        status, _ = plan_status_age(os.path.join(PLANS, name))
        if status not in TERMINAL_STATUS:
            n += 1
    return n


def occurrence_count(text):
    """Distinct occurrence lines in the plan's `## Occurrences`
    escalation record (0 when the section is absent)."""
    sec = text.split("## Occurrences", 1)
    sec = sec[1].split("\n## ", 1)[0] if len(sec) > 1 else ""
    return len(re.findall(r"(?m)^- ", sec))


def bump_occurrences(path, text):
    """Append one occurrence line to the plan's `## Occurrences`
    section (created at the end of the file when absent); atomic.
    mtime is preserved: the dedup window ages on original routing
    time, recurrences live in the occurrence timestamps."""
    st = os.stat(path)
    line = "- %s re-occurred (dedup window expired)" % now_utc()
    if "## Occurrences" in text:
        head, rest = text.split("## Occurrences", 1)
        nxt = rest.split("\n## ", 1)
        tail = nxt[0].rstrip("\n") + "\n" + line + "\n"
        if len(nxt) > 1:
            tail += "\n## " + nxt[1]
        new = head + "## Occurrences" + tail
    else:
        new = text.rstrip("\n") + "\n\n## Occurrences\n\n" + line + "\n"
    tmp = tempfile.NamedTemporaryFile("w", delete=False, dir=PLANS,
                                      suffix=".tmp", encoding="utf-8")
    tmp.write(new)
    tmp.close()
    os.replace(tmp.name, path)
    os.utime(path, (st.st_atime, st.st_mtime))


def step_states(text):
    """(closed, open) counts of `## Steps` checkbox lines."""
    sec = text.split("## Steps", 1)
    sec = sec[1].split("\n## ", 1)[0] if len(sec) > 1 else ""
    starts = re.findall(r"(?m)^- \[[ x]\]", sec)
    return (starts.count("- [x]"), starts.count("- [ ]"))


def named_step_closed(text, n):
    """True when step n (1-based) exists and is `- [x]`."""
    sec = text.split("## Steps", 1)
    sec = sec[1].split("\n## ", 1)[0] if len(sec) > 1 else ""
    starts = [ln for ln in sec.splitlines()
              if ln.startswith("- [ ]") or ln.startswith("- [x]")]
    return 0 < n <= len(starts) and starts[n - 1].startswith("- [x]")


def shape_for(identity):
    """Routing-table candidate shape for an alert identity."""
    low = identity.lower()
    if any(k in low for k in CRITICAL_KEYS):
        return None  # critical parks, per the plan contract
    for keys, shape in NORMAL_SHAPES:
        if isinstance(keys, str):
            keys = (keys,)
        if any(k in low for k in keys):
            # knowledge-shaped: re-running the gate without new knowledge
            # just loops; route to research first (disposition spine)
            if keys == ("gate",) and "tree-skew" not in low:
                return research_shape(identity)
            return shape
    # plan-draft-fail and the generic investigate fallthrough are
    # knowledge-shaped too
    return research_shape(identity)


def research_shape(identity):
    """Research-demand candidate: one Delve step that opens a research
    subject for the alert identity, records its disposition, then fixes
    or parks. The subject id follows the fail-YYYYMMDD-<slug> bestiary
    convention so the session can append it to research-subjects.txt."""
    slug = re.sub(r"[^a-z0-9._-]+", "-", identity.lower()).strip("-")
    sid = "fail-%s-%s" % (now_utc()[:10].replace("-", ""), slug)
    return (
        "Delve: open research subject %s for %s; record disposition; "
        "then fix or park" % (sid, identity),
        "research subject %s present in research-subjects.txt with a "
        "recorded disposition; alert fixed or parked" % sid)


def candidate_text(identity, text, shape, date):
    title, verify = shape
    body = text if text else identity
    return (
        "<!-- plan: status=proposed risk=normal accepted=- "
        "routed-from=%s -->\n"
        "# %s — routed candidate\n"
        "\n"
        "Routed by scripts/router-tick.py from alert identity `%s`\n"
        "at %s. Alert text: %s\n"
        "\n"
        "## Steps\n"
        "\n"
        "- [ ] %s\n"
        "      Verification: %s\n" % (identity, date, identity, now_utc(), body,
                                     title, verify))


def route(identity, text):
    """One alert occurrence -> candidate / dedup / skip pair.
    Returns exit code."""
    if not IDENT_OK.match(identity):
        breadcrumb("router", "no-candidate", "%s identity not routable" % identity)
        return 0
    scrubbed = scrub_pathy_identity(identity)
    if scrubbed is None:
        breadcrumb("router", "no-candidate",
                   "%s identity not routable (path-derived)" % identity)
        return 0
    identity = scrubbed
    if ":plan:" in identity:
        return refire(identity)
    shape = shape_for(identity)
    date = now_utc()[:10]
    slug = "%s-routed-%s" % (date, re.sub(r"[^A-Za-z0-9._-]+", "-", identity))
    if shape is None:  # critical-class: parks, never a machine candidate
        report("alert", "router parks critical-class alert %s for the "
               "operator (candidate never machine-drafted)" % identity,
               "router:parked:%s" % identity, 604800)
        breadcrumb("router", "parked", "%s critical-class parks" % identity)
        return 0
    # expiry runs first: a candidate past its TTL is dead even while a
    # shorter dedup window would still call it live
    dup = expire_stale_candidates(identity)
    if dup is None:
        dup = live_duplicate(identity, dedup_window_s())
    if dup:
        # keep the signal (alert row still lands in reports.md), keep
        # the plan queue clean; >=3 dedups in a day escalate once/day
        dup_slug, age = dup
        dup_path = os.path.join(PLANS, dup_slug + ".plan.md")
        try:
            with open(dup_path, encoding="utf-8") as fh:
                dup_text = fh.read()
        except OSError:
            dup_text = ""
        status = re.search(r"status=(\w+)", dup_text[:400])
        status = status.group(1) if status else "proposed"
        closed_ct, _ = step_states(dup_text)
        # an accepted plan with closed steps is execution supply, not a
        # routing duplicate: leave it alone (refire() owns its steps);
        # only zero-progress candidates accumulate toward the park
        in_progress = status == "accepted" and closed_ct > 0
        disposed = None
        if not in_progress and os.environ.get("DRY_RUN") != "1":
            bump_occurrences(dup_path, dup_text)
            with open(dup_path, encoding="utf-8") as fh:
                occurrences = occurrence_count(fh.read())
            if occurrences >= escalate_n():
                disposed = subprocess.run(
                    [sys.executable,
                     os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                  "plan-dispose.py"),
                     dup_path, "--action", "park", "--cause", "obsolete",
                     "--reason", "identity re-occurred %d times without "
                     "landing; operator escalation stands" % occurrences],
                    env={**os.environ}, capture_output=True, timeout=30)
        count = dedup_count_today(identity)
        if status == "expired":
            # expired candidate whose alert re-fires: escalate
            # immediately (skip remaining suppressions); the alert then
            # routes fresh below
            occ = occurrence_count(dup_text)
            occ_ts = re.findall(
                r"^- (\S+) re-occurred", dup_text, re.M) if occ else []
            oldest = occ_ts[0] if occ_ts else now_utc()
            report("alert", "router escalation: %s re-fired %dx with no "
                   "landing (oldest occurrence %s; candidate %s expired "
                   "after %dh unaccepted)" % (identity, max(occ, 1), oldest,
                                              dup_slug, int(ttl_s() // 3600)),
                   "router:escalated:%s" % identity, 0)
            breadcrumb("router", "escalated",
                       "%s re-fired past expired candidate %s" %
                       (identity, dup_slug))
            dup = None  # route fresh past the corpse
        else:
            report("alert", "router dedup: %s suppressed (routed candidate "
                   "%s still live, %dh old; day count %d)"
                   % (identity, dup_slug, int(age // 3600), count),
                   "router:dedup:%s" % identity, 86400)
            if count >= 3:
                report("alert", "router dedup escalation: %s recurring — "
                       "suppressed %d times today — escalated to operator "
                       "visibility" % (identity, count),
                       "router:dedup-escalated:%s" % identity, 86400)
            breadcrumb("router", "plan-dedup",
                       "%s suppressed (%s live, %dh old); day count %d"
                       % (identity, dup_slug, int(age // 3600), count))
        if disposed is not None and disposed.returncode == 0:
            report("alert", "router escalated: %s re-occurred %d times "
                   "without landing — plan %s parked (cause=obsolete); "
                   "operator disposition stands" % (identity, occurrences,
                                                    dup_slug),
                   "router:parked:%s" % identity, 604800)
            breadcrumb("router", "escalated-park",
                       "%s -> %s parked after %d occurrences"
                       % (identity, dup_slug, occurrences))
        if dup is None:
            # expired-candidate escalation falls through: the alert
            # routes fresh below (past the corpse)
            pass
        else:
            return 0
    # re-route bound: an identity whose chain already holds the bound in
    # unworked members stops minting. The row keeps the lane visible -
    # routed/parked is never reported as resolved.
    bound = router_reroute_max()
    if chain_live_count(identity) >= bound:
        report("alert", "router parks %s at the re-route bound - "
               "SLA: re-fires bump this row for 7d, then it expires on "
               "silence; halt: the lane stops until the identity is "
               "worked or the chain is disposed; re-route bound reached "
               "(%d) - parked, not resolved" % (identity, bound),
               "router:parked:%s" % identity, 604800)
        breadcrumb("router", "reroute-bound",
                   "%s parked at re-route bound %d" % (identity, bound))
        return 0
    path = os.path.join(PLANS, slug + ".plan.md")
    if os.path.exists(path):
        # window-aged same-day plan routes fresh: suffix, never overwrite
        n = 2
        while os.path.exists(os.path.join(
                PLANS, "%s-%d.plan.md" % (slug, n))):
            n += 1
        path = os.path.join(PLANS, "%s-%d.plan.md" % (slug, n))
        slug = os.path.basename(path)[:-8]
    os.makedirs(PLANS, exist_ok=True)
    if os.environ.get("DRY_RUN") == "1":
        print("[dry-run] would draft candidate %s from %s" % (path, identity))
        return 0
    tmp = tempfile.NamedTemporaryFile("w", delete=False, dir=PLANS,
                                       suffix=".tmp", encoding="utf-8")
    tmp.write(candidate_text(identity, text, shape, date))
    tmp.close()
    os.replace(tmp.name, path)
    report("progress", "router routed %s -> plan candidate %s (routed-at %s)"
           % (identity, slug, now_utc()), "router:routed:%s" % slug, 86400)
    breadcrumb("router", "routed", "%s -> %s" % (identity, slug))
    return 0


def refire(identity):
    """Pre-check plan state before any add; skip when the step is closed."""
    _, rest = identity.split(":plan:", 1)
    m = STEP_SUFFIX.search(rest)
    slug, step = (rest[:m.start()], int(m.group(1))) if m else (rest, None)
    path = os.path.join(PLANS, slug + ".plan.md")
    if not os.path.isfile(path):
        breadcrumb("router", "no-candidate", "%s names no plan file" % identity)
        return 0
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    closed_ct, open_ct = step_states(text)
    # the named step is open when it exists unchecked, or (no step
    # number) any `- [ ]` remains — the selector's grep, read directly
    still_open = (not named_step_closed(text, step) if step
                  and step <= closed_ct + open_ct else open_ct > 0)
    if still_open:
        # named step still open: the work is scheduled, no candidate re-draft
        report("progress", "router re-fire of %s (named step still open)"
               % identity, "router:routed:%s%s" %
               (slug, ":step-%d" % step if step else ""), 86400)
        breadcrumb("router", "in-flight", "%s step still open" % identity)
        return 0
    # named step closed (or nothing left): the re-fire is a duplicate —
    # skip the candidate add, file exactly one observable skip pair
    report("alert", "router duplicate-skip: %s (named step closed; "
           "candidate not re-drafted)" % identity,
           "router:dup-skip:%s" % identity, 86400)
    breadcrumb("router", "duplicate-skip", "%s step already closed" % identity)
    return 0


def main():
    args = sys.argv[1:]
    identity = None
    text = ""
    i = 0
    while i < len(args):
        if args[i] == "--identity" and i + 1 < len(args):
            identity = args[i + 1]
            i += 2
        elif args[i] == "--text" and i + 1 < len(args):
            text = args[i + 1]
            i += 2
        else:
            print("usage: router-tick.py --identity ID [--text TEXT]",
                  file=sys.stderr)
            return 2
    if not identity:
        print("usage: router-tick.py --identity ID [--text TEXT]", file=sys.stderr)
        return 2
    return route(identity, text)


if __name__ == "__main__":
    sys.exit(main())
