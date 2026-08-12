#!/usr/bin/env python3
"""Fixture checks for the read-only candidate evidence verifier."""

from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "verify-candidate.py"


CHECKS = 0


def check(condition, description):
  global CHECKS
  CHECKS += 1
  if not condition:
    raise AssertionError(description)


def run(command, cwd):
  return subprocess.run(
    command,
    cwd=cwd,
    check=True,
    capture_output=True,
    text=True,
  )


def make_repository(directory):
  root = Path(directory)
  run(["git", "init", "--quiet"], root)
  run(["git", "config", "user.email", "fixture@example.invalid"], root)
  run(["git", "config", "user.name", "Fixture"], root)
  (root / "README.md").write_text("fixture\n", encoding="utf-8")
  (root / "Makefile").write_text("test:\n\t@true\n", encoding="utf-8")
  run(["git", "add", "README.md", "Makefile"], root)
  run(["git", "commit", "--quiet", "-m", "fixture"], root)
  return root


def run_verifier(manifest, root):
  return subprocess.run(
    [sys.executable, str(SCRIPT), "--manifest", str(manifest)],
    cwd=root,
    check=False,
    capture_output=True,
    text=True,
  )


def test_missing_manifest_refuses():
  result = subprocess.run(
    [sys.executable, str(SCRIPT)],
    cwd=ROOT,
    check=False,
    capture_output=True,
    text=True,
  )
  check(result.returncode == 2, "missing manifest is a usage refusal")
  check("candidate manifest is required" in result.stderr,
        "missing manifest names the required input")
  check(":refused" in result.stdout,
        "missing manifest reports a closed refusal")


def test_empty_manifest_refuses():
  with tempfile.TemporaryDirectory() as directory:
    manifest = Path(directory) / "candidate.txt"
    manifest.write_text("", encoding="utf-8")
    result = subprocess.run(
      [sys.executable, str(SCRIPT), "--manifest", str(manifest)],
      cwd=ROOT,
      check=False,
      capture_output=True,
      text=True,
    )
  check(result.returncode == 1, "empty manifest is a policy refusal")
  check("candidate manifest is empty" in result.stdout,
        "empty manifest names its defect")
  check(":refused" in result.stdout,
        "empty manifest reports a closed refusal")


def test_duplicate_manifest_entry_refuses():
  with tempfile.TemporaryDirectory() as directory:
    manifest = Path(directory) / "candidate.txt"
    manifest.write_text("README.md\nREADME.md\n", encoding="utf-8")
    result = subprocess.run(
      [sys.executable, str(SCRIPT), "--manifest", str(manifest)],
      cwd=ROOT,
      check=False,
      capture_output=True,
      text=True,
    )
  check(result.returncode == 1, "duplicate manifest entry is a policy refusal")
  check("duplicate candidate path: README.md" in result.stdout,
        "duplicate entry names its path")
  check(":refused" in result.stdout,
        "duplicate entry reports a closed refusal")


def test_manifest_path_policy_refuses():
  cases = (
    ("/tmp/outside\n", "candidate path must be repository-relative: /tmp/outside"),
    ("../outside\n", "candidate path escapes repository: ../outside"),
    (".hermes/plan.md\n", "candidate path is excluded: .hermes/plan.md"),
    ("docs/README.md\nAGENTS.md\n", "candidate manifest is not sorted"),
  )
  for contents, expected in cases:
    with tempfile.TemporaryDirectory() as directory:
      manifest = Path(directory) / "candidate.txt"
      manifest.write_text(contents, encoding="utf-8")
      result = subprocess.run(
        [sys.executable, str(SCRIPT), "--manifest", str(manifest)],
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
      )
    check(result.returncode == 1, f"{expected} is a policy refusal")
    check(expected in result.stdout, f"{expected} is reported")
    check(":refused" in result.stdout, f"{expected} has a closed refusal")


def test_missing_or_directory_candidate_path_refuses():
  cases = (
    ("missing-source.lisp\n", "candidate path does not exist: missing-source.lisp"),
    ("docs\n", "candidate path is not a regular file: docs"),
  )
  for contents, expected in cases:
    with tempfile.TemporaryDirectory() as directory:
      manifest = Path(directory) / "candidate.txt"
      manifest.write_text(contents, encoding="utf-8")
      result = subprocess.run(
        [sys.executable, str(SCRIPT), "--manifest", str(manifest)],
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
      )
    check(result.returncode == 1, f"{expected} is a policy refusal")
    check(expected in result.stdout, f"{expected} is reported")
    check(":refused" in result.stdout, f"{expected} has a closed refusal")


def test_valid_manifest_runs_fast_gate():
  with tempfile.TemporaryDirectory() as directory:
    root = make_repository(directory)
    manifest = root / "manifest.txt"
    manifest.write_text("README.md\n", encoding="utf-8")
    result = run_verifier(manifest, root)
  check(result.returncode == 0, "valid candidate with passing fast gate succeeds")
  check("fast-test: passed" in result.stdout,
        "valid candidate records fast-test evidence")
  check("whitespace: passed" in result.stdout,
        "valid candidate records whitespace evidence")
  check("relative-links: passed" in result.stdout,
        "valid candidate records relative-link evidence")
  check("dependency: passed" in result.stdout,
        "valid candidate records dependency evidence")
  check("excluded-paths: .hermes/** (not admitted)" in result.stdout,
        "valid candidate records excluded paths")
  check("public-content: passed" in result.stdout,
        "valid candidate records public-content evidence")
  check("candidate-hash: " in result.stdout,
        "valid candidate reports a content hash")
  check(":passed" in result.stdout,
        "valid candidate reports a closed pass")


def test_credential_shaped_content_refuses():
  with tempfile.TemporaryDirectory() as directory:
    root = make_repository(directory)
    candidate = root / "candidate.txt"
    candidate.write_text("api" + "_key=abcdefghijk\n", encoding="utf-8")
    manifest = root / "manifest.txt"
    manifest.write_text("candidate.txt\n", encoding="utf-8")
    result = run_verifier(manifest, root)
  check(result.returncode == 1, "credential-shaped content refuses")
  check("credential-shaped content: candidate.txt" in result.stdout,
        "credential-shaped content names its candidate")
  check(":refused" in result.stdout,
        "credential-shaped content reports a closed refusal")


def test_unsafe_content_refuses():
  cases = (
    ("path=" + "/" + "home/fixture/private\n", "absolute local path: candidate.txt"),
    ("ev" + "al(command)\n", "shell execution: candidate.txt"),
  )
  for contents, expected in cases:
    with tempfile.TemporaryDirectory() as directory:
      root = make_repository(directory)
      candidate = root / "candidate.txt"
      candidate.write_text(contents, encoding="utf-8")
      manifest = root / "manifest.txt"
      manifest.write_text("candidate.txt\n", encoding="utf-8")
      result = run_verifier(manifest, root)
    check(result.returncode == 1, f"{expected} refuses")
    check(expected in result.stdout, f"{expected} names its candidate")
    check(":refused" in result.stdout, f"{expected} reports a closed refusal")


def test_broken_markdown_link_refuses():
  with tempfile.TemporaryDirectory() as directory:
    root = make_repository(directory)
    candidate = root / "candidate.md"
    candidate.write_text("[missing](missing.md)\n", encoding="utf-8")
    manifest = root / "manifest.txt"
    manifest.write_text("candidate.md\n", encoding="utf-8")
    result = run_verifier(manifest, root)
  check(result.returncode == 1, "broken Markdown link refuses")
  check("broken Markdown link: candidate.md: missing.md" in result.stdout,
        "broken Markdown link names the source and target")
  check(":refused" in result.stdout,
        "broken Markdown link reports a closed refusal")


def test_trailing_whitespace_refuses():
  with tempfile.TemporaryDirectory() as directory:
    root = make_repository(directory)
    candidate = root / "candidate.txt"
    candidate.write_text("trailing space \n", encoding="utf-8")
    manifest = root / "manifest.txt"
    manifest.write_text("candidate.txt\n", encoding="utf-8")
    result = run_verifier(manifest, root)
  check(result.returncode == 1, "trailing whitespace refuses")
  check("trailing whitespace: candidate.txt: 1" in result.stdout,
        "trailing whitespace names its file and line")
  check(":refused" in result.stdout,
        "trailing whitespace reports a closed refusal")


def test_make_target_requires_manifest():
  result = subprocess.run(
    ["make", "verify-candidate"],
    cwd=ROOT,
    check=False,
    capture_output=True,
    text=True,
  )
  check(result.returncode == 2, "make target refuses a missing manifest")
  check("CANDIDATE_MANIFEST must name a manifest" in result.stderr,
        "make target names the required variable")


def test_ignored_candidate_refuses():
  with tempfile.TemporaryDirectory() as directory:
    root = make_repository(directory)
    (root / ".gitignore").write_text("ignored.txt\n", encoding="utf-8")
    (root / "ignored.txt").write_text("fixture\n", encoding="utf-8")
    manifest = root / "manifest.txt"
    manifest.write_text("ignored.txt\n", encoding="utf-8")
    result = run_verifier(manifest, root)
  check(result.returncode == 1, "ignored candidate refuses")
  check("candidate path is ignored: ignored.txt" in result.stdout,
        "ignored candidate names its path")
  check(":refused" in result.stdout, "ignored candidate is a closed refusal")


def test_working_tree_report_observes_untracked_files():
  with tempfile.TemporaryDirectory() as directory:
    root = make_repository(directory)
    manifest = root / "manifest.txt"
    manifest.write_text("README.md\n", encoding="utf-8")
    result = run_verifier(manifest, root)
  check(result.returncode == 0, "untracked manifest does not alter candidate scope")
  check("working-tree-dirty: yes" in result.stdout,
        "working-tree report records dirty state")
  check("working-tree-staged: no" in result.stdout,
        "working-tree report records unstaged state")
  check("working-tree-untracked: yes" in result.stdout,
        "working-tree report records untracked state")


def test_lisp_candidate_records_parenthesis_guard_evidence():
  with tempfile.TemporaryDirectory() as directory:
    root = make_repository(directory)
    (root / "scripts").mkdir()
    shutil.copy2(ROOT / "scripts" / "lint-parens.py", root / "scripts")
    candidate = root / "candidate.lisp"
    candidate.write_text("(defun fixture () nil)\n", encoding="utf-8")
    manifest = root / "manifest.txt"
    manifest.write_text("candidate.lisp\n", encoding="utf-8")
    result = run_verifier(manifest, root)
  check(result.returncode == 0, "balanced Lisp candidate passes")
  check("parenthesis-guard: passed" in result.stdout,
        "Lisp candidate records parenthesis evidence")


def test_unbalanced_lisp_candidate_refuses():
  with tempfile.TemporaryDirectory() as directory:
    root = make_repository(directory)
    (root / "scripts").mkdir()
    shutil.copy2(ROOT / "scripts" / "lint-parens.py", root / "scripts")
    candidate = root / "candidate.lisp"
    candidate.write_text("(defun fixture ()\n", encoding="utf-8")
    manifest = root / "manifest.txt"
    manifest.write_text("candidate.lisp\n", encoding="utf-8")
    result = run_verifier(manifest, root)
  check(result.returncode == 1, "unbalanced Lisp candidate refuses")
  check(":refused parenthesis evidence failed" in result.stdout,
        "unbalanced Lisp reports parenthesis refusal")


def test_inward_dependency_refuses():
  with tempfile.TemporaryDirectory() as directory:
    root = make_repository(directory)
    (root / "scripts").mkdir()
    shutil.copy2(ROOT / "scripts" / "lint-parens.py", root / "scripts")
    candidate = root / "candidate.lisp"
    candidate.write_text(
      "(defpackage #:hngh.domain (:use #:cl #:hngh.adapters.filesystem))\n",
      encoding="utf-8",
    )
    manifest = root / "manifest.txt"
    manifest.write_text("candidate.lisp\n", encoding="utf-8")
    result = run_verifier(manifest, root)
  check(result.returncode == 1, "inward outer dependency refuses")
  check("forbidden dependency: candidate.lisp" in result.stdout,
        "inward dependency names the candidate")
  check(":refused dependency evidence failed" in result.stdout,
        "inward dependency reports a closed refusal")


def test_missing_parenthesis_guard_refuses():
  with tempfile.TemporaryDirectory() as directory:
    root = make_repository(directory)
    candidate = root / "candidate.lisp"
    candidate.write_text("(defun fixture () nil)\n", encoding="utf-8")
    manifest = root / "manifest.txt"
    manifest.write_text("candidate.lisp\n", encoding="utf-8")
    result = run_verifier(manifest, root)
  check(result.returncode == 1, "missing parenthesis guard refuses")
  check(":refused parenthesis evidence failed" in result.stdout,
        "missing parenthesis guard reports a closed refusal")


def test_system_executable_path_passes():
  with tempfile.TemporaryDirectory() as directory:
    root = make_repository(directory)
    candidate = root / "candidate.txt"
    candidate.write_text("SHELL := /bin/bash\n", encoding="utf-8")
    manifest = root / "manifest.txt"
    manifest.write_text("candidate.txt\n", encoding="utf-8")
    result = run_verifier(manifest, root)
  check(result.returncode == 0, "system executable path passes")


def test_variable_relative_path_passes():
  with tempfile.TemporaryDirectory() as directory:
    root = make_repository(directory)
    candidate = root / "candidate.txt"
    candidate.write_text('archive="$archive/home/hngh"\n', encoding="utf-8")
    manifest = root / "manifest.txt"
    manifest.write_text("candidate.txt\n", encoding="utf-8")
    result = run_verifier(manifest, root)
  check(result.returncode == 0, "variable-relative path passes")


def test_symlink_candidate_refuses():
  with tempfile.TemporaryDirectory() as directory:
    root = make_repository(directory)
    target = root / "README.md"
    (root / "candidate.txt").symlink_to(target)
    manifest = root / "manifest.txt"
    manifest.write_text("candidate.txt\n", encoding="utf-8")
    result = run_verifier(manifest, root)
  check(result.returncode == 1, "symlink candidate refuses")
  check("candidate path is a symlink: candidate.txt" in result.stdout,
        "symlink candidate names its path")
  check(":refused" in result.stdout, "symlink candidate is a closed refusal")


def test_unreadable_candidate_refuses():
  with tempfile.TemporaryDirectory() as directory:
    root = make_repository(directory)
    candidate = root / "candidate.txt"
    candidate.write_text("fixture\n", encoding="utf-8")
    candidate.chmod(0)
    manifest = root / "manifest.txt"
    manifest.write_text("candidate.txt\n", encoding="utf-8")
    try:
      result = run_verifier(manifest, root)
    finally:
      candidate.chmod(0o600)
  check(result.returncode == 1, "unreadable candidate refuses")
  check("cannot read candidate: candidate.txt" in result.stdout,
        "unreadable candidate names its path")
  check(":refused" in result.stdout,
        "unreadable candidate reports a closed refusal")


def main():
  test_make_target_requires_manifest()
  test_missing_manifest_refuses()
  test_empty_manifest_refuses()
  test_duplicate_manifest_entry_refuses()
  test_manifest_path_policy_refuses()
  test_missing_or_directory_candidate_path_refuses()
  test_valid_manifest_runs_fast_gate()
  test_credential_shaped_content_refuses()
  test_unsafe_content_refuses()
  test_broken_markdown_link_refuses()
  test_trailing_whitespace_refuses()
  test_ignored_candidate_refuses()
  test_working_tree_report_observes_untracked_files()
  test_lisp_candidate_records_parenthesis_guard_evidence()
  test_unbalanced_lisp_candidate_refuses()
  test_inward_dependency_refuses()
  test_missing_parenthesis_guard_refuses()
  test_system_executable_path_passes()
  test_variable_relative_path_passes()
  test_symlink_candidate_refuses()
  test_unreadable_candidate_refuses()
  print(f"{CHECKS} candidate verifier checks passed.")


if __name__ == "__main__":
  main()
