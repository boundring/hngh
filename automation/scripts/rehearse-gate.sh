#!/usr/bin/env bash
# rehearse-gate.sh — run a repo's gate in an isolated git-archive copy.
#
# Rehearsal-lane plan step 2 (2026-09-09, design
# docs/design/rehearsal-and-self-order.md beat 4): gate pre-validation
# unpacks `git archive HEAD` into a temp dir and runs the gate there, so
# parallel delegated sessions never contend for compile/CPU with the
# acceptance sweep (the 2026-09-09 kernel/automation gate-red-rc2 blocks
# were load-correlated, and the 2026-09-02 routed-review wake proved an
# archived tree green while the working tree was red).
#
# Usage: rehearse-gate.sh [--gate CMD] [--log FILE] -- REPO [CANDIDATE...]
#   REPO        the repo to archive (any directory inside it works)
#   CANDIDATE   repo-relative working-tree files overlaid onto the
#               archived copy (uncommitted candidate edits rehearsed
#               without touching the working tree)
#   --gate CMD  gate command (default: make test). Run with $PWD set to
#               the unpacked repo root.
#   --log FILE  append one breadcrumb row per rehearsal (ts | repo |
#               gate | rc) so callers see the verdict without parsing
#               gate output. Default: no breadcrumb.
# Prints the gate's exit code and, on failure, the last failing check
# only (tail of gate output). Exit codes: 0 gate green, gate's rc when
# red, 2 refuse (non-git repo, escaping/missing candidate, no repo arg).
set -u

usage() { printf 'usage: %s [--gate CMD] [--log FILE] -- REPO [CANDIDATE...]\n' "$0" >&2; exit 2; }

GATE_CMD="make test"
LOG_FILE="${REHEARSE_LOG:-}"  # env seam (matches accept-plans' ACCEPT_LOG)
while [ $# -gt 0 ]; do
  case "$1" in
    --gate) [ $# -ge 2 ] || usage; GATE_CMD="$2"; shift 2 ;;
    --log)  [ $# -ge 2 ] || usage; LOG_FILE="$2"; shift 2 ;;
    --) shift; break ;;
    *) usage ;;
  esac
done
[ $# -ge 1 ] || usage
REPO_ARG="$1"; shift

# resolve to an absolute repo root; refuse anything that is not a work tree
REPO_DIR="$(cd "$REPO_ARG" 2>/dev/null && pwd)" || {
  printf 'rehearse-gate: refuse: not a directory: %s\n' "$REPO_ARG" >&2; exit 2; }
REPO_ROOT="$(git -C "$REPO_DIR" rev-parse --show-toplevel 2>/dev/null)" || {
  printf 'rehearse-gate: refuse: not a git work tree: %s\n' "$REPO_ARG" >&2; exit 2; }

TD="$(mktemp -d "${TMPDIR:-/tmp}/hngh-rehearse-XXXXXX")"
trap 'rm -rf "$TD"' EXIT

# unpack HEAD: only committed content, working-tree dirt never leaks in
if ! git -C "$REPO_ROOT" archive HEAD | tar -x -C "$TD"; then
  printf 'rehearse-gate: refuse: git archive HEAD failed: %s\n' "$REPO_ROOT" >&2
  exit 2
fi

# overlay named candidates from the working tree (repo-relative paths
# only; escaping paths fail closed)
REPO_ROOT="${REPO_ROOT%/}"
for cand in "$@"; do
  case "$cand" in
    /*|*..*) printf 'rehearse-gate: refuse: candidate escapes the repo or is absolute: %s\n' "$cand" >&2; exit 2 ;;
  esac
  src="$REPO_ROOT/$cand"
  [ -f "$src" ] || {
    printf 'rehearse-gate: refuse: candidate not a working-tree file: %s\n' "$cand" >&2
    exit 2
  }
  dst="$TD/$(dirname "$cand")"
  mkdir -p "$dst" || { printf 'rehearse-gate: refuse: cannot stage candidate: %s\n' "$cand" >&2; exit 2; }
  cp "$src" "$dst/" || exit 2
done

RC=0
( cd "$TD" && $GATE_CMD ) > "$TD/gate.out" 2>&1 || RC=$?
printf 'gate rc=%d\n' "$RC" >&2
if [ "$RC" -ne 0 ]; then
  # last failing check only: tail of the gate output
  printf '%s\n' '--- last failing check (tail) ---' >&2
  tail -n 15 "$TD/gate.out" >&2
fi

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
if [ -n "$LOG_FILE" ]; then
  printf '%s | repo=%s | gate=%s | rc=%d\n' "$TS" "$REPO_ROOT" "$GATE_CMD" "$RC" >> "$LOG_FILE" 2>/dev/null
fi
exit "$RC"
