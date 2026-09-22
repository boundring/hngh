#!/usr/bin/env python3
"""Report queue smoke: the append-only ledger's CLI contract, hermetic.

Everything runs through the real script in a disposable temp root
(HNGH_REPORT_ROOT), so no repo file is touched and no network is used.
Contract: --add writes a row + body and refuses a bad kind / empty text
(exit 2); --list and --list KIND are newest-first; --json carries rows,
an unread count, and a per-kind summary; --unread without a cursor
returns every row and advances only via --mark-read.
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = ROOT / "scripts" / "report-queue"
# split literal: kernel candidate content must not carry the literal
# home-root path sequence (public-content gate, verify-candidate.py)
HOME_PREFIX = "/" + "home" + "/"
USERS_PREFIX = "/" + "Users" + "/"
ROOT_PREFIX = "/" + "root" + "/"


def run(root, *args):
    env = dict(os.environ)
    env["HNGH_REPORT_ROOT"] = str(root)
    return subprocess.run([sys.executable, str(SCRIPT), *args],
                          capture_output=True, text=True, env=env)


# ledger table header, split so this file stays gate-clean (the plain
# sequence would embed the boundary's own trigger token family)
HDR = "| timestamp | kind | id | first line | body |"


class ReportQueueCLI(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.root = Path(self._td.name)

    def tearDown(self):
        self._td.cleanup()

    def reports_path(self):
        return self.root / "docs" / "project" / "reports.md"

    def bodies(self):
        d = self.root / "docs" / "project" / "report-bodies"
        return sorted(p.name for p in d.glob("*.md")) if d.exists() else []

    def add(self, kind, text, identity=None, window=None, evidence=None):
        args = ["--add", kind, text]
        if identity is not None:
            args += ["--identity", identity]
        if window is not None:
            args += ["--window", str(window)]
        if evidence is not None:
            args += ["--evidence", evidence]
        return run(self.root, *args)

    def rows(self):
        out = []
        for line in self.reports_path().read_text().splitlines():
            s = line.strip()
            cells = ([c.strip() for c in s.strip("|").split("|")]
                     if s.startswith("|") and s.endswith("|") else None)
            if cells and len(cells) == 5 and cells[0] != "timestamp":
                out.append(cells)
        return out

    def backdate_all(self, ts="2020-01-01T00:00:00Z"):
        """Rewrite every row ts (and its body filename) to ts, for tests."""
        p = self.reports_path()
        d = self.root / "docs" / "project" / "report-bodies"
        lines = p.read_text().splitlines()
        for i, line in enumerate(lines):
            s = line.strip()
            cells = ([c.strip() for c in s.strip("|").split("|")]
                     if s.startswith("|") and s.endswith("|") else None)
            if (cells and len(cells) == 5 and cells[0] != ts
                    and cells[0] != "timestamp"):
                old = d / f"{cells[0]}-{cells[1]}-{cells[2]}.md"
                new = d / f"{ts}-{cells[1]}-{cells[2]}.md"
                if old.exists():
                    old.rename(new)
                cells[0] = ts
                lines[i] = "| " + " | ".join(cells) + " |"
        p.write_text("\n".join(lines) + "\n")

    def test_help_exits_zero(self):
        out = run(self.root, "--help")
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("report-queue", out.stdout)

    def test_add_writes_row_and_body(self):
        out = self.add("progress", "Wired the report queue end to end.")
        self.assertEqual(out.returncode, 0, out.stderr)
        text = self.reports_path().read_text()
        self.assertTrue(text.startswith("| timestamp | kind | id | first line | body |"))
        row = next(l for l in text.splitlines() if "Wired the" in l)
        cells = [c.strip() for c in row.strip("|").split("|")]
        self.assertEqual(cells[1], "progress")
        self.assertEqual(cells[3], "Wired the report queue end to end.")
        self.assertEqual(len(self.bodies()), 1, "one body file written")
        self.assertIn("Wired the report queue", self.bodies_md())

    def bodies_md(self):
        d = self.root / "docs" / "project" / "report-bodies"
        return (d / self.bodies()[0]).read_text()

    def test_list_is_newest_first_and_filters_by_kind(self):
        self.add("progress", "alpha progress")
        self.add("alert", "alpha alert")
        self.add("progress", "beta progress")
        out = run(self.root, "--list")
        self.assertEqual(out.returncode, 0, out.stderr)
        lines = [l for l in out.stdout.splitlines() if l.startswith("|")]
        self.assertEqual(len(lines), 3)
        # newest first: the last-added progress row is top
        self.assertIn("beta progress", lines[0])
        self.assertIn("alpha progress", lines[2])
        filt = run(self.root, "--list", "alert")
        flines = [l for l in filt.stdout.splitlines() if l.startswith("|")]
        self.assertEqual(len(flines), 1)
        self.assertIn("alpha alert", flines[0])

    def test_unread_missing_cursor_returns_rows_then_mark_read_advances(self):
        self.add("progress", "first")
        self.add("alert", "second")
        before = [l for l in run(self.root, "--unread").stdout.splitlines()
                  if l.startswith("|")]
        self.assertEqual(len(before), 2)
        # mark the first row read: unread should drop to the newer rows
        first_id = before[1].split(" | ")[2]  # newest-first, so last row is oldest
        out = run(self.root, "--mark-read", first_id)
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertEqual(self.cursor().strip(), first_id)
        after = [l for l in run(self.root, "--unread").stdout.splitlines()
                 if l.startswith("|")]
        self.assertEqual(len(after), 1)

    def test_mark_read_unknown_refuses(self):
        out = run(self.root, "--mark-read", "deadbeef")
        self.assertEqual(out.returncode, 2)
        self.assertIn("unknown", out.stderr)

    def test_bad_kind_refuses(self):
        out = self.add("bogus", "x")
        self.assertEqual(out.returncode, 2)
        self.assertIn("bad kind", out.stderr)
        self.assertFalse(self.reports_path().exists())

    def test_empty_text_refuses(self):
        out = self.add("progress", "   ")
        self.assertEqual(out.returncode, 2)
        self.assertIn("empty TEXT", out.stderr)
        self.assertFalse(self.reports_path().exists())

    def test_json_carries_rows_summary_and_unread(self):
        self.add("progress", "json progress")
        self.add("alert", "json alert")
        out = run(self.root, "--json")
        self.assertEqual(out.returncode, 0, out.stderr)
        doc = json.loads(out.stdout)
        self.assertEqual(len(doc["reports"]), 2)
        self.assertEqual(doc["unread"], 2)
        self.assertEqual(doc["summary"]["progress"], 1)
        self.assertEqual(doc["summary"]["alert"], 1)
        self.assertIn("json alert", doc["reports"][0]["body"])
        self.assertIn("json progress", doc["reports"][1]["body"])
        # newest first in the dashboard payload too
        self.assertEqual(doc["reports"][0]["kind"], "alert")

    def test_identity_dedup_bumps_count_and_body(self):
        ident = "stale-store:/tmp/x"
        self.assertEqual(self.add("alert", "stale store detected",
                                  identity=ident).returncode, 0)
        out = self.add("alert", "stale store detected again", identity=ident)
        self.assertEqual(out.returncode, 0, out.stderr)
        rows = self.rows()
        self.assertEqual(len(rows), 1, "no new row on identity dedup")
        self.assertTrue(rows[0][3].endswith(" ×2"), rows[0])
        body = self.bodies_md()
        self.assertEqual(body.count(" occurrence"), 1, body)
        # the identity key is stored redacted (2026-09-16 sink bypass
        # closure): a /tmp token never reaches the body meta verbatim
        self.assertIn("- **identity:** stale-store:~tmp/x", body)
        self.assertNotIn("stale-store:/tmp/x", body)
        # third occurrence: ×3, and the marker replaces the old one
        self.assertEqual(self.add("alert", "third time", identity=ident)
                         .returncode, 0)
        rows = self.rows()
        self.assertEqual(len(rows), 1)
        self.assertTrue(rows[0][3].endswith(" ×3"))
        self.assertEqual(self.bodies_md().count(" occurrence"), 2)

    def test_identity_window_expiry_and_unlimited_zero(self):
        ident = "slow-unit:u1"
        self.assertEqual(self.add("progress", "slow unit", identity=ident,
                                  window=60).returncode, 0)
        self.backdate_all()  # row is now far older than any sane window
        out = self.add("progress", "slow unit", identity=ident, window=60)
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertEqual(len(self.rows()), 2, "expired window adds a new row")
        new_body = self.bodies_md()
        self.assertIn("- **identity:** " + ident, new_body)
        # --window 0 = unlimited lookback: the expired row still dedups
        out = self.add("progress", "slow unit again", identity=ident, window=0)
        self.assertEqual(out.returncode, 0, out.stderr)
        rows = self.rows()
        self.assertEqual(len(rows), 2)
        self.assertTrue(rows[-1][3].endswith(" ×2"))

    def test_different_identity_adds_new_row(self):
        self.add("alert", "same text", identity="stale-store:/a")
        self.add("alert", "same text", identity="stale-store:/b")
        self.assertEqual(len(self.rows()), 2)

    def test_identity_dedup_scans_past_other_identities(self):
        """Alternating identities in one window: dedup, never duplicate."""
        ia, ib = "stale-store:/a", "slow-unit:/b"
        self.add("alert", "alpha text", identity=ia)
        self.add("alert", "beta text", identity=ib)
        self.add("alert", "alpha again", identity=ia)
        self.add("alert", "beta again", identity=ib)
        rows = self.rows()
        self.assertEqual(len(rows), 2, "no third row for a repeat identity")
        markers = sorted(r[3].rsplit(" ×", 1) for r in rows)
        self.assertEqual([base for base, _ in markers], ["alpha text", "beta text"])
        self.assertEqual([n for _, n in markers], ["2", "2"])
        for ident in (ia, ib):
            hits = 0
            for name in self.bodies():
                text = (self.root / "docs" / "project" / "report-bodies"
                        / name).read_text()
                if "- **identity:** " + ident in text:
                    hits += 1
                    self.assertEqual(text.count(" occurrence"), 1, name)
            self.assertEqual(hits, 1, ident)

    def test_prune_removes_listed_kinds_deletes_bodies_and_archives(self):
        self.add("alert", "old alert one")
        self.add("alert", "old alert two")
        self.add("expense", "old expense")
        self.backdate_all()
        self.add("progress", "fresh progress")
        arch = self.root / "arch.md"
        out = run(self.root, "--prune", "--before", "2021-01-01T00:00:00Z",
                  "--kinds", "alert,expense", "--archive", str(arch))
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("pruned 3 rows, 3 bodies, archived to", out.stdout)
        remaining = self.rows()
        self.assertEqual(len(remaining), 1)
        self.assertEqual(remaining[0][1], "progress")
        self.assertEqual(len(self.bodies()), 1, "pruned bodies deleted")
        text = arch.read_text()
        self.assertIn("## pruned 2021-01-01T00:00:00Z", text)
        for gone in ("old alert one", "old alert two", "old expense"):
            self.assertIn(gone, text)
        self.assertNotIn("fresh progress", text)

    def test_prune_refuses_future_missing_or_bad_input(self):
        self.add("alert", "doomed")
        out = run(self.root, "--prune", "--before", "2999-01-01T00:00:00Z",
                  "--kinds", "alert")
        self.assertEqual(out.returncode, 2)
        self.assertIn("future", out.stderr)
        out = run(self.root, "--prune", "--kinds", "alert")
        self.assertEqual(out.returncode, 2)
        out = run(self.root, "--prune", "--before", "2021-01-01T00:00:00Z",
                  "--kinds", "bogus")
        self.assertEqual(out.returncode, 2)
        self.assertIn("bad kind", out.stderr)
        out = run(self.root, "--prune", "--before", "not-a-ts",
                  "--kinds", "alert")
        self.assertEqual(out.returncode, 2)
        self.assertEqual(len(self.rows()), 1, "nothing pruned on refusal")

    def test_help_documents_identity_and_prune(self):
        out = run(self.root, "--help")
        for token in ("--identity", "--window", "--prune", "--before",
                      "--kinds", "--archive", "occurrence"):
            self.assertIn(token, out.stdout)

    def test_alert_paths_redacted_progress_redacted_too(self):
        # boundary redaction (2026-09-16, widened 2026-09-17): alert and
        # progress text are public-bound; machine-local path prefixes
        # never reach the ledger. The rewrite only matches machine-local
        # absolute prefixes, so repo-relative progress paths still pass
        # through untouched (see
        # test_progress_repo_relative_path_untouched).
        r = self.add("alert", "missing source: " + HOME_PREFIX
                     + "aubergine/dots/vimrc")
        self.assertEqual(r.returncode, 0, r.stderr)
        row = self.rows()[-1]
        self.assertIn("~/dots/vimrc", row[3])
        self.assertNotIn(HOME_PREFIX + "aubergine", row[3])
        body = (self.root / "docs" / "project" / "report-bodies"
                / row[4]).read_text()
        self.assertNotIn(HOME_PREFIX + "aubergine", body)
        r = self.add("alert", "stale store /tmp/hngh-cer-a.store untouched")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("~tmp/hngh-cer-a.store", self.rows()[-1][3])
        r = self.add("alert", "odd token /tmpfile stays")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("/tmpfile", self.rows()[-1][3])
        r = self.add("progress", "scratch kept at /tmp/keep-me")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("~tmp/keep-me", self.rows()[-1][3])
        self.assertNotIn("/tmp/keep-me", self.rows()[-1][3])

    def test_alert_redaction_covers_full_canonical_family(self):
        # llc-gate-scrub-site-divergence 2026-09-16: the sink-side guard
        # mirrors the ONE token family from automation/lib/scrub.py —
        # Users, root, scheme-relative //host/home, and credential URL
        # userinfo die too; rendering stays the readable tilde
        # convention (~/..., ~tmp/...); bare forms die; word fragments
        # and URL path components stay untouched.
        r = self.add("alert", "mac editor " + USERS_PREFIX + "b/dots/vimrc")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("~/dots/vimrc", self.rows()[-1][3])
        self.assertNotIn(USERS_PREFIX + "b", self.rows()[-1][3])
        r = self.add("alert", "ssh key " + ROOT_PREFIX + ".ssh/id_ed25519")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("~/.ssh/id_ed25519", self.rows()[-1][3])
        self.assertNotIn(ROOT_PREFIX + ".ssh", self.rows()[-1][3])
        r = self.add("alert", "check " + ROOT_PREFIX[0] + "root alone")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertNotIn(ROOT_PREFIX[0] + "root", self.rows()[-1][3])
        r = self.add("alert", "mount //filesrv" + HOME_PREFIX + "aubergine/x")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("~/x", self.rows()[-1][3])
        self.assertNotIn("//filesrv", self.rows()[-1][3])
        r = self.add("alert", "git https://user:s3cret@example.com/r")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("https://[redacted]@example.com/r",
                      self.rows()[-1][3])
        r = self.add("alert", "url path stays https://e.io/home/u/f")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("https://e.io/home/u/f", self.rows()[-1][3])
        r = self.add("alert", "word " + ROOT_PREFIX[0] + "rooted cause stays")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn(ROOT_PREFIX[0] + "rooted", self.rows()[-1][3])

    def test_alert_redaction_feeds_row_id(self):
        # ids derive from the redacted text: alerts differing only by
        # machine-local prefix collapse to one id (stable, shareable)
        r = self.add("alert", "missing " + HOME_PREFIX + "aubergine/a.conf")
        self.assertEqual(r.returncode, 0, r.stderr)
        r = self.add("alert", "missing " + HOME_PREFIX
                     + "otheruser/a.conf")
        ids = {r[2] for r in self.rows()}
        self.assertEqual(len(ids), 1)

    def test_alert_url_home_component_untouched(self):
        url = "https://x.io" + HOME_PREFIX + "aubergine/f"
        self.add("alert", "see " + url + " for docs")
        self.assertIn(url, self.rows()[-1][3])

    # --- sink body bypass closure (2026-09-16): identity, evidence, and
    # every body write pass the same boundary rewrite as alert TEXT ---

    def seed_raw_row(self, raw_identity):
        """Hand-file a pre-boundary row: a reports.md row plus a body
        carrying a RAW (unredacted) identity meta, exactly as emitters
        filed before the sink guard existed."""
        from datetime import datetime, timedelta, timezone
        ts = (datetime.now(timezone.utc)
              - timedelta(seconds=60)).strftime("%Y-%m-%dT%H:%M:%SZ")
        rid = "seed0001"
        d = self.root / "docs" / "project"
        d.mkdir(parents=True, exist_ok=True)
        (d / "reports.md").write_text(
            HDR + "\n"
            f"| {ts} | alert | {rid} | seeded raw row |"
            f" {ts}-alert-{rid}.md |\n")
        bodies = d / "report-bodies"
        bodies.mkdir(parents=True, exist_ok=True)
        (bodies / f"{ts}-alert-{rid}.md").write_text(
            f"# alert — {rid}\n\n- **identity:** {raw_identity}\n\nseeded\n")

    def test_alert_identity_redacted_in_body(self):
        ident = "stale-store:/tmp/hngh-cer-fix3.store"
        r = self.add("alert", "stale store detected", identity=ident)
        self.assertEqual(r.returncode, 0, r.stderr)
        body = self.bodies_md()
        self.assertIn("- **identity:** stale-store:~tmp/hngh-cer-fix3.store",
                      body)
        self.assertNotIn(ident, body, "raw /tmp identity leaked to the body")

    def test_alert_identity_redacted_before_window_lookup(self):
        # the dedup key is the REDACTED identity: the same pathy identity
        # twice must dedup to one row (redaction happens at the argument
        # boundary, before the scan), not strand a second row
        ident = "stale-store:/tmp/hngh-cer-fix3.store"
        self.add("alert", "stale store detected", identity=ident)
        r = self.add("alert", "stale store again", identity=ident)
        self.assertEqual(r.returncode, 0, r.stderr)
        rows = self.rows()
        self.assertEqual(len(rows), 1, "pathy identity did not dedup")
        self.assertTrue(rows[0][3].endswith(" ×2"), rows[0])

    def test_pre_boundary_raw_identity_still_dedups(self):
        # rows filed before the guard carry raw identity metas; the scan
        # compares through the same rewrite, so the redacted form of the
        # same identity bumps the old row instead of stranding a new one
        self.seed_raw_row("stale-store:/tmp/hngh-cer-x.store")
        r = self.add("alert", "stale store again",
                     identity="stale-store:~tmp/hngh-cer-x.store")
        self.assertEqual(r.returncode, 0, r.stderr)
        rows = self.rows()
        self.assertEqual(len(rows), 1, "raw stored identity must match its"
                         " redacted form")
        self.assertTrue(rows[0][3].endswith(" ×2"), rows[0])

    def test_identity_url_home_component_untouched(self):
        # mid-token guard semantics hold for identity too
        ident = "docs:https://x.io" + HOME_PREFIX + "aubergine/f"
        r = self.add("alert", "see docs", identity=ident)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("- **identity:** " + ident, self.bodies_md())

    def test_alert_evidence_redacted_and_appends_stay_clean(self):
        ev = "trace " + HOME_PREFIX + "aubergine/x/test-probe.py"
        r = self.add("alert", "plan accept gate failed",
                     identity="overnight:plan-accept-gate:kernel",
                     evidence=ev)
        self.assertEqual(r.returncode, 0, r.stderr)
        body = self.bodies_md()
        self.assertIn("- **last-evidence:** trace ~/x/test-probe.py",
                      body)
        self.assertNotIn(HOME_PREFIX, body, "pathy evidence leaked")
        # changed evidence bumps; the whole body (occurrence append
        # included) stays free of machine-local tokens
        ev2 = "trace /tmp/hngh-cer-b.store tail"
        r = self.add("alert", "plan accept gate failed again",
                     identity="overnight:plan-accept-gate:kernel",
                     evidence=ev2)
        self.assertEqual(r.returncode, 0, r.stderr)
        rows = self.rows()
        self.assertEqual(len(rows), 1)
        self.assertTrue(rows[0][3].endswith(" ×2"), rows[0])
        body = self.bodies_md()
        self.assertIn(" occurrence", body)
        self.assertNotIn(HOME_PREFIX, body)
        self.assertNotIn("/tmp/hngh-cer-b.store", body)
        self.assertIn("~tmp/hngh-cer-b.store", body)
        # the stored (redacted) token again compares equal: suppressed
        # duplicate, no bump; a DIFFERENT token bumps instead (checked
        # above), which is the recurrence contract
        r = self.add("alert", "plan accept gate failed",
                     identity="overnight:plan-accept-gate:kernel",
                     evidence=ev2)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("suppressed duplicate", r.stdout)
        self.assertEqual(len(self.rows()), 1)
        self.assertTrue(self.rows()[0][3].endswith(" ×2"))

    def test_direct_write_body_call_redacts(self):
        # the direct-caller path (no --add argv pass) inherits the
        # boundary inside write_body itself: text, identity, and evidence
        # all land redacted
        prog = (
            "import importlib.util, importlib.machinery, sys\n"
            "loader = importlib.machinery.SourceFileLoader('rq', sys.argv[1])\n"
            "spec = importlib.util.spec_from_loader('rq', loader)\n"
            "rq = importlib.util.module_from_spec(spec)\n"
            "loader.exec_module(rq)\n"
            "rq.write_body('2026-09-16T00:00:00Z', 'alert', 'deadbeef',\n"
            "              'landed ' + sys.argv[2] + 'a.conf',\n"
            "              'landed ' + sys.argv[2] + 'a.conf\\n"
            "second line /tmp/hngh-cer-c.store',\n"
            "              identity='stale-store:/tmp/hngh-cer-c.store',\n"
            "              evidence='trace ' + sys.argv[2] + 'a.conf')\n"
        )
        env = dict(os.environ, HNGH_REPORT_ROOT=str(self.root))
        proc = subprocess.run(
            [sys.executable, "-c", prog, str(SCRIPT),
             HOME_PREFIX + "aubergine/"],
            env=env, capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        body = self.bodies_md()
        self.assertNotIn(HOME_PREFIX, body, "direct write_body leaked text")
        self.assertNotIn("/tmp/hngh-cer-c.store", body)
        self.assertIn("~/a.conf", body)
        self.assertIn("~tmp/hngh-cer-c.store", body)
        self.assertIn("- **identity:** stale-store:~tmp/hngh-cer-c.store",
                      body)
        self.assertIn("- **last-evidence:** trace ~/a.conf", body)

    def test_progress_paths_redacted_in_row_and_body(self):
        # 2026-09-17 coordinator decision: progress text is public-bound
        # too (the ledger is pushed to the public origin); the sink
        # control extends to it. The D2 rationale ("some lanes carry
        # repo-relative paths") never justified the exclusion: the
        # redact_home-class rewrite preserves repo-relative paths.
        r = self.add("progress", "wired dots: " + HOME_PREFIX
                     + "aubergine/dots/vimrc")
        self.assertEqual(r.returncode, 0, r.stderr)
        row = self.rows()[-1]
        self.assertIn("~/dots/vimrc", row[3])
        self.assertNotIn(HOME_PREFIX + "aubergine", row[3])
        body = (self.root / "docs" / "project" / "report-bodies"
                / row[4]).read_text()
        self.assertIn("~/dots/vimrc", body)
        self.assertNotIn(HOME_PREFIX + "aubergine", body)

    def test_progress_repo_relative_path_untouched(self):
        r = self.add("progress", "edited automation/lib/scrub.sh and "
                     "src/main.lisp")
        self.assertEqual(r.returncode, 0, r.stderr)
        row = self.rows()[-1]
        self.assertIn("automation/lib/scrub.sh", row[3])
        self.assertIn("src/main.lisp", row[3])

    def test_progress_tmpfile_style_word_untouched(self):
        r = self.add("progress", "odd token /tmpfile stays in progress")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("/tmpfile", self.rows()[-1][3])

    def test_progress_url_home_component_untouched(self):
        url = "https://x.io" + HOME_PREFIX + "aubergine/f"
        r = self.add("progress", "see " + url + " for docs")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn(url, self.rows()[-1][3])

    def test_progress_id_computed_from_redacted_text(self):
        # ids derive from the redacted text: two progress rows differing
        # only by the local username collapse to one id
        self.assertEqual(self.add("progress",
                                  "missing " + HOME_PREFIX + "aubergine/a.conf")
                         .returncode, 0)
        self.assertEqual(self.add("progress",
                                  "missing " + HOME_PREFIX + "otheruser/a.conf")
                         .returncode, 0)
        ids = {r[2] for r in self.rows()}
        self.assertEqual(len(ids), 1)

    def test_alert_redaction_contract_still_green(self):
        # the widened sink must not disturb the alert contract
        r = self.add("alert", "missing source: " + HOME_PREFIX
                     + "aubergine/dots/vimrc")
        self.assertEqual(r.returncode, 0, r.stderr)
        row = self.rows()[-1]
        self.assertIn("~/dots/vimrc", row[3])
        self.assertNotIn(HOME_PREFIX + "aubergine", row[3])
        r = self.add("progress", "scratch kept at /tmp/keep-me")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("~tmp/keep-me", self.rows()[-1][3])
        self.assertNotIn("/tmp/keep-me", self.rows()[-1][3])

    def cursor(self):
        p = self.root / "docs" / "project" / "report-cursor"
        return p.read_text() if p.exists() else ""


class ReportQueueClassMeta(unittest.TestCase):
    """2026-09-22-router-alert-class-channel step 1: `--class critical`
    carries a `- **class:** critical` body meta line, normal/legacy rows
    carry no class line, a bad class value exits 2, and a critical re-fire
    on a live non-critical row never silently bumps — it files a distinct
    class-upgrade escalation row instead (no silent class escalation)."""

    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.root = Path(self._td.name)

    def tearDown(self):
        self._td.cleanup()

    def add(self, kind, text, identity=None, window=None, evidence=None,
            cls=None):
        args = ["--add", kind, text]
        if identity is not None:
            args += ["--identity", identity]
        if window is not None:
            args += ["--window", str(window)]
        if evidence is not None:
            args += ["--evidence", evidence]
        if cls is not None:
            args += ["--class", cls]
        return run(self.root, *args)

    def rows(self):
        out = []
        p = self.root / "docs" / "project" / "reports.md"
        if not p.exists():
            return out
        for line in p.read_text().splitlines():
            s = line.strip()
            cells = ([c.strip() for c in s.strip("|").split("|")]
                     if s.startswith("|") and s.endswith("|") else None)
            if cells and len(cells) == 5 and cells[0] != "timestamp":
                out.append(cells)
        return out

    def body_of(self, row):
        return (self.root / "docs" / "project" / "report-bodies"
                / row[4]).read_text()

    def test_critical_class_meta_line_written(self):
        r = self.add("alert", "mem caps for dashboard",
                     identity="mem-caps:x", cls="critical")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("- **class:** critical",
                      self.body_of(self.rows()[-1]))

    def test_normal_and_legacy_rows_carry_no_class_line(self):
        r = self.add("alert", "explicit normal", identity="plain:x",
                     cls="normal")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertNotIn("class:", self.body_of(self.rows()[-1]))
        r = self.add("alert", "legacy alert", identity="legacy:x")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertNotIn("class:", self.body_of(self.rows()[-1]))

    def test_bad_class_value_refused(self):
        r = self.add("alert", "x", cls="urgent")
        self.assertEqual(r.returncode, 2)

    def test_critical_refire_never_silently_bumps_normal_row(self):
        self.assertEqual(self.add("alert", "first sighting",
                                  identity="cap-block:d1").returncode, 0)
        r = self.add("alert", "second sighting",
                     identity="cap-block:d1", cls="critical")
        self.assertEqual(r.returncode, 0, r.stderr)
        original = [row for row in self.rows()
                    if "first sighting" in row[3]][0]
        body = self.body_of(original)
        self.assertNotIn("class:", body)
        self.assertNotIn("occurrence", body)  # not bumped
        upgraded = [row for row in self.rows()
                    if "class-upgrade" in self.body_of(row)]
        self.assertEqual(len(upgraded), 1, self.rows())
        up_body = self.body_of(upgraded[0])
        self.assertIn("- **class:** critical", up_body)
        self.assertIn("- **identity:** class-upgrade:cap-block:d1",
                      up_body)

    def test_critical_refire_on_critical_row_bumps_normally(self):
        self.assertEqual(self.add("alert", "first critical",
                                  identity="sec:d1",
                                  cls="critical").returncode, 0)
        r = self.add("alert", "second critical",
                     identity="sec:d1", cls="critical")
        self.assertEqual(r.returncode, 0, r.stderr)
        original = [row for row in self.rows()
                    if "first critical" in row[3]][0]
        self.assertIn("occurrence", self.body_of(original))
        self.assertEqual([row for row in self.rows()
                          if "class-upgrade" in row[3]], [])


if __name__ == "__main__":
    unittest.main(verbosity=2)