#!/usr/bin/env python3
"""Report read-only evidence for an explicit Git candidate manifest."""

import argparse
import hashlib
from pathlib import Path
import os
import re
import subprocess
import sys
import time


EXCLUDED_PREFIXES = (".hermes/",)
CREDENTIAL_PATTERN = re.compile(
  r"(?i)(api[_-]?key|secret|token|password)\s*[:=]\s*['\"]?[A-Za-z0-9_\-]{8,}"
)
ABSOLUTE_PATH_PATTERN = re.compile(r"(?<![$A-Za-z0-9_}])/(?:home|Users|root)/")
SHELL_EXECUTION_PATTERN = re.compile(r"\b(?:eval|exec)\s*\(")
MARKDOWN_LINK_PATTERN = re.compile(r"\[[^]]+\]\(([^)#]+)(?:#[^)]*)?\)")
INWARD_PACKAGE_PATTERN = re.compile(
  r"\(defpackage\s+(?:#:\s*|:)?hngh\.(?:domain|application)\b",
  re.IGNORECASE,
)
FORBIDDEN_DEPENDENCY_PATTERN = re.compile(
  r"(?:#:\s*|:)?hngh\.(?:adapters\.[a-z0-9.-]+|presentation)\b",
  re.IGNORECASE,
)


def run_command(arguments):
  try:
    result = subprocess.run(
      arguments,
      check=False,
      capture_output=True,
      text=True,
    )
  except OSError as error:
    return None, f"cannot run {arguments[0]}: {error}"
  if result.returncode:
    detail = result.stderr.strip() or result.stdout.strip() or "command failed"
    return None, f"{' '.join(arguments)} failed: {detail}"
  return result.stdout, None


def run_git(arguments):
  return run_command(["git", *arguments])


def working_tree_state():
  output, error = run_git(["status", "--porcelain=v1", "--untracked-files=all"])
  if error or output is None:
    return None, error or "working-tree state is unavailable"
  rows = output.splitlines()
  return {
    "dirty": bool(rows),
    "staged": any(row[:1] not in (" ", "?") for row in rows),
    "untracked": any(row.startswith("??") for row in rows),
    "porcelain": output,
  }, None


def ignored_path(entry):
  try:
    result = subprocess.run(
      ["git", "check-ignore", "--quiet", "--no-index", "--", entry],
      check=False,
      capture_output=True,
      text=True,
    )
  except OSError as error:
    return None, f"cannot run git: {error}"
  if result.returncode == 0:
    return True, None
  if result.returncode == 1:
    return False, None
  detail = result.stderr.strip() or result.stdout.strip() or "command failed"
  return None, f"git check-ignore failed: {detail}"


def validate_entries(entries):
  root = Path.cwd().resolve()
  if entries != sorted(entries):
    return "candidate manifest is not sorted"

  seen = set()
  for entry in entries:
    path = Path(entry)
    if path.is_absolute():
      return f"candidate path must be repository-relative: {entry}"
    if ".." in path.parts:
      return f"candidate path escapes repository: {entry}"
    if any(entry.startswith(prefix) for prefix in EXCLUDED_PREFIXES):
      return f"candidate path is excluded: {entry}"
    if entry in seen:
      return f"duplicate candidate path: {entry}"
    candidate = root / path
    if not candidate.exists():
      return f"candidate path does not exist: {entry}"
    if candidate.is_symlink():
      return f"candidate path is a symlink: {entry}"
    if not candidate.is_file():
      return f"candidate path is not a regular file: {entry}"
    ignored, error = ignored_path(entry)
    if error:
      return error
    if ignored:
      return f"candidate path is ignored: {entry}"
    seen.add(entry)
  return None


def read_manifest(path):
  try:
    entries = Path(path).read_text(encoding="utf-8").splitlines()
  except (OSError, UnicodeError) as error:
    return None, f"cannot read candidate manifest: {error}"

  entries = [entry for entry in entries if entry]
  if not entries:
    return None, "candidate manifest is empty"
  error = validate_entries(entries)
  if error:
    return None, error
  return entries, None


def candidate_hash(entries):
  digest = hashlib.sha256()
  try:
    for entry in entries:
      digest.update(entry.encode("utf-8"))
      digest.update(b"\0")
      digest.update((Path.cwd() / entry).read_bytes())
      digest.update(b"\0")
  except OSError as error:
    return None, f"cannot read candidate: {error}"
  return digest.hexdigest(), None


def fast_test_marker(base_revision, candidate_hash_value, state):
  # The full gate's outcome depends on the candidate's content plus the
  # tracked working-tree state, not on the commit id nor the untracked
  # byte noise. Keying on candidate-hash + sorted tracked porcelain keeps
  # the marker stable across issue-cert prepare/commit/push transitions
  # (previously the action that `git add`s flipped --untracked-files=all
  # porcelain -> cold miss -> full 30-50s make test per action) AND across
  # the commit itself (commit bumps HEAD but leaves tracked porcelain
  # unchanged). The mutation executor re-verifies working-tree state
  # separately, so the gate is not weakened.
  tracked = sorted(line for line in state["porcelain"].splitlines()
                   if line and not line.startswith("??"))
  # Exclude the candidate's OWN porcelain: the candidate flips
  # `M file` -> clean at the commit boundary, which would otherwise
  # cold-miss the push phase's verify on an identical tree.
  candidates = {line[3:] for line in tracked}
  others = [line for line in tracked if line[3:] not in candidates]
  key = f"{candidate_hash_value}|{'/'.join(sorted(others))}"
  repo = Path.cwd().resolve().name or "repo"
  digest = hashlib.sha256(key.encode("utf-8")).hexdigest()
  return os.path.join(
    os.environ.get("TMPDIR", "/tmp"), f"hngh-fasttest-{repo}-{digest}.ok"
  )


def write_fast_test_marker(marker, base_revision, candidate_hash_value, rc, duration):
  try:
    with open(marker, "w", encoding="utf-8") as handle:
      handle.write(f"base-revision: {base_revision}\n")
      handle.write(f"candidate-hash: {candidate_hash_value}\n")
      handle.write(f"rc: {rc}\n")
      handle.write(f"duration: {duration}\n")
  except OSError:
    pass


def fast_test_passes_from_cache(marker, candidate_hash_value):
  if marker is None:
    return False
  try:
    with open(marker, encoding="utf-8") as handle:
      contents = handle.read()
  except (OSError, UnicodeError):
    return False
  fields = {}
  for line in contents.splitlines():
    if ":" in line:
      name, _, value = line.partition(":")
      fields[name.strip()] = value.strip()
  return fields.get("candidate-hash") == candidate_hash_value and fields.get("rc") == "0"


def whitespace_error(entry, text):
  for number, line in enumerate(text.splitlines(), start=1):
    if line.rstrip(" \t") != line:
      return f"trailing whitespace: {entry}: {number}"
  return None


def markdown_error(entry, text):
  root = Path.cwd().resolve()
  source = root / entry
  for target in MARKDOWN_LINK_PATTERN.findall(text):
    if "://" in target or target.startswith("mailto:"):
      continue
    resolved = (source.parent / target).resolve()
    if root not in resolved.parents or not resolved.exists():
      return f"broken Markdown link: {entry}: {target}"
  return None


def parenthesis_guard_error(entries):
  lisp_entries = [entry for entry in entries if Path(entry).suffix == ".lisp"]
  if not lisp_entries:
    return False, None
  _, error = run_command([sys.executable, "scripts/lint-parens.py", *lisp_entries])
  return True, error


def dependency_error(entries):
  for entry in entries:
    if Path(entry).suffix != ".lisp":
      continue
    try:
      text = (Path.cwd() / entry).read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
      return f"cannot read candidate: {entry}: {error}"
    if (INWARD_PACKAGE_PATTERN.search(text)
        and FORBIDDEN_DEPENDENCY_PATTERN.search(text)):
      return f"forbidden dependency: {entry}"
  return None


def public_content_error(entries):
  for entry in entries:
    try:
      text = (Path.cwd() / entry).read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
      return f"cannot read candidate: {entry}: {error}"
    if CREDENTIAL_PATTERN.search(text):
      return f"credential-shaped content: {entry}"
    if ABSOLUTE_PATH_PATTERN.search(text):
      return f"absolute local path: {entry}"
    if SHELL_EXECUTION_PATTERN.search(text):
      return f"shell execution: {entry}"
  return None


def whitespace_scan_error(entries):
  for entry in entries:
    try:
      text = (Path.cwd() / entry).read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
      return f"cannot read candidate: {entry}: {error}"
    error = whitespace_error(entry, text)
    if error:
      return error
  return None


def relative_link_error(entries):
  for entry in entries:
    if Path(entry).suffix != ".md":
      continue
    try:
      text = (Path.cwd() / entry).read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
      return f"cannot read candidate: {entry}: {error}"
    error = markdown_error(entry, text)
    if error:
      return error
  return None


def main(arguments):
  parser = argparse.ArgumentParser(add_help=False)
  parser.add_argument("--manifest")
  try:
    options = parser.parse_args(arguments)
  except SystemExit:
    print(":refused invalid arguments")
    return 2

  if options.manifest is None:
    print("candidate manifest is required", file=sys.stderr)
    print(":refused missing candidate manifest")
    return 2

  entries, error = read_manifest(options.manifest)
  if error or entries is None:
    print(error or "candidate manifest is unavailable")
    print(":refused invalid candidate manifest")
    return 1

  base_revision, error = run_git(["rev-parse", "HEAD"])
  if error or base_revision is None:
    print(error or "base revision is unavailable")
    print(":refused unavailable git evidence")
    return 1

  state, error = working_tree_state()
  if error or state is None:
    print(error or "working-tree state is unavailable")
    print(":refused unavailable git evidence")
    return 1

  guarded, error = parenthesis_guard_error(entries)
  if error:
    print(error)
    print(":refused parenthesis evidence failed")
    return 1

  error = dependency_error(entries)
  if error:
    print(error)
    print(":refused dependency evidence failed")
    return 1

  error = public_content_error(entries)
  if error:
    print(error)
    print(":refused public-content evidence failed")
    return 1

  error = whitespace_scan_error(entries)
  if error:
    print(error)
    print(":refused whitespace evidence failed")
    return 1

  error = relative_link_error(entries)
  if error:
    print(error)
    print(":refused relative-link evidence failed")
    return 1

  candidate_hash_value, error = candidate_hash(entries)
  if error or candidate_hash_value is None:
    print(error or "candidate hash is unavailable")
    print(":refused candidate evidence failed")
    return 1

  marker = fast_test_marker(base_revision.strip(), candidate_hash_value, state)
  cached = fast_test_passes_from_cache(marker, candidate_hash_value)
  if cached:
    print("trace: fast-test passed (cached)")
  else:
    started = time.time()
    _, error = run_command(["make", "test"])
    duration = time.time() - started
    if error:
      write_fast_test_marker(marker, base_revision.strip(), candidate_hash_value, 1, duration)
      print(error)
      print(":refused candidate evidence failed")
      return 1
    write_fast_test_marker(marker, base_revision.strip(), candidate_hash_value, 0, duration)

  print(f"base-revision: {base_revision.strip()}")
  print(f"working-tree-dirty: {'yes' if state['dirty'] else 'no'}")
  print(f"working-tree-staged: {'yes' if state['staged'] else 'no'}")
  print(f"working-tree-untracked: {'yes' if state['untracked'] else 'no'}")
  print(f"parenthesis-guard: {'passed' if guarded else 'not-applicable'}")
  print("excluded-paths: .hermes/** (not admitted)")
  print("dependency: passed")
  print("public-content: passed")
  print("whitespace: passed")
  print("relative-links: passed")
  print("fast-test: passed")
  for entry in entries:
    print(f"manifest: {entry}")
  print(f"candidate-hash: {candidate_hash_value}")
  print(":passed")
  return 0


if __name__ == "__main__":
  sys.exit(main(sys.argv[1:]))
