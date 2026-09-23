#!/usr/bin/env python3
"""test-crumbs-writer — single STATE.md crumb writer (lib/crumbs.py)
convergence + the mirror silent-failure hole closure.

Hermetic: temp journals + a stub report-queue behind a fake kernel root;
no imports of the routes under test (exec/subprocess, the
tests/test-breadcrumb-single-line.py pattern).

Coverage: one 4-field line emitted; separator/newline in a field
rejected (fail closed); the four writer routes converge on the one
writer (line shape + refusal proof); a verify mismatch raises exactly
one report-queue alert row with a stable evidence token.
"""
import importlib.util
import os
import re
import sqlite3
import subprocess
import sys
import tempfile
import types
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TS = r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z"
FOUR = re.compile(r"^%s \| [^|\n]* \| [^|\n]* \| [^\n]*\n$" % TS)


def load_crumbs():
    """lib/crumbs.py by path (the unit under test)."""
    spec = importlib.util.spec_from_file_location(
        "crumbs_uut", str(ROOT / "lib" / "crumbs.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def load_route(rel):
    """Exec a route module (router-tick / feedback-apply / service-state)
    like test-breadcrumb-single-line.py does: real source, __file__ set."""
    src = (ROOT / rel).read_text(encoding="utf-8")
    mod = types.ModuleType("route_" + Path(rel).stem.replace("-", "_"))
    mod.__file__ = str(ROOT / rel)
    sys.path.insert(0, str(ROOT / "lib"))
    try:
        exec(compile(src, mod.__file__, "exec"), mod.__dict__)
    finally:
        sys.path.pop(0)
    return mod


def run_shim(env, job, event, detail):
    """Run the shell route: source lib/breadcrumbs.sh, call breadcrumb."""
    sh = ('set -u\n. "%s/lib/breadcrumbs.sh"\nbreadcrumb "$1" "$2" "$3"\n'
          % ROOT)
    return subprocess.run(["bash", "-c", sh, "shim", job, event, detail],
                          env=env, capture_output=True, text=True)


class CrumbsWriterTest(unittest.TestCase):
    def setUp(self):
        self.td = tempfile.TemporaryDirectory()
        self.home = Path(self.td.name)
        self.journal = self.home / "STATE.md"
        self.env = dict(os.environ, STATE_FILE=str(self.journal),
                        HNGH_HOME_DIR=str(self.home), HOME=str(self.home))
        self.crumbs = load_crumbs()

    def tearDown(self):
        self.td.cleanup()

    def shape(self, data, job, detail):
        """Exactly one 4-field line, job/detail as expected."""
        self.assertEqual(len(data.splitlines()), 1, repr(data))
        self.assertTrue(FOUR.match(data), repr(data))
        fields = data.rstrip("\n").split(" | ")
        self.assertEqual(fields[1], job)
        self.assertEqual(fields[3], detail)

    def test_writer_emits_single_four_field_line(self):
        line = self.crumbs.crumb("job-x", "event-y", "detail z",
                                 state_file=str(self.journal))
        self.shape(line, "job-x", "detail z")
        self.assertEqual(self.journal.read_text(), line)

    def test_writer_rejects_separator_or_newline_in_any_field(self):
        for field in ("job", "event", "detail"):
            for dirty in ("a | b", "a\nb", "a\rb"):
                args = ["job-x", "event-y", "detail z"]
                args[("job", "event", "detail").index(field)] = dirty
                with self.assertRaises(ValueError, msg=(field, dirty)):
                    self.crumbs.crumb(*args, state_file=str(self.journal))
        self.assertFalse(self.journal.exists())  # fail closed: nothing half-written

    def test_shim_route_converges_and_refuses_dirty(self):
        proc = run_shim(self.env, "test-job", "test-event",
                        "gate: FAILED (rc=2)\nRan 34 tests")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        run_shim(self.env, "test-job", "test-event", "a | b | c")
        self.shape(self.journal.read_text().splitlines(keepends=True)[0],
                   "test-job", "gate: FAILED (rc=2) Ran 34 tests")
        self.shape(self.journal.read_text().splitlines(keepends=True)[1],
                   "test-job", "a \u00a6 b \u00a6 c")
        proc = run_shim(self.env, "test-job", "e | vil", "detail")
        self.assertEqual(proc.returncode, 2)  # writer fail-closed, visible
        self.assertEqual(len(self.journal.read_text().splitlines()), 2)

    def test_router_route_converges_and_refuses_dirty(self):
        mod = load_route("scripts/router-tick.py")
        mod.STATE_FILE = str(self.journal)
        mod.breadcrumb("test-job", "test-event",
                       "gate: FAILED (rc=2)\nRan 34 tests")
        self.shape(self.journal.read_text(), "test-job",
                   "gate: FAILED (rc=2) Ran 34 tests")
        with self.assertRaises(ValueError):  # routed through the writer
            mod.breadcrumb("test-job", "e | vil", "detail")
        self.assertEqual(len(self.journal.read_text().splitlines()), 1)

    def test_feedback_route_converges_and_refuses_dirty(self):
        mod = load_route("jobs/feedback-apply.py")
        mod.STATE_MD = str(self.journal)
        mod.crumb("test-event", "gate: FAILED (rc=2)\nRan 34 tests")
        self.shape(self.journal.read_text(), "feedback-apply",
                   "gate: FAILED (rc=2) Ran 34 tests")
        with self.assertRaises(ValueError):  # routed through the writer
            mod.crumb("e | vil", "detail")
        self.assertEqual(len(self.journal.read_text().splitlines()), 1)

    def test_service_route_converges_and_refuses_dirty(self):
        mod = load_route("jobs/service-state.py")
        mod.STATE_FILE = str(self.journal)
        mod.breadcrumb("test-event", "gate: FAILED (rc=2)\nRan 34 tests")
        self.shape(self.journal.read_text(), "service-state",
                   "gate: FAILED (rc=2) Ran 34 tests")
        mod.breadcrumb("e | vil", "detail")  # swallowed: best-effort probe
        self.assertEqual(len(self.journal.read_text().splitlines()), 1)


class CrumbsMirrorAlertTest(unittest.TestCase):
    """verify mismatch -> exactly one report-queue alert row; the
    evidence token is the stable evidence-gated dedup key."""

    def setUp(self):
        self.td = tempfile.TemporaryDirectory()
        self.home = Path(self.td.name)
        self.kernel = self.home / "kernel"
        (self.kernel / "scripts").mkdir(parents=True)
        self.log = self.home / "stub.log"
        stub = self.kernel / "scripts" / "report-queue"
        stub.write_text(  # the real scripts/report-queue is python; log argv
            "import os, sys\n"
            "with open(os.environ['STUB_LOG'], 'a') as fh:\n"
            "    fh.write('\\n'.join(sys.argv[1:]) + '\\n')\n")
        self.journal = self.home / "STATE.md"
        self.db = self.home / "crumbs.db"
        self.env = dict(
            os.environ, HNGH_STATE_FILE=str(self.journal),
            HNGH_CRUMBS_DB=str(self.db), HNGH_HOME=str(self.kernel),
            HNGH_REPORT_ROOT=str(self.kernel), HNGH_HOME_DIR=str(self.home),
            HOME=str(self.home), STUB_LOG=str(self.log))
        crumbs = load_crumbs()
        for i in range(2):
            crumbs.crumb("job-x", "event-%d" % i, "detail %d" % i,
                         state_file=str(self.journal))

    def tearDown(self):
        self.td.cleanup()

    def run_tick(self):
        proc = subprocess.run(
            ["bash", str(ROOT / "cadence" / "1m" / "15-crumbs-sync.sh")],
            env=self.env, capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, proc.stderr)

    def test_healthy_sync_files_no_alert(self):
        self.run_tick()
        self.run_tick()
        self.assertFalse(self.log.exists())  # no mismatch, no row

    def test_mismatch_files_one_alert_with_stable_evidence(self):
        self.run_tick()
        conn = sqlite3.connect(str(self.db))
        conn.execute("DELETE FROM crumbs WHERE event='event-0'")
        conn.commit()
        conn.close()
        self.run_tick()
        first = self.log.read_text().splitlines()
        self.run_tick()  # same evidence: the real report-queue suppresses
        second = self.log.read_text().splitlines()[len(first):]
        for args in (first, second):
            self.assertIn("alert", args)
            self.assertIn("crumbs-mirror:rows", args)
            self.assertIn("--window", args)
        self.assertEqual(first[first.index("--evidence") + 1],
                         "rows=1-importable=2")
        self.assertEqual(first[first.index("--evidence") + 1],
                         second[second.index("--evidence") + 1])


if __name__ == "__main__":
    unittest.main(verbosity=2)
