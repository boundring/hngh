#!/usr/bin/env python3
"""history-feed.py — pure builder + CLI for the dashboard /history.json feed.

Builds the pinned history/1 merged envelope:
  {"schema": "history/1", "entries": [{key, ts, summary, ...}, ...]}
from four sources, each already deduped/capped/truncated before the merge:

  gitlog   git log trailing 7d, cap 200   key gitlog:<40-hex sha>
  report   docs/project/reports.md table, newest 50, key report:<ts>-<kind>-<id>
  records  docs/records/*.md minus README.md, newest 30, key records:<stem>
  journal  docs/journal/<date>.md, newest 14, key journal:<date>

Entries are flat scalar objects; all ts values are Z-normalized
(YYYY-MM-DDTHH:MM:SSZ); the merged list sorts ts desc with key asc as the
tie-break. Newest-wins truncation at both layers (per-source cap, then the
total 500 cap after the merge). Missing report sidecars are tolerated (ref
may dangle); prune-archive rows are skipped. Display layer only: never a
governance input.

CLI: --out PATH (default automation/dashboard/history.json). The payload is
validated against jobs/viz_schema.py --schema history/1 before the atomic
temp+rename write; on any failure the last good file is kept (fail closed).
"""

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent  # automation/
REPO = ROOT.parent

SCHEMA = "history/1"
HIST_CAP_GITLOG = 200
HIST_CAP_REPORT = 50
HIST_CAP_RECORDS = 30
HIST_CAP_JOURNAL = 14
HIST_CAP_TOTAL = 500
HIST_SUMMARY_MAX = 200  # report `first` only; suffix "..."

GITLOG_WINDOW_DAYS = 7

_Z_RE = re.compile(
    r"^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2}:\d{2})([+-]\d{2}):?(\d{2})?$|^"
    r"(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2}:\d{2})Z$")


def _parse_z(text):
    """Parse an ISO-8601 timestamp to an aware UTC datetime; None if not
    parsable (fail closed per source row)."""
    if not isinstance(text, str):
        return None
    try:
        return datetime.fromisoformat(text.strip().replace("Z", "+00:00"))
    except ValueError:
        return None


def _z(dt):
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _now():
    return datetime.now(timezone.utc)


def _sort_desc(entries):
    """ts desc, key asc — the deterministic feed order everywhere.
    (reverse=True on the tuple would flip the key tie-break too.)"""
    by_key = sorted(entries, key=lambda e: e["key"])
    return sorted(by_key, key=lambda e: e["ts"], reverse=True)


def _cap(entries, cap):
    """Newest-wins head slice after the desc sort."""
    return _sort_desc(entries)[:cap]


# ---------------------------------------------------------------------------
# gitlog source
# ---------------------------------------------------------------------------

def gitlog_entries(repo_root, now):
    """Trailing {GITLOG_WINDOW_DAYS}d commit feed, cap {HIST_CAP_GITLOG},
    newest-wins. No path scoping, no --no-merges (publication-spine parity)."""
    start = now - timedelta(days=GITLOG_WINDOW_DAYS)
    start_iso = _z(start)
    try:
        out = subprocess.run(
            ["git", "-C", str(repo_root), "log",
             "--since=%s" % start_iso,
             "--pretty=format:%H%x09%h%x09%an%x09%aI%x09%s"],
            capture_output=True, text=True, check=True).stdout
    except (subprocess.CalledProcessError, FileNotFoundError):
        return []  # no git / bare fixture dir: empty source, feed stays valid
    entries = []
    for line in out.splitlines():
        parts = line.split("\t")
        if len(parts) != 5:
            continue
        sha, short, author, aI, subject = parts
        dt = _parse_z(aI)
        if dt is None:
            continue
        ts = _z(dt)
        if ts < start_iso:  # client-side guard: window on the emitted ts
            continue
        entries.append({
            "key": "gitlog:" + sha,
            "ts": ts,
            "summary": subject,
            "source": "gitlog",
            "author": author,
            "short": short,
        })
    return _cap(entries, HIST_CAP_GITLOG)


# ---------------------------------------------------------------------------
# report source (report-queue ledger table, read side only)
# ---------------------------------------------------------------------------

_TABLE_ROW_RE = re.compile(r"^\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|"
                           r"\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|"
                           r"\s*([^|]*?)\s*\|\s*$")


def report_entries(repo_root):
    """Newest HIST_CAP_REPORT ledger rows from docs/project/reports.md
    (5-col pipe table). Skips prune-archive rows; sidecar refs may dangle."""
    path = repo_root / "docs" / "project" / "reports.md"
    entries = []
    if not path.exists():
        return []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        m = _TABLE_ROW_RE.match(line.strip())
        if not m:
            continue
        ts, kind, rid, first, body = (c.strip() for c in m.groups())
        if (ts, kind, rid) == ("timestamp", "kind", "id"):
            continue  # header
        if body.startswith("prune-archive-"):
            continue
        dt = _parse_z(ts)
        if dt is None or not ts.endswith("Z"):
            continue  # fail closed on malformed rows
        summary = first if len(first) <= HIST_SUMMARY_MAX \
            else first[:HIST_SUMMARY_MAX] + "..."
        entries.append({
            "key": "report:%s-%s-%s" % (ts, kind, rid),
            "ts": ts,  # verbatim: ledger cells are already Z-form
            "summary": summary,
            "source": "report",
            "kind": kind,
            "ref": "docs/project/report-bodies/%s-%s-%s.md"
                   % (ts, kind, rid),
        })
    return _cap(entries, HIST_CAP_REPORT)


# ---------------------------------------------------------------------------
# records + journal sources
# ---------------------------------------------------------------------------

_DATE_STEM_RE = re.compile(r"^(\d{4}-\d{2}-\d{2})-(.+)$")


def records_entries(repo_root):
    """Newest HIST_CAP_RECORDS date-slug records; README.md excluded by
    exact filename; ts at date-precision midnight UTC."""
    rec_dir = repo_root / "docs" / "records"
    entries = []
    if not rec_dir.is_dir():
        return []
    for path in rec_dir.glob("*.md"):
        if path.name == "README.md":
            continue
        m = _DATE_STEM_RE.match(path.stem)
        if not m:
            continue
        date, slug = m.groups()
        entries.append({
            "key": "records:%s" % path.stem,
            "ts": "%sT00:00:00Z" % date,
            "summary": slug,
            "source": "records",
            "ref": "docs/records/%s" % path.name,
        })
    return _cap(entries, HIST_CAP_RECORDS)


def journal_entries(repo_root):
    """Newest HIST_CAP_JOURNAL daily journal files (glob excludes nested
    ebook/ by construction)."""
    jr_dir = repo_root / "docs" / "journal"
    entries = []
    if not jr_dir.is_dir():
        return []
    for path in jr_dir.glob("*.md"):
        if not re.match(r"^\d{4}-\d{2}-\d{2}$", path.stem):
            continue
        entries.append({
            "key": "journal:%s" % path.stem,
            "ts": "%sT00:00:00Z" % path.stem,
            "summary": "daily journal %s" % path.stem,
            "source": "journal",
            "ref": "docs/journal/%s" % path.name,
        })
    return _cap(entries, HIST_CAP_JOURNAL)


# ---------------------------------------------------------------------------
# merge + validate
# ---------------------------------------------------------------------------

def build(repo_root, now=None):
    """Merged history/1 feed dict. All sources are pre-capped; the merged
    list is sorted ts desc / key asc and cut to the total cap."""
    now = now or _now()
    repo_root = Path(repo_root)
    merged = (gitlog_entries(repo_root, now) + report_entries(repo_root)
              + records_entries(repo_root) + journal_entries(repo_root))
    seen = set()
    unique = []
    for e in merged:  # dedup fail-open would break the validator; guard here
        if e["key"] in seen:
            continue
        seen.add(e["key"])
        unique.append(e)
    return {"schema": SCHEMA,
            "entries": _sort_desc(unique)[:HIST_CAP_TOTAL]}


def _validate_with_viz_schema(payload):
    """Run jobs/viz_schema.py --schema history/1 over the serialized
    payload (round-trip first); returns (ok, detail)."""
    try:
        text = json.dumps(json.loads(json.dumps(payload)))
    except (TypeError, ValueError) as exc:
        return False, "round-trip failed: %s" % exc
    script = ROOT / "jobs" / "viz_schema.py"
    tmp = None
    try:
        fd, tmp = tempfile.mkstemp(prefix="hist-validate-", suffix=".json")
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
        return False, "viz_schema rc=%d: %s" % (proc.returncode,
                                                proc.stdout.strip())
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
    ap.add_argument("--out", default=str(ROOT / "dashboard" / "history.json"),
                    help="output path (default automation/dashboard/history.json)")
    ap.add_argument("--repo-root", default=str(REPO),
                    help="repository root (default: auto)")
    args = ap.parse_args()
    payload = build(args.repo_root)
    counts = {}
    for e in payload["entries"]:
        counts[e["source"]] = counts.get(e["source"], 0) + 1
    ok, detail = write_out(payload, args.out)
    if not ok:
        print("history-feed: validation failed: %s" % detail, file=sys.stderr)
        return 2
    print("history-feed: %d entries %s" % (len(payload["entries"]),
                                           counts))
    return 0


if __name__ == "__main__":
    sys.exit(main())
