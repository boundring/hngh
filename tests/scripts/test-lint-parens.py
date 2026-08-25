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


def fix_copy(name, contents):
  "Write CONTENTS to a throwaway copy; returns (path, run)."
  import tempfile as _tf
  directory = _tf.mkdtemp()
  path = Path(directory) / name
  path.write_text(contents, encoding="utf-8")
  result = subprocess.run(
    [sys.executable, str(SCRIPT), "--fix", str(path)],
    check=False, capture_output=True, text=True,
  )
  return path, result


def test_fix_appends_missing_closers():
  path, result = fix_copy("unclosed-copy.lisp", "(defun foo ()\n")
  check(result.returncode == 0, "fix mode repairs an unclosed form")
  check(path.read_text(encoding="utf-8") == "(defun foo ())\n",
        "missing closers are appended at EOF")
  check("fixed:" in result.stdout, "fix mode reports the repair")


def test_fix_removes_stray_close():
  path, result = fix_copy("stray-copy.lisp", ")\n(defun foo () nil)\n")
  check(result.returncode == 0, "fix mode repairs a stray closer")
  check(path.read_text(encoding="utf-8") == "\n(defun foo () nil)\n",
        "the excess closer is removed")
  check("fixed:" in result.stdout, "fix mode reports the repair")


def test_fix_handles_balanced_and_mixed():
  ok_path, ok_result = fix_copy("balanced-copy.lisp", "(defun foo () nil)\n")
  check(ok_result.returncode == 0 and "[OK]" in ok_result.stdout,
        "fix mode leaves balanced files untouched")
  mixed, mixed_result = fix_copy(
    "mixed-copy.lisp", ")(defun foo ()\n")
  check(mixed_result.returncode == 0, "fix mode repairs mixed imbalances")
  check(Path(mixed).read_text(encoding="utf-8") == "(defun foo ())\n",
        "mixed stray plus unclosed is repaired to balance")


def test_fix_never_touches_strings_or_comments():
  path, result = fix_copy(
    "strings-copy.lisp", '(defun s () "(()")\n; stray ) in a comment )\n(defun t ()\n')
  check(result.returncode == 0, "fix mode repairs around strings/comments")
  text = path.read_text(encoding="utf-8")
  check('(defun s () "(()")' in text, "string content is untouched")
  check("; stray ) in a comment )" in text, "comment content is untouched")
  check(text.endswith("(defun t ())\n"), "only the unclosed form is closed")





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
  import tempfile
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
    "python3 scripts/lint-parens.py" in result.stdout,
    "make test runs the reader guard over the tree",
  )


def main():
  test_balanced_fixture()
  test_unclosed_fixture()
  test_stray_close_fixture()
  test_fix_appends_missing_closers()
  test_fix_removes_stray_close()
  test_fix_handles_balanced_and_mixed()
  test_fix_never_touches_strings_or_comments()
  test_fix_leaves_block_comments_reported_not_touched()
  test_missing_file_is_reported()
  test_non_utf8_file_is_reported()
  test_reports_every_bad_path()
  test_makefile_runs_reader_guard()
  print("12 reader guard checks passed.")
