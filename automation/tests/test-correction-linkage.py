#!/usr/bin/env python3
"""test-correction-linkage.py -- the correction convergence fold
(hermetic, 2026-09-15). Recurring operator corrections (>=2 sightings in
the ledger day window) converge into exactly one pending named-check row
(state/pending-checks.tsv) instead of re-filing blind re-route alerts;
the pending check then surfaces in patrol as check-pending:<id> (and
check-pending-stale:<id> after 7 days) until an operator promotes it by
removing the row.
"""
import importlib.util
import os
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)


def load(name, rel):
    spec = importlib.util.spec_from_file_location(
        name, os.path.join(ROOT, rel))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main():
    td = tempfile.mkdtemp(prefix="correction-linkage-")
    state = os.path.join(td, "state")
    os.makedirs(state)
    cl = load("correction_linkage", "lib/correction-linkage.py")

    sightings = os.path.join(state, "correction-sightings.tsv")
    pending = os.path.join(state, "pending-checks.tsv")
    now = time.time()
    day = 86400

    # 1. first sighting: below threshold, no pending check, re-route stays
    n = cl.record_sighting(sightings, "3146c023", now)
    assert n == 1, n
    created = cl.maybe_converge("3146c023", "mark read does nothing",
                                sightings, pending, now)
    assert created is False, created
    assert not os.path.exists(pending)

    # 2. second sighting same day: converges into exactly one pending row
    cl.record_sighting(sightings, "3146c023", now + 60)
    created = cl.maybe_converge("3146c023", "mark read does nothing",
                                sightings, pending, now + 60)
    assert created is True, created
    rows = cl.load_pending(pending)
    assert len(rows) == 1, rows
    assert rows[0]["id"] == "correction-3146c023", rows[0]
    assert rows[0]["check"] == "check:correction-3146c023", rows[0]
    assert "mark read does nothing" in rows[0]["condition"], rows[0]
    assert rows[0]["tier"], rows[0]

    # 3. dedup: further recurrences never duplicate the pending row
    for i in range(5):
        cl.record_sighting(sightings, "3146c023", now + 120 + i * 60)
        created = cl.maybe_converge("3146c023", "mark read does nothing",
                                    sightings, pending, now + 120)
    assert created is False, "re-converge must be suppressed once pending"
    assert len(cl.load_pending(pending)) == 1

    # 4. suppression: a converged correction no longer re-routes
    assert cl.is_converged(pending, "3146c023") is True
    assert cl.is_converged(pending, "other-id") is False

    # 5. stale escalation: pending older than 7 days escalates
    old_ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now - 8 * day))
    with open(pending, "a", encoding="utf-8") as fh:
        fh.write("\t".join(["correction-old1", "check:correction-old1",
                            "old condition", "30m", old_ts, "2",
                            "pending"]) + "\n")
    patrol = load("patrol", "jobs/patrol.py")
    os.environ["PATROL_PENDING_CHECKS"] = pending
    ctx = {"root": td, "pending_checks": pending, "now": now}
    out = patrol.check_pending_checks(ctx)
    arts = {"check-pending:" + f[0]: f[1] for f in out["fails"]}
    assert "check-pending:correction-3146c023" in arts, arts
    assert arts.get("check-pending:correction-old1") \
        == "check-pending-stale", arts

    # 6. promotion: operator removes the row -> no longer surfaced
    rows = [r for r in cl.load_pending(pending)
            if r["id"] != "correction-3146c023"]
    with open(pending, "w", encoding="utf-8") as fh:
        for r in rows:
            fh.write("\t".join([r["id"], r["check"], r["condition"],
                                r["tier"], r["created"], r["occurrences"],
                                r["status"]]) + "\n")
    out = patrol.check_pending_checks(ctx)
    arts = {f[0] for f in out["fails"]}
    assert "check-pending:correction-3146c023" not in arts, arts

    print("ok: correction-linkage convergence fold")
    return 0


if __name__ == "__main__":
    sys.exit(main())
