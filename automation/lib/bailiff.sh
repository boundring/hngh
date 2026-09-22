#!/usr/bin/env bash
# bailiff — charter branch check for the executive surface (plan
# 2026-09-22-federal-branches-occupancy step 1). Read-only: audits the ng
# ledger via ng/watch.py --bailiff and reports whether executive work may
# proceed. Findings halt (rc 1, breadcrumb); a fault fails OPEN (rc 0 +
# bailiff-fault breadcrumb) — the gate is a belt, a bogus probe must never
# stall every tier (same discipline as memory-gate.sh's fail-open).
set -u
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/breadcrumbs.sh"

bailiff_check() { # -> rc 0 proceed (or fault, fail open) / rc 1 halt
  local out rc=0
  if ! out="$(python3 "$AUTOMATION_ROOT/ng/watch.py" --bailiff 2>&1)"; then
    rc=$?
  fi
  # stdout verdict is the LAST line; stderr finding detail precedes it.
  case "${out##*$'\n'}" in
  "bailiff: clean") return 0 ;;
  "bailiff: halt")
    breadcrumb "${JOB_NAME:-bailiff}" "bailiff-halt" \
      "watch audit findings — executive tier halted: ${out%%$'\n'*}"
    return 1
    ;;
  *)
    breadcrumb "${JOB_NAME:-bailiff}" "bailiff-fault" \
      "watch audit rc=$rc (fail open): $out"
    return 0
    ;;
  esac
}
