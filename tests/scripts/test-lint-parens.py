"""Regression tests for scripts/lint-parens.py --fix.

The procedural paren fixer is the guardrail that keeps LLMs from hand-
counting parentheses (owner directive, 2026-08-09): wiring --fix into the
test gate means a broken file gets repaired deterministically before the
suite runs, and the LLM never counts. These tests lock in the fixer's
behavior so a regression in the fixer itself fails loudly.
"""

import subprocess
import sys
from pathlib import Path

LINT = Path(__file__).resolve().parents[2] / "scripts" / "lint-parens.py"


def run_lint(tmp_path, text, fix=False):
    f = tmp_path / "sample.lisp"
    f.write_text(text)
    cmd = [sys.executable, str(LINT), "--fix" if fix else "", str(f)]
    cmd = [c for c in cmd if c]
    r = subprocess.run(cmd, capture_output=True, text=True)
    return r.returncode, f.read_text(), r.stdout


def test_balanced_file_passes_and_unchanged(tmp_path):
    code = "(defun f ()\n  (list 1 2))\n"
    rc, out, _ = run_lint(tmp_path, code)
    assert rc == 0
    assert out == code


def test_unclosed_form_appends_close(tmp_path):
    # the class hit in the sandbox test session: EOF while a form is open
    code = "(test foo\n  (%sandbox-with\n    (is t))\n"
    rc, out, _ = run_lint(tmp_path, code, fix=True)
    assert rc == 0
    # only (test foo remains open at EOF -> appends 1 ')'
    assert out == code.rstrip("\n") + ")" * 1 + "\n"
    # and now a plain check passes on the fixed text
    rc2, _, _ = run_lint(tmp_path, out)
    assert rc2 == 0


def test_stray_close_reported_not_deleted(tmp_path):
    # stray ')' (depth went negative) is ambiguous — must be reported, never
    # silently deleted
    code = "(defun f ()\n  (list 1 2)))\n"
    rc, out, out_text = run_lint(tmp_path, code, fix=True)
    assert rc != 0
    assert "stray" in out_text
    assert out == code  # untouched


def test_mixed_stray_and_unclosed_never_fixes(tmp_path):
    # a file with BOTH classes must not be half-fixed
    code = "(defun f ()\n  (list 1)))\n  (defun g ()\n"
    rc, out, out_text = run_lint(tmp_path, code, fix=True)
    assert rc != 0
    assert out == code
    assert "stray" in out_text