#!/usr/bin/env python3
"""run-autonomous smoke: one no-prompt ceremony tick, hermetic.

The real script runs in a disposable temp repo root (HNGH_RUN_ROOT) with
stub siblings for generate-publication / backlog-lanes / ceremony-drive,
so no repo file is touched, no sbcl and no network are needed.
Contract: --help exits 0; a missing journal is generated and reported
(progress + scheduled rows land); journal present with no queue prints
"nothing due"; a Next id + >=2 open lanes + valid heartbeat card runs the
ceremony stub from a fresh /tmp/hngh-auto- store and records the card's
kind; a malformed card exits 2 naming it; a refusing ceremony exits 3.
"""

import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = ROOT / "scripts" / "run-autonomous"
DAY = "2026-01-02"

GEN_STUB = """#!{python}
import os, sys
day = sys.argv[sys.argv.index("--daily") + 1]
p = __import__("pathlib").Path("docs/journal") / f"{day}.md"
p.parent.mkdir(parents=True, exist_ok=True)
p.write_text(f"# {day}\\n\\nstub narrative for {day}\\n")
"""

LANES_STUB = """#!{python}
import json
print(json.dumps({"summary": {"open": {open}}}))
"""

CEREMONY_STUB = """#!{python}
import os, sys
open(os.environ["STUB_ARGV_LOG"], "w").write(" ".join(sys.argv[1:]))
raise SystemExit(int(os.environ.get("STUB_EXIT", "0")))
"""


class RunAutonomousTick(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.root = Path(self._td.name)
        self.argv_log = self.root / "ceremony-argv.txt"
        (self.root / "docs" / "journal").mkdir(parents=True)
        (self.root / "docs" / "project" / "heartbeat").mkdir(parents=True)
        s = self.root / "scripts"
        s.mkdir()
        shutil.copy(ROOT / "scripts" / "report-queue", s / "report-queue")
        self.write_gen_stub()
        self.write_lanes_stub(0)
        self.write_ceremony_stub()

    def tearDown(self):
        self._td.cleanup()

    def write_gen_stub(self):
        self._stub("generate-publication", GEN_STUB)

    def write_lanes_stub(self, open_):
        self._stub("backlog-lanes", LANES_STUB.replace("{open}", str(open_)))

    def write_ceremony_stub(self):
        self._stub("ceremony-drive", CEREMONY_STUB)

    def _stub(self, name, text):
        p = self.root / "scripts" / name
        p.write_text(text.replace("{python}", sys.executable))
        os.chmod(p, 0o755)

    def tick(self, exit_code=0):
        env = dict(os.environ)
        env["HNGH_RUN_ROOT"] = str(self.root)
        env["HNGH_TICK_TS"] = DAY
        env["STUB_ARGV_LOG"] = str(self.argv_log)
        env["STUB_EXIT"] = str(exit_code)
        out = subprocess.run([sys.executable, str(SCRIPT)],
                             capture_output=True, text=True, env=env)
        return out

    def reports_text(self):
        p = self.root / "docs" / "project" / "reports.md"
        return p.read_text() if p.exists() else ""

    def prewrite_report(self, ts, kind, body):
        """Seed reports.md (header + one row) plus its body file, so
        report-queue --json returns a row naming the lane in BODY."""
        proj = self.root / "docs" / "project"
        proj.mkdir(parents=True, exist_ok=True)
        rf = proj / "reports.md"
        if not rf.exists():
            rf.write_text("| timestamp | kind | id | first line | body |\n")
        rid = body[:8]
        name = f"{ts}-{kind}-{rid}.md"
        (proj / "report-bodies").mkdir(parents=True, exist_ok=True)
        (proj / "report-bodies" / name).write_text(
            f"# {kind} \u2014 {rid}\n\n{body}\n")
        with rf.open("a") as fh:
            fh.write(f"| {ts} | {kind} | {rid} | {body} | {name} |\n")

    def test_help(self):
        out = subprocess.run([sys.executable, str(SCRIPT), "--help"],
                             capture_output=True, text=True)
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("run-autonomous", out.stdout)

    def test_missing_journal_generates_and_reports(self):
        out = self.tick()
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("ran: journal", out.stdout)
        self.assertTrue((self.root / "docs" / "journal" / f"{DAY}.md").exists())
        reports = self.reports_text()
        self.assertIn("progress", reports)
        self.assertIn("scheduled", reports)
        self.assertIn("stub narrative", reports)

    def test_journal_present_nothing_due(self):
        (self.root / "docs" / "journal" / f"{DAY}.md").write_text(
            f"# {DAY}\n\nalready here\n")
        out = self.tick()
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("nothing due", out.stdout)
        self.assertEqual(self.reports_text(), "")

    def mount_card(self, item="slice-a", kind="progress", body=None):
        q = self.root / "docs" / "project" / "queue.md"
        q.parent.mkdir(parents=True, exist_ok=True)
        q.write_text(f"# Queue\n\n## Next\n\n- **{item}** do the thing\n")
        card = self.root / "docs" / "project" / "heartbeat" / f"{item}.slice"
        lines = body or [f"objective for {item}", kind,
                         "src/a.lisp", "tests/a.lisp"]
        card.write_text("\n".join(lines) + "\n")
        return card

    def test_ceremony_runs_when_gates_open(self):
        self.mount_card()
        self.write_lanes_stub(2)
        (self.root / "docs" / "journal" / f"{DAY}.md").write_text(
            f"# {DAY}\n\npresent\n")
        out = self.tick()
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("ceremony slice-a complete", out.stdout)
        argv = self.argv_log.read_text()
        self.assertIn("--store=", argv)
        store = [a for a in argv.split() if a.startswith("--store=")][0]
        self.assertTrue(store.split("=", 1)[1].startswith("/tmp/hngh-auto-"), store)
        self.assertIn("src/a.lisp", argv)
        reports = self.reports_text()
        self.assertIn("progress", reports)
        self.assertIn("ceremony slice-a complete", reports)

    def test_course_prefers_mounted_older_lane_over_static_next(self):
        """Queue Next names lane-a, but lane-b shares a mounted card and
        has the older increment, so choose_course must steer to lane-b:
        a justified `course lane-b:` progress row lands and lane-b's
        slice (not lane-a's) runs through the ceremony stub."""
        q = self.root / "docs" / "project" / "queue.md"
        q.parent.mkdir(parents=True, exist_ok=True)
        q.write_text(
            "# Queue\n\n"
            "id\tstatus\ttitle\tevidence\n"
            "lane-a\tqueued\tA\tx\n"
            "lane-b\tqueued\tB\ty\n\n"
            "## Next\n\n"
            "- **lane-a** do A\n")
        for lane in ("lane-a", "lane-b"):
            (self.root / "docs" / "project" / "heartbeat"
             / f"{lane}.slice").write_text(
                f"objective {lane}\nprogress\nsrc/{lane}.lisp\n"
                f"tests/{lane}.lisp\n")
        # lane-a's last increment is NEWER than lane-b's → lane-b most due
        self.prewrite_report("2026-01-02T00:00:00Z", "progress",
                             "increment lane-a")
        self.prewrite_report("2026-01-01T00:00:00Z", "progress",
                             "increment lane-b")
        self.write_lanes_stub(2)
        (self.root / "docs" / "journal" / f"{DAY}.md").write_text(
            f"# {DAY}\n\npresent\n")

        out = self.tick()

        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("ceremony lane-b complete", out.stdout)
        argv = self.argv_log.read_text()
        self.assertIn("--store=", argv)
        self.assertIn("src/lane-b.lisp", argv)
        self.assertNotIn("src/lane-a.lisp", argv)
        reports = self.reports_text()
        self.assertIn("course lane-b:", reports)
        self.assertIn("last increment 2026-01-01T00:00:00Z", reports)
        self.assertIn("ceremony lane-b complete", reports)
        self.assertIn("scheduled", reports)

    def test_malformed_card_fails_closed(self):
        card = self.mount_card(kind="bogus")
        self.write_lanes_stub(2)
        (self.root / "docs" / "journal" / f"{DAY}.md").write_text(
            f"# {DAY}\n\npresent\n")
        out = self.tick()
        self.assertEqual(out.returncode, 2, out.stdout)
        self.assertIn(card.name, out.stderr)

    def test_ceremony_refusal_exits_3(self):
        self.mount_card()
        self.write_lanes_stub(2)
        (self.root / "docs" / "journal" / f"{DAY}.md").write_text(
            f"# {DAY}\n\npresent\n")
        out = self.tick(exit_code=1)
        self.assertEqual(out.returncode, 3, out.stdout)
        self.assertIn("ceremony refused", out.stderr)

    def test_provision_degrades_prose_evidence_to_placeholder(self):
        """A queue row whose evidence column is prose (not paths) must
        provision a card with the item id as the placeholder candidate —
        never prose words, which wedge every later tick with an invalid
        candidate manifest (2026-08-27 node-lattice-admission wedge)."""
        q = self.root / "docs" / "project" / "queue.md"
        q.parent.mkdir(parents=True, exist_ok=True)
        q.write_text(
            "# Queue\n\n"
            "id\tstatus\ttitle\tevidence\n"
            "lane-a\tqueued\tA\tbacklog entry; README vision\n"
            "lane-b\tqueued\tB\treal/path.lisp other\n\n"
            "## Next\n\n- **lane-a** do A\n")
        real = self.root / "real"
        real.mkdir()
        (real / "path.lisp").write_text("x\n")
        self.write_lanes_stub(2)
        (self.root / "docs" / "journal" / f"{DAY}.md").write_text(
            f"# {DAY}\n\npresent\n")

        out = self.tick()

        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("course lane-a provisioned", out.stdout)
        card = (self.root / "docs" / "project" / "heartbeat"
                / "lane-a.slice")
        lines = card.read_text().splitlines()
        self.assertEqual(lines[0], "A")
        self.assertEqual(lines[2], "lane-a")


if __name__ == "__main__":
    unittest.main(verbosity=2)
