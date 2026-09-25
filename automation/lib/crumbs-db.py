#!/usr/bin/env python3
"""crumbs-db — the crumbs journal db (source of truth) + derived export.

Writer flip (refoundation P1b): lib/crumbs.py crumb() writes ONLY this
db (insert_crumb); STATE.md is a derived export rendered by
`export [--tail N] [--write-state]`. sync remains as the one-shot legacy
import (byte-offset watermark; spill lines counted in
crumbs_meta.skipped_total, never imported) so the flip loses no tail:
export --write-state runs sync once first, rewrites STATE.md from the
rows, then advances state_byte_offset to the new size — after that sync
imports 0 (idempotent).

Fail-open: any exception exits 0 silently (the telemetry.py contract) —
the db must never fail a cadence tick. --verify recounts the derived
export against the rows (wired in cadence/subhour/15-crumbs-sync.sh):
it prints row count, watermark, skipped_total plus importable/spill
counts, then verdict=ok or verdict=mismatch:<kind> evidence=<token>
(kind: rows|skipped; the evidence token is the report-queue dedup key).

usage: lib/crumbs-db.py sync|export|verify|rotate [--state PATH] [--db PATH]
       [--verify] [--tail N] [--write-state] [--days N] [--archive PATH]
"""

import argparse
import os
import re
import sqlite3
import sys
from datetime import datetime, timedelta, timezone

AUTO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STATE_FILE = os.environ.get("HNGH_STATE_FILE") or os.path.join(AUTO_ROOT, "STATE.md")
DB_FILE = os.path.join(AUTO_ROOT, "state", "crumbs.db")

TS_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")
KEEP_EVENTS = ("alert", "finding", "decision")

SCHEMA = """\
CREATE TABLE IF NOT EXISTS crumbs(
  ts TEXT NOT NULL, job TEXT NOT NULL,
  event TEXT NOT NULL, detail TEXT NOT NULL,
  writer TEXT);
CREATE TABLE IF NOT EXISTS crumbs_meta(
  key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE INDEX IF NOT EXISTS idx_crumbs_event
  ON crumbs(job, event, ts);"""

STAMP_RE = re.compile(r"^(?P<detail>.*) \[w=(?P<writer>[^@\s]+@\d+)\]$")

# ponytail: the watermark now tracks the derived export size (export
# --write-state rewrites STATE.md and advances it), so sync stays a
# harmless no-op after the writer flip; it is kept only to absorb the
# pre-flip tail and legacy appends.


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


def _ensure(conn):
    """Schema + writer column + one-time [w=@] stamp split."""
    conn.executescript(SCHEMA)
    try:
        conn.execute("ALTER TABLE crumbs ADD COLUMN writer TEXT")
    except sqlite3.OperationalError:
        pass
    if _meta(conn, "stamp_split") == 0:
        for rowid, detail in conn.execute(
                "SELECT rowid, detail FROM crumbs WHERE detail LIKE '% [w=%'"
        ).fetchall():
            m = STAMP_RE.match(detail)
            if m:
                conn.execute(
                    "UPDATE crumbs SET detail=?, writer=? WHERE rowid=?",
                    (m.group("detail"), m.group("writer"), rowid))
        conn.execute(
            "INSERT OR REPLACE INTO crumbs_meta(key, value) VALUES('stamp_split', '1')")
        conn.commit()


def db_path():
    return os.environ.get("HNGH_CRUMBS_DB") or DB_FILE


def render(row):
    ts, job, event, detail, writer = row
    if writer:
        detail = "%s [w=%s]" % (detail, writer)
    return "%s | %s | %s | %s" % (ts, job, event, detail)


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
            ts, job, event, detail = row
            m = STAMP_RE.match(detail)  # legacy stamp rides the detail
            if m:
                rows.append((ts, job, event, m.group("detail"),
                             m.group("writer")))
            else:
                rows.append((ts, job, event, detail, None))
        with conn:  # one transaction: rows + watermark land atomically
            conn.executemany(
                "INSERT INTO crumbs(ts, job, event, detail, writer)"
                " VALUES(?,?,?,?,?)", rows)
            conn.execute("INSERT OR REPLACE INTO crumbs_meta(key, value)"
                         " VALUES('state_byte_offset', ?)", (str(offset + consumed),))
            conn.execute("INSERT OR REPLACE INTO crumbs_meta(key, value)"
                         " VALUES('skipped_total', ?)", (str(skipped),))
        return len(rows), skipped, offset + consumed
    finally:
        conn.close()


def insert_crumb(db_file, ts, job, event, detail, writer):
    """Append one crumb row (the single write seam) and return the
    rendered 4-field line with trailing newline. Stamp number == rowid
    (journal coordinate: retries show the same content at new rowids)."""
    d = os.path.dirname(db_file)
    if d:
        os.makedirs(d, exist_ok=True)
    conn = sqlite3.connect(db_file, timeout=10)
    try:
        conn.execute("PRAGMA journal_mode=WAL")
        _ensure(conn)
        conn.execute("BEGIN IMMEDIATE")
        nxt = conn.execute(
            "SELECT COALESCE(MAX(rowid), 0) + 1 FROM crumbs").fetchone()[0]
        stamp = "%s@%d" % (writer, nxt)
        conn.execute(
            "INSERT INTO crumbs(ts, job, event, detail, writer) VALUES(?, ?, ?, ?, ?)",
            (ts, job, event, detail, stamp))
        conn.commit()
        return "%s | %s | %s | %s [w=%s]\n" % (ts, job, event, detail, stamp)
    finally:
        conn.close()


def export(db_file, tail=None, write_state=False, state_file=None):
    """Render 4-field lines from the rows (the derived journal).
    Prints to stdout; --write-state atomically rewrites STATE.md: final
    legacy sync first (absorbs the pre-flip tail, no dup — the old
    crumb() wrote STATE.md only), then watermark = new file size."""
    conn = sqlite3.connect(db_file, timeout=10)
    try:
        _ensure(conn)
        if write_state:
            state_file = state_file or STATE_FILE
            sync(state_file, db_file)
            rows = conn.execute(
                "SELECT ts, job, event, detail, writer FROM crumbs"
                " ORDER BY ts, rowid").fetchall()
            tmp = state_file + ".tmp"
            with open(tmp, "w", encoding="utf-8") as fh:
                for r in rows:
                    fh.write(render(r) + "\n")
            os.replace(tmp, state_file)
            conn.execute(
                "INSERT OR REPLACE INTO crumbs_meta(key, value)"
                " VALUES('state_byte_offset', ?)",
                (str(os.path.getsize(state_file)),))
            conn.commit()
            return
        if tail:
            rows = conn.execute(
                "SELECT ts, job, event, detail, writer FROM crumbs"
                " ORDER BY ts DESC, rowid DESC LIMIT ?",
                (tail,)).fetchall()[::-1]
        else:
            rows = conn.execute(
                "SELECT ts, job, event, detail, writer FROM crumbs"
                " ORDER BY ts, rowid").fetchall()
        for r in rows:
            print(render(r))
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
    elif spill != 0:  # derived export must contain only importable lines
        print("verdict=mismatch:skipped evidence=skipped=%d-spill=%d"
              % (skipped, spill))
    else:
        print("verdict=ok")


def _default_archive():
    # stdlib-only leaf (test-lib-dependencies LAYERS): inline hngh_home's
    # rule — HNGH_HOME_DIR or ~/.hngh, archive/ subdir — instead of
    # importing the sibling module.
    home = (os.environ.get("HNGH_HOME_DIR")
            or os.path.join(os.path.expanduser("~"), ".hngh"))
    return os.path.join(home, "archive", "crumbs-archive.tsv")


def rotate(db_file, days=14, archive=None):
    """Daily prune (P1c): keep `days` of ordinary rows and ALL
    alert/finding/decision rows forever; archive the pruned rows to the
    home archive before deleting them (archive-first ordering: a failed
    archive write deletes nothing)."""
    cutoff = (datetime.now(timezone.utc) - timedelta(days=days)
              ).strftime("%Y-%m-%dT%H:%M:%SZ")
    conn = sqlite3.connect(db_file, timeout=10)
    try:
        _ensure(conn)
        rows = conn.execute(
            "SELECT rowid, ts, job, event, detail, writer FROM crumbs"
            " WHERE ts < ? AND event NOT IN (?,?,?)",
            (cutoff,) + KEEP_EVENTS).fetchall()
        if rows and archive:
            adir = os.path.dirname(archive)
            if adir:
                os.makedirs(adir, exist_ok=True)
            with open(archive, "a", encoding="utf-8") as fh:
                fh.write("\n## rotated %s\n\n"
                         % datetime.now(timezone.utc).strftime(
                             "%Y-%m-%dT%H:%M:%SZ"))
                for r in rows:
                    fh.write(render(r[1:]) + "\n")
        if rows and not archive:
            print("rotated 0 rows before %s (no archive given --"
                  " nothing deleted)" % cutoff)
            return 0
        if rows:
            conn.executemany("DELETE FROM crumbs WHERE rowid = ?",
                             [(r[0],) for r in rows])
            conn.commit()
    finally:
        conn.close()
    tail = (", archived to %s" % archive) if (rows and archive) else ""
    print("rotated %d rows before %s%s" % (len(rows), cutoff, tail))
    return len(rows)


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="sqlite mirror of the STATE.md crumbs journal")
    ap.add_argument("cmd",
                    nargs="?",
                    choices=("sync", "export", "verify", "rotate"),
                    default="sync")
    ap.add_argument("--state", default=STATE_FILE)
    ap.add_argument("--db", default=db_path())
    ap.add_argument("--verify", action="store_true")
    ap.add_argument("--tail", type=int, default=None)
    ap.add_argument("--write-state", action="store_true")
    ap.add_argument("--days", type=int, default=14)
    ap.add_argument("--archive", default=None)
    args = ap.parse_args(argv)
    try:
        if args.cmd == "export":
            export(args.db, tail=args.tail, write_state=args.write_state,
                   state_file=args.state)
        elif args.cmd == "rotate":
            rotate(args.db, days=args.days,
                   archive=args.archive or _default_archive())
        else:
            if args.cmd == "sync":
                sync(args.state, args.db)
            if args.verify or args.cmd == "verify":
                verify(args.db, args.state)
    except Exception:
        pass  # fail-open: the mirror must never fail a tick
    return 0


if __name__ == "__main__":
    raise SystemExit(main())