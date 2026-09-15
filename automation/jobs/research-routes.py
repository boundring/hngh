#!/usr/bin/env python3
"""research-routes.py — pure builder + CLI for the dashboard
/research-routes.json feed (the routes/1 game-layer map payload).

Builds the pinned routes/1 envelope:
  {"schema": "routes/1", "generated": <ISO Z>, "routes": [...]}

One route per research line (automation/research-lines.tsv: line_id,
status, last_transition, title). The dated route history comes from
automation/research-dispositions.tsv — the ledger IS the transition log:
every usable dated disposition row (adopted/parked/killed) of a line is a
segment date; the terminus is the latest dated disposition (last row wins
on date ties). A line with no usable disposition is an open route
(terminus {action: "open", date: ""}); its polyline starts at the map
origin in the view. `harvested` marks lines carrying an ACTIVE lesson in
automation/research-lessons.tsv (d1-harvest: re-adoption refreshes,
non-adoption retires — so harvested means "carries a lesson now").

Fail-closed rules (legacy-accommodating like lib/research-harvest.py):
  lines        HEADERLESS (graph-data.py read parity: 4 columns id,
               status, timestamp, title; '#' comments and blank lines
               skipped); every data row must have exactly 4 fields, a
               known status family, and a parsable last_transition —
               anything else raises (the server's fail-soft cache keeps
               the last good feed).
  dispositions header must match; narrow prefix-parseable rows (>= 3
               fields: line, action, verdict) are padded — the live file
               carries 5/6/8-field pre-2026-09-12 rows; over-wide rows
               and < 3-field rows raise. Unknown-action rows (e.g. the
               blocker ledger's "fixed") are skipped, undated known-action
               rows are skipped (no map position).
  lessons      header must match; the line_id set is read from rows whose
               status is "active".
The payload is validated against jobs/viz_schema.py --schema routes/1
before the atomic temp+rename write; on any failure the last good file is
kept. Display layer only: never a governance input.

CLI: --out PATH (default automation/dashboard/research-routes.json).
"""

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent  # automation/
REPO = ROOT.parent

SCHEMA = "routes/1"
ROUTES_CAP = 100

LINES_COLUMNS = ("line_id", "status", "last_transition", "title")
DISP_HEADER = ("line", "action", "verdict", "reviewer", "evidence", "date",
               "support", "oppose", "followons")
LESSONS_HEADER = ("lesson_id", "date", "line_id", "subject", "lesson",
                  "status")

# status families (research-lines.tsv col 2) and route terminus actions
# (disposition ledger col 2 + the synthetic "open") — the same vocabulary
# jobs/viz_schema.py enforces.
STATUS_FAMILIES = ("planned", "expanding", "contracting", "crystallized",
                   "reviewed")
ROUTE_ACTIONS = ("adopted", "parked", "killed")

_Z_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")


def _parse_z(text):
    """Parse an ISO-8601 timestamp to an aware UTC datetime; None if not
    parsable. Bare dates (no offset) are UTC midnight — the disposition
    ledger's date column is date-precision and must never shift by the
    builder host's local offset."""
    if not isinstance(text, str):
        return None
    try:
        dt = datetime.fromisoformat(text.strip().replace("Z", "+00:00"))
    except ValueError:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


def _z(dt):
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _now():
    return datetime.now(timezone.utc)


def _norm_date(text):
    """Z-normalize a date/timestamp cell; None when unparsable."""
    dt = _parse_z(text)
    return _z(dt) if dt else None


# ---------------------------------------------------------------------------
# TSV readers
# ---------------------------------------------------------------------------

def _read_tsv(path, header, min_fields=None, pad_to=None, headerless=False):
    """Read a TSV into dicts keyed by the header names.

    Header drift raises (fail closed — a renamed column must never emit a
    quietly-wrong payload) unless headerless is set, in which case every
    data row must match len(header) exactly. Rows shorter than min_fields
    raise; rows between min_fields and len(header) are padded when pad_to
    is set (the research-dispositions legacy accommodation); over-wide
    rows raise. '#' comment lines and blank lines are skipped (read_tsv
    parity with graph-data.py). A missing file returns [] (callers decide
    whether that is fatal).
    """
    if not path.exists():
        return []
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    rows = []
    first = True
    for n, line in enumerate(lines, start=1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        fields = line.split("\t")
        if first and not headerless:
            first = False
            if tuple(f.strip() for f in fields) != tuple(header):
                raise ValueError("%s: header drift: expected %s, got %r"
                                 % (path.name, "+".join(header), line))
            continue
        first = False
        need = min_fields if min_fields is not None else len(header)
        if len(fields) < need:
            raise ValueError("%s:%d: row has %d fields, need >= %d"
                             % (path.name, n, len(fields), need))
        if len(fields) > len(header):
            raise ValueError("%s:%d: row has %d fields, expected %d"
                             % (path.name, n, len(fields), len(header)))
        if pad_to:
            fields = fields + [""] * (pad_to - len(fields))
        rows.append(dict(zip(header, fields)))
    return rows


def line_rows(repo_root):
    """research-lines.tsv rows. The file is HEADERLESS (graph-data.py
    read parity): 4 columns, '#' comments and blank lines skipped, every
    data row exactly 4 fields, known status, parsable timestamp."""
    path = Path(repo_root) / "automation" / "research-lines.tsv"
    rows = _read_tsv(path, LINES_COLUMNS, headerless=True)
    out = {}
    for n, row in enumerate(rows, start=2):
        lid = row["line_id"].strip()
        status = row["status"].strip()
        ts = _norm_date(row["last_transition"])
        if not lid:
            raise ValueError("research-lines.tsv:%d: empty line_id" % n)
        if status not in STATUS_FAMILIES:
            raise ValueError("research-lines.tsv:%d: unknown status %r"
                             % (n, status))
        if ts is None:
            raise ValueError("research-lines.tsv:%d: unparsable "
                             "last_transition %r"
                             % (n, row["last_transition"]))
        out[lid] = {"id": lid, "status": status,
                    "last_transition": ts,
                    "title": row["title"].strip(),
                    "_order": n}  # file order breaks recency ties
    return out


def disposition_rows(repo_root):
    """research-dispositions.tsv rows padded to the 9-column writer
    schema; rows below 3 fields or over-wide raise."""
    path = Path(repo_root) / "automation" / "research-dispositions.tsv"
    return _read_tsv(path, DISP_HEADER, min_fields=3, pad_to=len(DISP_HEADER))


def lesson_line_ids(repo_root):
    """Line ids carrying an ACTIVE lesson (research-lessons.tsv)."""
    path = Path(repo_root) / "automation" / "research-lessons.tsv"
    rows = _read_tsv(path, LESSONS_HEADER)
    return {r["line_id"].strip() for r in rows
            if r.get("status", "").strip() == "active"}


# ---------------------------------------------------------------------------
# route assembly
# ---------------------------------------------------------------------------

def _segments_for(lid, disp_rows):
    """Usable dated segments for one line: every known-action disposition
    row with a parsable date, Z-normalized, deduped, ascending."""
    dates = set()
    for row in disp_rows:
        if row.get("line", "").strip() != lid:
            continue
        if row.get("action", "").strip() not in ROUTE_ACTIONS:
            continue  # e.g. blocker-ledger rows sharing the file
        norm = _norm_date(row.get("date", ""))
        if norm:
            dates.add(norm)
    return sorted(dates)


def _terminus_for(lid, disp_rows):
    """Latest dated known-action disposition: {action, date}; the open
    route shape {action: 'open', date: ''} when none exists. Date ties
    resolve to the LAST row (the ledger is append-only; the later append
    is the newer verdict)."""
    best = None  # (norm_date, file_order, action)
    for order, row in enumerate(disp_rows):
        if row.get("line", "").strip() != lid:
            continue
        action = row.get("action", "").strip()
        if action not in ROUTE_ACTIONS:
            continue
        norm = _norm_date(row.get("date", ""))
        if not norm:
            continue
        if best is None or (norm, order) >= (best[0], best[1]):
            best = (norm, order, action)
    if best is None:
        return {"action": "open", "date": ""}
    return {"action": best[2], "date": best[0]}


def _recency(route):
    """Route recency key for the newest-wins cap: the newest dated fact
    on the route (segments, terminus, or the line's own transition)."""
    dates = list(route["segments"])
    if route["terminus"]["date"]:
        dates.append(route["terminus"]["date"])
    dates.append(route["last_transition"])
    return max(dates)


def build(repo_root, now=None, cap=ROUTES_CAP):
    """The routes/1 payload dict: one route per research line, newest-
    wins at `cap`."""
    now = now or _now()
    repo_root = Path(repo_root)
    lines = line_rows(repo_root)
    disp_rows = disposition_rows(repo_root)
    harvested_ids = lesson_line_ids(repo_root)
    routes = []
    for lid, line in lines.items():
        route = {
            "id": lid,
            "title": line["title"],
            "status": line["status"],
            "segments": _segments_for(lid, disp_rows),
            "terminus": _terminus_for(lid, disp_rows),
            "harvested": lid in harvested_ids,
            "last_transition": line["last_transition"],  # internal: cap
        }
        route["_order"] = line["_order"]
        routes.append(route)
    routes.sort(key=lambda r: (_recency(r), r["_order"]), reverse=True)
    # sort once more by id only among equal recency so the order is total
    # and deterministic regardless of dict iteration
    by_id = sorted(routes, key=lambda r: r["id"])
    by_id.sort(key=lambda r: _recency(r), reverse=True)
    out = []
    for r in by_id[:cap]:
        r.pop("_order", None)
        r.pop("last_transition", None)  # internal cap key, not in routes/1
        out.append(r)
    return {"schema": SCHEMA, "generated": _z(now), "routes": out}


# ---------------------------------------------------------------------------
# validate + atomic write (history-feed discipline)
# ---------------------------------------------------------------------------

def _validate_with_viz_schema(payload):
    """Run jobs/viz_schema.py --schema routes/1 over the serialized
    payload (round-trip first); returns (ok, detail)."""
    try:
        text = json.dumps(json.loads(json.dumps(payload)))
    except (TypeError, ValueError) as exc:
        return False, "round-trip failed: %s" % exc
    script = ROOT / "jobs" / "viz_schema.py"
    tmp = None
    try:
        fd, tmp = tempfile.mkstemp(prefix="routes-validate-", suffix=".json")
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(text)
        proc = subprocess.run(
            [sys.executable, str(script), "--schema", SCHEMA, tmp],
            capture_output=True, text=True, timeout=30)
    except (subprocess.TimeoutExpired, OSError) as exc:
        return False, "validator unavailable: %s" % exc
    finally:
        if tmp and os.path.exists(tmp):
            os.unlink(tmp)
    if proc.returncode != 0:
        # viz_schema prints the rejection detail on stderr (rc-2 path);
        # stdout only carries the accept line
        detail = (proc.stderr.strip() or proc.stdout.strip())
        return False, "viz_schema rc=%d: %s" % (proc.returncode, detail)
    return True, proc.stdout.strip()


def write_out(payload, out_path):
    """Validate then atomic temp+rename write; returns (ok, detail)."""
    ok, detail = _validate_with_viz_schema(payload)
    if not ok:
        return False, detail  # fail closed: keep the last good file
    out_path = Path(out_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    tmp = "%s.%d.tmp" % (out_path, os.getpid())
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, indent=1)
        fh.write("\n")
    os.replace(tmp, out_path)
    return True, detail


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--out",
                    default=str(ROOT / "dashboard" / "research-routes.json"),
                    help="output path (default automation/dashboard/"
                         "research-routes.json)")
    ap.add_argument("--repo-root", default=str(REPO),
                    help="repository root (default: auto)")
    args = ap.parse_args()
    payload = build(args.repo_root)
    harvested = sum(1 for r in payload["routes"] if r["harvested"])
    ok, detail = write_out(payload, args.out)
    if not ok:
        print("research-routes: validation failed: %s" % detail,
              file=sys.stderr)
        return 2
    print("research-routes: %d routes (%d harvested)"
          % (len(payload["routes"]), harvested))
    return 0


if __name__ == "__main__":
    sys.exit(main())
