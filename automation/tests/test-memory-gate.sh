#!/usr/bin/env bash
# test-memory-gate.sh — RAM belt gate (plan
# 2026-09-22-ram-guardrails-dashboard-controls step 2).
#
# Behavioral: memory_gate rc 0 above the floor / rc 1 + breadcrumb row
# below it; floor precedence env HNGH_RAM_FLOOR_MB > cadence-params row
# ram-gate-floor-mb > default 2048; unreadable /proc/meminfo fails OPEN
# (the gate is a belt — a bogus probe must never stall every tick).
# Source-assert the two wire-ins: cadence-tick gates rapid tiers only;
# overnight-cycle reuses the crash-net STOP=1 flag (same pattern as
# test_retarget source-asserts).
#
# Hermetic: real /proc/meminfo read (present on any Linux dev box),
# fake AUTOMATION_ROOT for the param row, STATE_FILE in a temp dir;
# floors are built relative to live MemAvailable so the test does not
# depend on machine RAM.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d /tmp/hngh-memory-gate-test.XXXXXX)"
trap 'rm -rf "$tmp"' EXIT
export STATE_FILE="$tmp/state.tsv"
fails=0
ck() { # desc expected actual
  if [ "$2" = "$3" ]; then echo "ok: $1"; else
    echo "FAIL: $1 (expected=$2 actual=$3)"
    fails=$((fails + 1))
  fi
}

avail="$(awk '/^MemAvailable:/ {printf "%d", $2/1024; exit}' /proc/meminfo)"
ck "precondition: MemAvailable readable" "yes" "$([ -n "$avail" ] && echo yes || echo no)"

# fake automation root: memory-gate.sh + params.sh + a param-row floor
fake="$tmp/auto"
mkdir -p "$fake/lib"
cp "$root/lib/memory-gate.sh" "$root/lib/params.sh" "$fake/lib/"
cp "$root/lib/breadcrumbs.sh" "$fake/lib/"
printf 'ram-gate-floor-mb\t%s\ttest\ttest row\n' "$((avail / 2))" >"$fake/cadence-params.tsv"

run_gate() { # extra env via caller; prints rc
  (
    export AUTOMATION_ROOT="$fake" JOB_NAME=test-job
    . "$fake/lib/memory-gate.sh"
    memory_gate
  ) >/dev/null 2>&1
  echo $?
}
crumb_rows() { grep -c "memory-gate" "$STATE_FILE" 2>/dev/null || true; }

# 1) above a high floor: continue, no breadcrumb
: >"$STATE_FILE"
ck "above floor rc 0" "0" "$(HNGH_RAM_FLOOR_MB=1 run_gate)"
ck "above floor writes no breadcrumb" "0" "$(crumb_rows)"

# 2) below floor: rc 1 + one breadcrumb row
: >"$STATE_FILE"
ck "below floor rc 1" "1" "$(HNGH_RAM_FLOOR_MB=$((avail + 500)) run_gate)"
ck "below floor breadcrumbs once" "1" "$(crumb_rows)"

# 3) param row floor (avail/2) beats the 2048 default; env beats the row
: >"$STATE_FILE"
ck "param row floor accepted (rc 0)" "0" "$(run_gate)"
ck "param-row pass writes no breadcrumb" "0" "$(crumb_rows)"
: >"$STATE_FILE"
ck "env floor beats param row" "1" "$(HNGH_RAM_FLOOR_MB=$((avail + 500)) run_gate)"

# 4) unreadable meminfo fails OPEN
: >"$STATE_FILE"
rc="$(
  (
    export AUTOMATION_ROOT="$fake" JOB_NAME=test-job
    mem_available_mb() { echo ""; }
    . "$fake/lib/memory-gate.sh"
    memory_gate
  ) >/dev/null 2>&1
  echo $?
)"
ck "unreadable meminfo fails open (rc 0)" "0" "$rc"
ck "fail-open writes no breadcrumb" "0" "$(crumb_rows)"

# 5) source asserts: wire-ins present and correctly shaped
tick="$root/jobs/cadence-tick.sh"
ck "cadence-tick sources memory-gate.sh" "1" "$(grep -c 'lib/memory-gate.sh' "$tick")"
ck "cadence-tick gates rapid tiers only" "1" \
  "$(grep -c '^30m | 10m | 5m | 1m)' "$tick")"
oc="$root/scripts/overnight-cycle.sh"
ck "overnight sources memory-gate.sh" "1" "$(grep -c 'lib/memory-gate.sh' "$oc")"
ck "overnight gate sets STOP=1 on refusal" "1" \
  "$(grep -c 'memory_gate; then STOP=1' "$oc")"

if [ "$fails" -gt 0 ]; then
  echo "memory-gate contract: $fails FAILURES"
  exit 1
fi
echo "memory-gate contract: all cases passed"
