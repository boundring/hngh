#!/usr/bin/env python3
"""breadcrumb single-line integrity (2026-09-20 defect fix): the journal
crumb format is exactly one line per event (timestamp | job | event |
detail). Detail text containing literal newlines — e.g. the last-N make
error lines passed through by cadence/calendar/daily/03-gate-check.sh — must be
folded before the append, or the file gains malformed non-crumb lines
(2026-09-19 gate-red alert leaked 11 raw lines). Hermetic: sources the
real lib/breadcrumbs.sh against a temp journal db (HNGH_CRUMBS_DB) and asserts the
4-field, single-line structure survives any detail."""

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib" / "breadcrumbs.sh"


def run_breadcrumb(detail: str, db: Path) -> None:
    env = dict(os.environ)
    env["HNGH_CRUMBS_DB"] = str(db)  # sandbox journal db
    script = (
        '. "%s"\nbreadcrumb "test-job" "test-event" %s\n'
        % (LIB, "'" + detail.replace("'", "'\\''") + "'")
    )
    subprocess.run(["bash", "-c", script], env=env, check=True)


def read_journal(db: Path) -> str:
    """The journal's derived 4-field lines (the read seam)."""
    return subprocess.run(
        ["python3", str(ROOT / "lib" / "crumbs-db.py"), "export", "--db", str(db)],
        capture_output=True, text=True, check=True).stdout


class BreadcrumbSingleLine(unittest.TestCase):
    def test_plain_detail_is_four_fields(self):
        with tempfile.TemporaryDirectory() as td:
            db = Path(td) / "crumbs.db"
            run_breadcrumb("plain detail", db)
            line = read_journal(db).splitlines()[0]
            self.assertEqual(len(line.split(" | ")), 4)

    def test_multiline_detail_is_folded_to_one_line(self):
        with tempfile.TemporaryDirectory() as td:
            db = Path(td) / "crumbs.db"
            run_breadcrumb("gate: FAILED (rc=2)\nRan 34 tests\nmake: *** Error 1", db)
            lines = read_journal(db).splitlines()
            self.assertEqual(len(lines), 1)
            self.assertEqual(len(lines[0].split(" | ")), 4)
            self.assertNotIn("\n", lines[0])

    def test_trailing_newline_detail_is_folded(self):
        with tempfile.TemporaryDirectory() as td:
            db = Path(td) / "crumbs.db"
            run_breadcrumb("trailing newline\n", db)
            self.assertEqual(len(read_journal(db).splitlines()), 1)

    def test_pipe_escaping_still_holds(self):
        with tempfile.TemporaryDirectory() as td:
            db = Path(td) / "crumbs.db"
            run_breadcrumb("a | b | c", db)
            line = read_journal(db).splitlines()[0]
            self.assertEqual(len(line.split(" | ")), 4)
            self.assertIn("a ¦ b ¦ c", line)


class SelfLocatingRoot(unittest.TestCase):
    def test_sourcing_without_common_sh_writes_crumb(self):
        """2026-09-23 defect cleanup: an order-dependent caller sourced
        breadcrumbs.sh without lib/common.sh and died on set -u at the
        STATE_FILE default. The lib self-locates AUTOMATION_ROOT — and
        a self-located root yields its own journal db (never the live
        automation/state/crumbs.db)."""
        with tempfile.TemporaryDirectory() as td:
            fake = Path(td) / "automation"
            (fake / "lib").mkdir(parents=True)
            shutil.copy(LIB, fake / "lib" / "breadcrumbs.sh")
            # the writer the shim invokes lives beside it, same as prod
            shutil.copy(ROOT / "lib" / "crumbs.py", fake / "lib" / "crumbs.py")
            shutil.copy(ROOT / "lib" / "crumbs-db.py", fake / "lib" / "crumbs-db.py")
            env = {k: v for k, v in os.environ.items()
                   if k not in ("AUTOMATION_ROOT", "STATE_FILE", "HNGH_CRUMBS_DB")}
            script = ('. "%s"\nbreadcrumb "test-job" "test-event" "detail"\n'
                      % (fake / "lib" / "breadcrumbs.sh"))
            r = subprocess.run(["bash", "-c", script], env=env,
                               capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            lines = read_journal(fake / "state" / "crumbs.db").splitlines()
            self.assertEqual(len(lines[0].split(" | ")), 4)


# every non-lib STATE.md writer must uphold the same invariant itself:
# one line, four ` | `-separated fields, detail with no literal newline
# and no unescaped pipe (the 2026-09-19 gate-red spill class).
PY_WRITERS = [
    # (path, breadcrumb args with {d} marking the detail slot)
    (ROOT / "scripts" / "router-tick.py", ("test-job", "test-event", "{d}")),
    (ROOT / "jobs" / "service-state.py", ("test-event", "{d}")),
]


def write_via_python(path: Path, args: tuple, db: Path, detail: str) -> None:
    """Exec the module's breadcrumb() against a temp journal db."""
    import types
    mod = types.ModuleType("writer_under_test")
    mod.__file__ = str(path)
    src = path.read_text(encoding="utf-8")
    exec(compile(src, str(path), "exec"), mod.__dict__)  # noqa: S102 - test harness
    saved = os.environ.get("HNGH_CRUMBS_DB")
    os.environ["HNGH_CRUMBS_DB"] = str(db)
    try:
        mod.breadcrumb(*[detail if a == "{d}" else a for a in args])
    finally:
        if saved is None:
            os.environ.pop("HNGH_CRUMBS_DB", None)
        else:
            os.environ["HNGH_CRUMBS_DB"] = saved


class PythonWriterSingleLine(unittest.TestCase):
    def test_each_python_writer_folds_newlines(self):
        for path, args in PY_WRITERS:
            with self.subTest(writer=str(path)):
                with tempfile.TemporaryDirectory() as td:
                    db = Path(td) / "crumbs.db"
                    write_via_python(
                        path, args, db,
                        "gate: FAILED (rc=2)\nRan 34 tests\nmake: *** Error 1")
                    lines = read_journal(db).splitlines()
                    self.assertEqual(len(lines), 1)
                    self.assertEqual(len(lines[0].split(" | ")), 4)


def all_state_lines_are_four_fields(state_text: str) -> bool:
    """Reader contract shared by operator-items-feed.py:87 (split(' | ', 3)
    == 4 parts), patrol.py:150, beat-watchdog.py, and common.sh data.json
    parser: every line either parses to 4 fields or is skipped (the spill
    class). A compliant writer produces only 4-field lines."""
    for ln in state_text.splitlines():
        if len([p.strip() for p in ln.split(" | ", 3)]) != 4:
            return False
    return True


class ReaderContract(unittest.TestCase):
    def test_lib_output_satisfies_all_reader_parsers(self):
        with tempfile.TemporaryDirectory() as td:
            db = Path(td) / "crumbs.db"
            run_breadcrumb("gate: FAILED (rc=2)\nline two | pipe\nline three", db)
            self.assertTrue(all_state_lines_are_four_fields(read_journal(db)))


if __name__ == "__main__":
    unittest.main()
