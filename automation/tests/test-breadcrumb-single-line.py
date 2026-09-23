#!/usr/bin/env python3
"""breadcrumb single-line integrity (2026-09-20 defect fix): the STATE.md
crumb format is exactly one line per event (timestamp | job | event |
detail). Detail text containing literal newlines — e.g. the last-N make
error lines passed through by cadence/day/03-gate-check.sh — must be
folded before the append, or the file gains malformed non-crumb lines
(2026-09-19 gate-red alert leaked 11 raw lines). Hermetic: sources the
real lib/breadcrumbs.sh against a temp STATE_FILE and asserts the
4-field, single-line structure survives any detail."""

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib" / "breadcrumbs.sh"


def run_breadcrumb(detail: str, state: Path) -> None:
    env = dict(os.environ)
    env["AUTOMATION_ROOT"] = str(ROOT)  # unused: STATE_FILE overrides
    env["STATE_FILE"] = str(state)
    script = (
        '. "%s"\nbreadcrumb "test-job" "test-event" %s\n'
        % (LIB, "'" + detail.replace("'", "'\\''") + "'")
    )
    subprocess.run(["bash", "-c", script], env=env, check=True)


class BreadcrumbSingleLine(unittest.TestCase):
    def test_plain_detail_is_four_fields(self):
        with tempfile.TemporaryDirectory() as td:
            state = Path(td) / "STATE.md"
            run_breadcrumb("plain detail", state)
            line = state.read_text().splitlines()[0]
            self.assertEqual(len(line.split(" | ")), 4)

    def test_multiline_detail_is_folded_to_one_line(self):
        with tempfile.TemporaryDirectory() as td:
            state = Path(td) / "STATE.md"
            run_breadcrumb("gate: FAILED (rc=2)\nRan 34 tests\nmake: *** Error 1", state)
            lines = state.read_text().splitlines()
            self.assertEqual(len(lines), 1)
            self.assertEqual(len(lines[0].split(" | ")), 4)
            self.assertNotIn("\n", lines[0])

    def test_trailing_newline_detail_is_folded(self):
        with tempfile.TemporaryDirectory() as td:
            state = Path(td) / "STATE.md"
            run_breadcrumb("trailing newline\n", state)
            self.assertEqual(len(state.read_text().splitlines()), 1)

    def test_pipe_escaping_still_holds(self):
        with tempfile.TemporaryDirectory() as td:
            state = Path(td) / "STATE.md"
            run_breadcrumb("a | b | c", state)
            line = state.read_text().splitlines()[0]
            self.assertEqual(len(line.split(" | ")), 4)
            self.assertIn("a ¦ b ¦ c", line)


class SelfLocatingRoot(unittest.TestCase):
    def test_sourcing_without_common_sh_writes_crumb(self):
        """2026-09-23 defect cleanup: an order-dependent caller sourced
        breadcrumbs.sh without lib/common.sh and died on set -u at the
        STATE_FILE default. The lib self-locates AUTOMATION_ROOT."""
        with tempfile.TemporaryDirectory() as td:
            fake = Path(td) / "automation"
            (fake / "lib").mkdir(parents=True)
            shutil.copy(LIB, fake / "lib" / "breadcrumbs.sh")
            env = {k: v for k, v in os.environ.items()
                   if k not in ("AUTOMATION_ROOT", "STATE_FILE")}
            script = ('. "%s"\nbreadcrumb "test-job" "test-event" "detail"\n'
                      % (fake / "lib" / "breadcrumbs.sh"))
            r = subprocess.run(["bash", "-c", script], env=env,
                               capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            lines = (fake / "STATE.md").read_text().splitlines()
            self.assertEqual(len(lines[0].split(" | ")), 4)


# every non-lib STATE.md writer must uphold the same invariant itself:
# one line, four ` | `-separated fields, detail with no literal newline
# and no unescaped pipe (the 2026-09-19 gate-red spill class).
PY_WRITERS = [
    # (path, breadcrumb args with {d} marking the detail slot)
    (ROOT / "scripts" / "router-tick.py", ("test-job", "test-event", "{d}")),
    (ROOT / "jobs" / "service-state.py", ("test-event", "{d}")),
]


def write_via_python(path: Path, args: tuple, state: Path, detail: str) -> None:
    """Exec the module's breadcrumb() against a temp STATE_FILE."""
    import types
    mod = types.ModuleType("writer_under_test")
    mod.__file__ = str(path)
    src = path.read_text(encoding="utf-8")
    exec(compile(src, str(path), "exec"), mod.__dict__)  # noqa: S102 - test harness
    mod.STATE_FILE = str(state)
    mod.breadcrumb(*[detail if a == "{d}" else a for a in args])


class PythonWriterSingleLine(unittest.TestCase):
    def test_each_python_writer_folds_newlines(self):
        for path, args in PY_WRITERS:
            with self.subTest(writer=str(path)):
                with tempfile.TemporaryDirectory() as td:
                    state = Path(td) / "STATE.md"
                    write_via_python(
                        path, args, state,
                        "gate: FAILED (rc=2)\nRan 34 tests\nmake: *** Error 1")
                    lines = state.read_text().splitlines()
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
            state = Path(td) / "STATE.md"
            run_breadcrumb("gate: FAILED (rc=2)\nline two | pipe\nline three", state)
            self.assertTrue(all_state_lines_are_four_fields(state.read_text()))


if __name__ == "__main__":
    unittest.main()
