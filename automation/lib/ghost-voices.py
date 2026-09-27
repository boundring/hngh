#!/usr/bin/env python3
"""ghost-voices.py — ghost pantheon counsel for the digest editorial slot
(course-correction slice 4). Blends three ghosts from
config/ghost-voices.tsv and asks Xiaomi MiMo for one one-shot counsel
sentence. Decoration, not data: every failure path returns None.

Seams (env): HNGH_GHOST_TSV (roster override), HNGH_GHOST_STATE (stamp
dir override), HNGH_GHOST_STUB (canned-answer file; tests), and
HNGH_XIAOMI_CMD (bridge command override). Cap: 6 fresh calls per 24h,
stamp files in ~/.hngh/db/ghost-state/ (hngh_home db_dir contract)."""

import hashlib
import json
import os
import random
import re
import subprocess
import sys
import time
from datetime import datetime, timedelta, timezone

_AUTOMATION = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _AUTOMATION not in sys.path:
    sys.path.insert(0, os.path.join(_AUTOMATION, "lib"))

CAP_CALLS = 6
CAP_WINDOW_S = 86400
STALE_MENTION_RE = re.compile(r"\b(stale|expired|unverified)\b", re.I)
# Default per the two-home layout contract (AGENTS.md): userspace data
# under ~/.hngh/db/. Literal path, not an hngh_home import — py lib
# modules stay stdlib-only (test-lib-dependencies.py py-coupling rule).
DEFAULT_STATE = os.path.join(os.path.expanduser("~"), ".hngh", "db",
                             "ghost-state")


def tsv_path():
    return os.environ.get(
        "HNGH_GHOST_TSV", os.path.join(_AUTOMATION, "config", "ghost-voices.tsv"))


def state_dir():
    p = os.environ.get("HNGH_GHOST_STATE") or DEFAULT_STATE
    os.makedirs(p, exist_ok=True)
    return p


def load_ghosts():
    """Roster -> list of dicts; unknown/malformed lines fail closed."""
    path = tsv_path()
    if not os.path.isfile(path):
        return []
    ghosts = []
    with open(path, encoding="utf-8") as fh:
        for raw in fh:
            line = raw.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) != 4:
                continue  # malformed roster row: skip, never guess
            ghosts.append(
                {"name": parts[0], "era": parts[1],
                 "register": parts[2], "convictions": parts[3]})
    return ghosts


def pick_ghosts(ghosts, seed, n=3):
    """Deterministic distinct blend: sha1(seed) drives a seeded sample."""
    if len(ghosts) < n:
        return []
    digest = hashlib.sha1(seed.encode("utf-8")).hexdigest()
    rng = random.Random(digest)
    return rng.sample(ghosts, n)


def fresh_stamp_count(stamps):
    import time
    now = time.time()
    n = 0
    for name in os.listdir(stamps):
        fp = os.path.join(stamps, name)
        try:
            if now - os.path.getmtime(fp) < CAP_WINDOW_S:
                n += 1
        except OSError:
            continue
    return n


def _bridge_call(prompt):
    """One xiaomi one-shot through lib/model.sh; stub/cmd seams for tests."""
    stub = os.environ.get("HNGH_GHOST_STUB")
    if stub:
        with open(stub, encoding="utf-8") as fh:
            return 0, fh.read()
    cmd = os.environ.get("HNGH_XIAOMI_CMD") or \
        '. "%s/lib/model.sh"; xiaomi_chat "$(cat)" 400' % _AUTOMATION
    env = dict(os.environ)
    env["AUTOMATION_ROOT"] = _AUTOMATION  # model.sh sources lib/ from it
    try:
        r = subprocess.run(["bash", "-c", cmd], input=prompt, env=env,
                           capture_output=True, text=True, timeout=120)
    except subprocess.TimeoutExpired:
        return 1, ""
    return r.returncode, r.stdout


def ghost_counsel():
    """One blended-voice counsel line, or None (fail-closed decoration)."""
    ghosts = load_ghosts()
    if not ghosts:
        return None
    stamps = state_dir()
    if fresh_stamp_count(stamps) >= CAP_CALLS:
        return None
    now = datetime.now(timezone.utc)
    seed = "%s-%d" % (now.strftime("%Y-%m-%d"), now.hour // 8)
    trio = pick_ghosts(ghosts, seed)
    if len(trio) < 3:
        return None
    voice_txt = "; ".join(
        "%s (%s): %s. Convictions: %s" % (g["name"], g["era"], g["register"],
                                          g["convictions"])
        for g in trio)
    prompt = (
        "You are the blended editorial voice of three ghosts on an "
        "autonomous machine's daily digest. Their registers and "
        "convictions:\n%s\n\nWrite ONE sentence of counsel (at most 60 "
        "words) to the machine's operator about today's machine state. "
        "Speak in the blended manner of the three ghosts. No preamble, "
        "no names of the ghosts, one sentence only." % voice_txt)
    rc, text = _bridge_call(prompt)
    if rc != 0 or not text.strip():
        return None
    line = " ".join(text.split())
    if STALE_MENTION_RE.search(line):
        return None  # counsel must not invent machine facts it cannot see
    with open(os.path.join(stamps, "%d-%d" % (int(now.timestamp()), os.getpid())),
              "w", encoding="utf-8") as fh:
        fh.write(seed + "\n")
    return line


# --- complete article summaries (2026-09-27 operator directive: "allow
# our ghost counsel to write complete summaries for us to review on any
# of our articles") ---

GHOST_LINE_RE = re.compile(r"^GHOST\|([^|]+)\|([^|]+)\|(.+)$")
SUMMARY_MIN_WORDS = 20  # a solid paragraph, not a one-liner
DEFAULT_SUMMARY_CAP = 12  # ghost-cap-day; the old 6/24h CAP_CALLS
# default stays on the one-line digest counsel lane above
QUIET_IDENTITY = "ghost-desk-quiet"
QUIET_WINDOW_S = 86400


def summaries_cache_path():
    return os.environ.get("HNGH_GHOST_SUMMARIES") or os.path.join(
        _AUTOMATION, "state", "ghost-summaries.json")


def params_path():
    return os.environ.get("HNGH_GHOST_PARAMS") or os.path.join(
        _AUTOMATION, "cadence-params.tsv")


def param(key, default=None):
    """cadence-params.tsv lookup: first row whose key column matches
    (same convention as weather-ingest.py); default when absent."""
    try:
        with open(params_path(), encoding="utf-8") as fh:
            for raw in fh:
                cols = raw.rstrip("\n").split("\t")
                if cols and cols[0] == key:
                    return cols[1]
    except OSError:
        pass
    return default


def summary_cap():
    """Daily call budget for the summaries lane (env override first)."""
    env = os.environ.get("HNGH_GHOST_CAP_DAY")
    if env and env.isdigit():
        return int(env)
    try:
        return int(param("ghost-cap-day", "") or DEFAULT_SUMMARY_CAP)
    except ValueError:
        return DEFAULT_SUMMARY_CAP


def _load_summary_cache():
    try:
        with open(summaries_cache_path(), encoding="utf-8") as fh:
            doc = json.load(fh)
    except (OSError, ValueError):
        return {}
    return doc if isinstance(doc, dict) else {}


def _save_summary_cache(cache):
    """Prune to a week and a 2000-entry ceiling; atomic; never raises."""
    cutoff = (datetime.now(timezone.utc) -
              timedelta(days=7)).strftime("%Y-%m-%dT%H:%M:%SZ")
    keep = {aid: c for aid, c in cache.items()
            if isinstance(c, dict) and isinstance(c.get("ts"), str)
            and c["ts"] >= cutoff}
    keep = dict(sorted(keep.items(),
                       key=lambda kv: kv[1]["ts"], reverse=True)[:2000])
    path = summaries_cache_path()
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        tmp = path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump(keep, fh, indent=1, sort_keys=True)
        os.replace(tmp, path)
    except OSError:
        pass


def _quiet(reason):
    """One deduped report-queue breadcrumb; a lost row is fine."""
    try:
        import report_queue
        report_queue.report(
            "model", "ghost desk quiet: %s" % reason,
            identity=QUIET_IDENTITY, window=QUIET_WINDOW_S)
    except Exception:
        pass


def ghost_summaries(articles, edition_stamp):
    """Batched ghost summaries for front-slot articles -- ONE xiaomi
    call per compose, cache-backed so 30-min re-composes do not re-call.

    Returns ({article_id: {"voice", "text"}}, quiet_reason_or_None).
    Fail-open but loud: every empty outcome carries a quiet reason (the
    caller renders it and a deduped breadcrumb is filed); a non-empty
    result means the page has ghosts and no marker is warranted."""
    cache = _load_summary_cache()
    got = {aid: {"voice": c["voice"], "text": c["text"]}
           for aid, c in cache.items()
           if isinstance(c, dict) and c.get("voice") and c.get("text")}
    todo = [a for a in articles if a.get("id") and a.get("headline")
            and a["id"] not in got]
    if not todo:
        return got, None
    ghosts = load_ghosts()
    if not ghosts:
        reason = "no ghost roster"
        _quiet(reason)
        return got, reason
    stamps = state_dir()
    cap = summary_cap()
    if fresh_stamp_count(stamps) >= cap:
        reason = "ghost cap exhausted (%d in 24h)" % cap
        _quiet(reason)
        return got, reason
    picks = pick_ghosts(ghosts, "ghost-summaries-%s" % edition_stamp,
                        n=min(len(todo), len(ghosts)))
    if not picks:
        reason = "no ghosts available for blend"
        _quiet(reason)
        return got, reason
    names = {g["name"] for g in ghosts}
    roster_txt = "\n".join(
        "- %s (%s): %s" % (g["name"], g["era"], g["register"])
        for g in picks)
    arts_txt = "\n".join(
        "ARTICLE|%s|%s|%s: %s -- %s" % (
            a["id"], picks[i]["name"], a.get("category") or "",
            a["headline"], (a.get("deck") or "").strip())
        for i, a in enumerate(todo))
    prompt = (
        "You write ghost summaries for an autonomous machine's "
        "newspaper; the machine's operator reviews them. Each ARTICLE "
        "below is assigned one ghost:\n\n%s\n\n%s\n\nFor every article "
        "write ONE line, exactly:\n"
        "GHOST|<article-id>|<ghost name>|<summary>\n"
        "The summary is one complete paragraph, 60-120 words, in the "
        "assigned ghost's voice. Use only facts stated in the article "
        "line; never mention stale, expired or unverified machine "
        "state. No preamble, no other lines." % (roster_txt, arts_txt))
    rc, text = _bridge_call(prompt)
    if rc != 0 or not text.strip():
        reason = "xiaomi bridge failed (rc %s)" % rc
        _quiet(reason)
        return got, reason
    todo_ids = {a["id"] for a in todo}
    fresh = {}
    for raw in text.splitlines():
        m = GHOST_LINE_RE.match(raw.strip())
        if not m:
            continue
        aid = m.group(1).strip()
        voice = m.group(2).strip()
        summary = " ".join(m.group(3).split())
        if aid not in todo_ids or voice not in names or not summary:
            continue
        if STALE_MENTION_RE.search(summary):
            continue  # summaries must not invent machine facts
        if len(summary.split()) < SUMMARY_MIN_WORDS:
            continue
        fresh[aid] = {"voice": voice, "text": summary}
    # one completed bridge call: stamp the budget regardless of yield
    try:
        with open(os.path.join(
                stamps, "%d-%d" % (time.time_ns(), os.getpid())),
                "w", encoding="utf-8") as fh:
            fh.write("ghost-summaries-%s\n" % edition_stamp)
    except OSError:
        pass
    if not fresh:
        reason = "all ghost summaries malformed"
        _quiet(reason)
        return got, reason
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    for aid, item in fresh.items():
        cache[aid] = dict(item, ts=now)
    _save_summary_cache(cache)
    got.update(fresh)
    return got, None


if __name__ == "__main__":
    print(ghost_counsel() or "")
