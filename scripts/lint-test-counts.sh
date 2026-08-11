#!/usr/bin/env bash
# lint-test-counts.sh — Procedural test-count lint for hngh docs.
#
# Runs make test, extracts the actual check count from the lisp-unit2
# summary line ("Did N checks. Pass: N (100%)"), then checks specific
# current-state references in project docs against the actual count.
#
# Historical session records are NOT checked — they record the count at
# the time of that session, not the current state.
#
# Exit codes:
#   0 — all current-state references match actual count
#   1 — one or more current-state references are stale
#   2 — could not determine actual test count
#
# Usage:
#   ./scripts/lint-test-counts.sh              # run make test, then lint
#   ./scripts/lint-test-counts.sh --cache FILE # use cached test output
#
# SPDX-License-Identifier: AGPL-3.0-or-later
# SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# --- Parse args ---

CACHE_FILE=""
if [[ "${1:-}" == "--cache" && -n "${2:-}" ]]; then
  CACHE_FILE="$2"
fi

# --- Get actual test count ---

if [[ -n "$CACHE_FILE" && -f "$CACHE_FILE" ]]; then
  TEST_OUTPUT="$(cat "$CACHE_FILE")"
else
  echo "Running make test..." >&2
  TEST_OUTPUT="$(cd "$REPO_ROOT" && make test 2>&1)"
fi

ACTUAL_COUNT="$(echo "$TEST_OUTPUT" | grep -oP 'Did \K[0-9]+' | awk '{s+=$1} END {print s}')"

if [[ -z "$ACTUAL_COUNT" ]]; then
  echo "ERROR: could not parse test count from output" >&2
  echo "Looked for: 'Did N checks'" >&2
  exit 2
fi

echo "Actual test count: $ACTUAL_COUNT" >&2

# --- Check current-state references ---
#
# Only lines that claim the *current* test count. Historical session
# entries record counts at the time of that session — those are correct
# as-is and must not be flagged.
#
# AGENTS.md:     the "Tests" line in "Current state"
# roadmap.md:     the Status line and M-table rows
# work-sessions.md: NOT checked (all entries are historical records)

STALE=0
STALE_REFS=""

check_file() {
  local filepath="$1"
  local patterns="$2"
  local label="$3"

  [[ -f "$filepath" ]] || return 0

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local line_num
    line_num="$(echo "$line" | cut -d: -f1)"
    local content
    content="$(echo "$line" | cut -d: -f2-)"

    # Extract N/M patterns from this line
    while IFS= read -r match; do
      [[ -z "$match" ]] && continue
      local count="${match%%/*}"
      if [[ "$count" =~ ^[0-9]+$ && "$count" -gt 100 && "$count" != "$ACTUAL_COUNT" ]]; then
        STALE_REFS+="  $label:$line_num — $match (expected $ACTUAL_COUNT)\n"
        STALE=1
      fi
    done < <(echo "$content" | grep -oP '[0-9]+/[0-9]+' 2>/dev/null || true)

    # Also catch bare "N tests" / "N checks" patterns
    while IFS= read -r match; do
      [[ -z "$match" ]] && continue
      local count="${match%% *}"
      if [[ "$count" =~ ^[0-9]+$ && "$count" -gt 100 && "$count" != "$ACTUAL_COUNT" ]]; then
        STALE_REFS+="  $label:$line_num — $match (expected $ACTUAL_COUNT)\n"
        STALE=1
      fi
    done < <(echo "$content" | grep -oP '[0-9]+ (?=tests|checks)' 2>/dev/null || true)

  done < <(grep -nP "$patterns" "$filepath" 2>/dev/null || true)
}

# AGENTS.md — only the "Tests" line in "Current state"
check_file \
  "$REPO_ROOT/AGENTS.md" \
  '^\s*- \*\*Tests\*\*' \
  "AGENTS.md"

# Core documents are the current documentation surface. The former roadmap
# is archived and available only through a compatibility alias, so it is
# historical evidence rather than a current-state test-count claim.
for filepath in "$REPO_ROOT"/docs/core/*.md; do
  check_file \
    "$filepath" \
    'tests (green|passing) @|[0-9]+/[0-9]+ (tests|checks)' \
    "docs/core/$(basename "$filepath")"
done

# --- Report ---

if [[ "$STALE" -eq 1 ]]; then
  echo "FAIL: stale test count references found:" >&2
  echo -e "$STALE_REFS" >&2
  echo "Update these lines to $ACTUAL_COUNT/$ACTUAL_COUNT" >&2
  exit 1
fi

echo "OK: all current-state test count references match ($ACTUAL_COUNT)" >&2
exit 0
