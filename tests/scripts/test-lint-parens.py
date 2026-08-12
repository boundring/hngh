#!/usr/bin/env python3
"""Fixture checks for the read-only Common Lisp reader guard."""

from pathlib import Path
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "lint-parens.py"
FIXTURES = ROOT / "tests" / "fixtures" / "lint-parens"


def run_guard(*names):
  return subprocess.run(
    [sys.executable, str(SCRIPT), *(str(FIXTURES / name) for name in names)],
    check=False,
    capture_output=True,
    text=True,
  )


def check(condition, description):
  if not condition:
    raise AssertionError(description)


def test_balanced_fixture():
  result = run_guard("balanced.lisp")
  check(result.returncode == 0, "balanced fixture succeeds")
  check("[OK]" in result.stdout, "balanced fixture reports success")


def test_unclosed_fixture():
  result = run_guard("unclosed.lisp")
  check(result.returncode != 0, "unclosed fixture fails")
  check("unclosed.lisp" in result.stdout, "unclosed fixture names its path")
  check("unclosed form" in result.stdout, "unclosed fixture reports the form")


def test_stray_close_fixture():
  result = run_guard("stray-close.lisp")
  check(result.returncode != 0, "stray close fixture fails")
  check("stray-close.lisp" in result.stdout, "stray close fixture names its path")
  check("stray ')'" in result.stdout, "stray close fixture reports the close")


def test_fix_mode_is_rejected_without_writing():
  fixture = FIXTURES / "unclosed.lisp"
  before = fixture.read_text(encoding="utf-8")
  result = subprocess.run(
    [sys.executable, str(SCRIPT), "--fix", str(fixture)],
    check=False,
    capture_output=True,
    text=True,
  )
  check(result.returncode != 0, "fix mode is rejected")
  check(fixture.read_text(encoding="utf-8") == before, "fix mode leaves input unchanged")


def test_missing_file_is_reported():
  missing = FIXTURES / "missing.lisp"
  check(not missing.exists(), "missing fixture path remains absent")
  result = subprocess.run(
    [sys.executable, str(SCRIPT), str(missing)],
    check=False,
    capture_output=True,
    text=True,
  )
  check(result.returncode != 0, "missing file fails")
  check("cannot read" in result.stdout, "missing file error is reported")


def test_non_utf8_file_is_reported():
  with tempfile.TemporaryDirectory() as directory:
    path = Path(directory) / "non-utf8.lisp"
    path.write_bytes(b"\xff")
    result = subprocess.run(
      [sys.executable, str(SCRIPT), str(path)],
      check=False,
      capture_output=True,
      text=True,
    )
  check(result.returncode != 0, "non-UTF-8 file fails")
  check("cannot read" in result.stdout, "non-UTF-8 file error is reported")
  check("Traceback" not in result.stderr, "non-UTF-8 file does not raise a traceback")


def test_reports_every_bad_path():
  result = run_guard("unclosed.lisp", "stray-close.lisp")
  check(result.returncode != 0, "multiple malformed fixtures fail")
  check("unclosed form" in result.stdout, "unclosed fixture is reported")
  check("stray ')'" in result.stdout, "stray-close fixture is reported")


def test_makefile_runs_reader_guard():
  result = subprocess.run(
    ["make", "--dry-run", "test"],
    cwd=ROOT,
    check=False,
    capture_output=True,
    text=True,
  )
  check(result.returncode == 0, "make dry-run succeeds")
  check(
    "python3 tests/scripts/test-lint-parens.py" in result.stdout,
    "make test runs the reader guard fixture suite",
  )


def main():
  test_balanced_fixture()
  test_unclosed_fixture()
  test_stray_close_fixture()
  test_fix_mode_is_rejected_without_writing()
  test_missing_file_is_reported()
  test_non_utf8_file_is_reported()
  test_reports_every_bad_path()
  test_makefile_runs_reader_guard()
  print("8 reader guard checks passed.")


if __name__ == "__main__":
  main()
