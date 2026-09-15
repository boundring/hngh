#!/usr/bin/env python3
"""correction-linkage -- the correction convergence fold (2026-09-15,
automation free-commit lane). Operator corrections without a named check
used to re-file blind re-route alerts forever (identity correction:<id>
seen dozens of times per day, never converging). This module folds the
loop: once a correction identity recurs (>= CONVERGE_THRESHOLD sightings
inside the day window), it converges into exactly one pending named-check
row in state/pending-checks.tsv instead of another candidate:

  id  check  condition  tier  created  occurrences  status

- id: correction-<identity tail>
- check: check:correction-<id> (the proposed named-check id)
- condition: the correction text (the check's proposed predicate)
- tier: proposed cadence tier (30m)
- status: pending | promoted

Suppression then applies to the CORRECTION (is_converged): feedback-apply
stops re-filing the blind alert because the pending check now represents
it. The pending check surfaces in patrol as one operator-visible item
(identity check-pending:<id>) until an operator or authorized session
promotes it into config/patrol-routes.tsv by removing the row (promotion
is never automatic). A pending check older than STALE_DAYS escalates as
check-pending-stale:<id>.

Ledger conventions follow state/beat-blockers.tsv (tab-separated,
self-describing columns, no header row).
"""
import os
import re
import time

CONVERGE_THRESHOLD = 2
DAY_WINDOW_S = 86400
STALE_DAYS = 7
DEFAULT_TIER = "30m"
ID_TAIL_RE = re.compile(r"[0-9a-fA-F]{4,}")


def pending_path(root):
    return os.environ.get("PENDING_CHECKS_FILE",
                          os.path.join(root, "state",
                                       "pending-checks.tsv"))


def record_sighting(path, identity, now_s=None):
    """Append one sighting row; returns total sightings for identity
    inside the day window."""
    if now_s is None:
        now_s = time.time()
    cutoff = now_s - DAY_WINDOW_S
    count = 0
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            for ln in fh:
                f = ln.rstrip("\n").split("\t")
                if len(f) >= 2 and f[0] == identity:
                    try:
                        ts = float(f[1])
                    except ValueError:
                        continue
                    if ts >= cutoff:
                        count += 1
    except OSError:
        count = 0
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "a", encoding="utf-8") as fh:
        fh.write("%s\t%.0f\n" % (identity, now_s))
    return count + 1


def id_tail(identity):
    """correction-3146c023 / raw hash -> 3146c023; opaque -> slugged."""
    m = ID_TAIL_RE.search(identity or "")
    return m.group(0).lower() if m else re.sub(
        r"[^a-z0-9]+", "-", (identity or "unknown").lower())[:24].strip("-")


def load_pending(path):
    """Rows -> [{id, check, condition, tier, created, occurrences,
    status}]. Malformed rows fail closed (skipped)."""
    rows = []
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            for ln in fh:
                f = ln.rstrip("\n").split("\t")
                if len(f) < 7 or not f[0]:
                    continue
                rows.append({"id": f[0], "check": f[1],
                             "condition": f[2], "tier": f[3],
                             "created": f[4], "occurrences": f[5],
                             "status": f[6]})
    except OSError:
        pass
    return rows


def is_converged(path, identity):
    """The correction identity is represented by a pending check, so the
    blind re-route alert is suppressed."""
    tail = id_tail(identity)
    return any(r["id"] == "correction-" + tail
               for r in load_pending(path))


def maybe_converge(identity, condition, sightings_path, pending_path_,
                   now_s=None, tier=DEFAULT_TIER):
    """Fold point: the caller records the sighting first; at
    CONVERGE_THRESHOLD sightings in the window this creates the pending
    check row exactly once. Returns True when a row was created, False
    when suppressed (below threshold or already converged)."""
    if now_s is None:
        now_s = time.time()
    if is_converged(pending_path_, identity):
        return False
    cutoff = now_s - DAY_WINDOW_S
    count = 0
    try:
        with open(sightings_path, encoding="utf-8", errors="replace") as fh:
            for ln in fh:
                f = ln.rstrip("\n").split("\t")
                if len(f) >= 2 and f[0] == identity:
                    try:
                        if float(f[1]) >= cutoff:
                            count += 1
                    except ValueError:
                        continue
    except OSError:
        count = 0
    if count < CONVERGE_THRESHOLD:
        return False
    tail = id_tail(identity)
    row = "\t".join(["correction-" + tail,
                     "check:correction-" + tail,
                     (condition or "unparseable")[:200].replace("\t", " "),
                     tier,
                     time.strftime("%Y-%m-%dT%H:%M:%SZ",
                                   time.gmtime(now_s)),
                     str(CONVERGE_THRESHOLD), "pending"]) + "\n"
    os.makedirs(os.path.dirname(pending_path_), exist_ok=True)
    with open(pending_path_, "a", encoding="utf-8") as fh:
        fh.write(row)
    return True


def promote(path, identity):
    """Authorized action: mark the pending check promoted (the operator
    then lands the real route row in config/patrol-routes.tsv). Returns
    True when a row was found and promoted."""
    rows = load_pending(path)
    tail = id_tail(identity)
    hit = False
    for r in rows:
        if r["id"] == "correction-" + tail and r["status"] == "pending":
            r["status"] = "promoted"
            hit = True
    if hit:
        write_pending(path, rows)
    return hit


def write_pending(path, rows):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        for r in rows:
            fh.write("\t".join([r["id"], r["check"], r["condition"],
                                r["tier"], r["created"], r["occurrences"],
                                r["status"]]) + "\n")
