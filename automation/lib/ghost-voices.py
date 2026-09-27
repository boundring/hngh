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
import os
import random
import re
import subprocess
import sys
from datetime import datetime, timezone

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


if __name__ == "__main__":
    print(ghost_counsel() or "")
