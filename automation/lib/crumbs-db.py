#!/usr/bin/env python3
"""crumbs-db — sqlite mirror of the STATE.md crumbs journal.

Derived index only: STATE.md stays the append-only source of truth
(automation/lib/breadcrumbs.sh and the python writers); this store is
read-side scaffolding for a future consumer (mirror-first — writers and
grep-readers untouched). sync imports complete newline-terminated crumbs
past a byte-offset watermark; legacy spill lines are counted in
crumbs_meta.skipped_total, never imported. The watermark advances only
with the commit, so a second run imports 0 (idempotent).

Fail-open: any exception exits 0 silently (the telemetry.py contract) —
the mirror must never fail a cadence tick. --verify recounts the journal
and cross-checks the mirror (wired in cadence/1m/15-crumbs-sync.sh): it
prints row count, watermark, skipped_total plus importable/spill counts,
then verdict=ok or verdict=mismatch:<kind> evidence=<token> (kind:
rows|skipped; the evidence token is the report-queue dedup key).

usage: lib/crumbs-db.py sync [--state PATH] [--db PATH] [--verify]
"""

import argparse
import os
import re
import sqlite3

AUTO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STATE_FILE = os.environ.get("HNGH_STATE_FILE") or os.path.join(AUTO_ROOT, "STATE.md")
DB_FILE = os.path.join(AUTO_ROOT, "state", "crumbs.db")

TS_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")

SCHEMA = """\
CREATE TABLE IF NOT EXISTS crumbs(
  ts TEXT NOT NULL, job TEXT NOT NULL,
  event TEXT NOT NULL, detail TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS crumbs_meta(
  key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE INDEX IF NOT EXISTS idx_crumbs_event
  ON crumbs(job, event, ts);"""

# ponytail: byte-offset watermark assumes the documented append-only
# invariant of STATE.md (automation/Makefile smoke comment); if STATE.md
# is ever rewritten, this sync is retired with the writer-flip slice
# that causes it.


def _meta(conn, key):
    row = conn.execute("SELECT value FROM crumbs_meta WHERE key=?", (key,)).fetchone()
    return int(row[0]) if row else 0


def _parse(raw):
    """One complete raw line -> (ts, job, event, detail) or None when
    unimportable (spill; the format authority's rules)."""
    parts = raw.decode("utf-8", errors="replace").split(" | ", 3)
    if len(parts) != 4 or not TS_RE.match(parts[0].strip()):
        return None
    return tuple(p.strip() for p in parts)


def sync(state_file, db_file):
    """Import complete crumb lines past the watermark. Returns
    (imported, skipped_total, new_offset)."""
    os.makedirs(os.path.dirname(db_file) or ".", exist_ok=True)
    conn = sqlite3.connect(db_file, timeout=10)
    try:
        conn.execute("PRAGMA journal_mode=WAL")
        conn.executescript(SCHEMA)
        offset = _meta(conn, "state_byte_offset")
        skipped = _meta(conn, "skipped_total")
        try:
            size = os.path.getsize(state_file)
        except OSError:
            size = offset  # journal absent: nothing to import
        if size <= offset:
            return 0, skipped, offset  # steady state (or truncated: see ponytail note)
        with open(state_file, "rb") as fh:
            fh.seek(offset)
            data = fh.read()
        rows = []
        consumed = 0
        for raw in data.split(b"\n")[:-1]:  # complete lines only; trailing partial waits
            consumed += len(raw) + 1
            row = _parse(raw)
            if row is None:
                skipped += 1
                continue
            rows.append(row)
        with conn:  # one transaction: rows + watermark land atomically
            conn.executemany(
                "INSERT INTO crumbs(ts, job, event, detail) VALUES(?,?,?,?)", rows)
            conn.execute("INSERT OR REPLACE INTO crumbs_meta(key, value)"
                         " VALUES('state_byte_offset', ?)", (str(offset + consumed),))
            conn.execute("INSERT OR REPLACE INTO crumbs_meta(key, value)"
                         " VALUES('skipped_total', ?)", (str(skipped),))
        return len(rows), skipped, offset + consumed
    finally:
        conn.close()


def verify(db_file, state_file=None):
    """Recount the journal line-by-line and cross-check the mirror: rows
    must equal importable lines and skipped_total must equal spill lines.
    An unreadable/missing db reads as 0 rows (so a lost mirror alerts);
    a torn trailing line waits like sync does. Print-only — mismatches
    are data (verdict=...), never an exception."""
    state_file = state_file or STATE_FILE
    importable = spill = 0
    try:
        with open(state_file, "rb") as fh:
            for raw in fh:  # complete lines only; torn tail waits
                if not raw.endswith(b"\n"):
                    break
                if _parse(raw) is None:
                    spill += 1
                else:
                    importable += 1
    except OSError:
        pass  # journal absent: 0 lines (mirror must match: 0 rows)
    try:
        conn = sqlite3.connect(db_file, timeout=10)
        try:
            rows = conn.execute("SELECT COUNT(*) FROM crumbs").fetchone()[0]
            watermark = _meta(conn, "state_byte_offset")
            skipped = _meta(conn, "skipped_total")
        finally:
            conn.close()
    except sqlite3.Error:
        rows = watermark = skipped = 0  # missing/broken mirror reads as 0
    print("crumbs rows=%d watermark=%d skipped_total=%d importable=%d "
          "spill=%d db=%s"
          % (rows, watermark, skipped, importable, spill, db_file))
    if rows != importable:
        print("verdict=mismatch:rows evidence=rows=%d-importable=%d"
              % (rows, importable))
    elif skipped != spill:
        print("verdict=mismatch:skipped evidence=skipped=%d-spill=%d"
              % (skipped, spill))
    else:
        print("verdict=ok")


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="sqlite mirror of the STATE.md crumbs journal")
    ap.add_argument("cmd", nargs="?", choices=("sync",), default="sync")
    ap.add_argument("--state", default=STATE_FILE)
    ap.add_argument("--db", default=DB_FILE)
    ap.add_argument("--verify", action="store_true")
    args = ap.parse_args(argv)
    try:
        if args.verify:
            verify(args.db, args.state)
        else:
            sync(args.state, args.db)
    except Exception:
        pass  # fail-open: the mirror must never fail a tick
    return 0


if __name__ == "__main__":
    raise SystemExit(main())