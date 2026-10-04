#!/usr/bin/env bash
# test-parallel.sh — run the automation gate suites in parallel.
#
# The suite list is extracted from `make -n test` so the Makefile recipe
# stays the single source of truth; this script never duplicates it.
# Each suite runs in its own log with its own wall time; failures print
# the failing log tail. Exit code is nonzero iff any suite failed.
#
# Knobs: GATE_JOBS (default: nproc, capped at 8).
set -u
cd "$(dirname "$0")/.."

JOBS="${GATE_JOBS:-$(nproc)}"
case "$JOBS" in *[!0-9]* | '') JOBS=8 ;; esac
[ "$JOBS" -le 0 ] && JOBS=8
[ "$JOBS" -gt 8 ] && JOBS=8

LOGDIR="$(mktemp -d /tmp/hngh-gate-parallel.XXXXXX)"
trap 'rm -rf "$LOGDIR"' EXIT

n=0
while IFS= read -r cmd; do
  n=$((n + 1))
  printf '%s\n' "$cmd" >"$LOGDIR/$(printf '%03d' "$n").cmd"
done < <(make -n test | sed 's/^[@-]\+//' | awk '!seen[$0]++' | grep -E '^(python3|bash) ')

[ "$n" -gt 0 ] || {
  echo "test-parallel: no suites extracted from 'make -n test'" >&2
  exit 2
}

echo "test-parallel: $n suites, jobs=$JOBS, logs=$LOGDIR"
SECONDS=0

ls "$LOGDIR"/*.cmd | xargs -n1 -P "$JOBS" bash -c '
  f=$1; base=${f%.cmd}; log="$base.log"
  s=$(date +%s)
  bash "$f" >"$log" 2>&1
  rc=$?
  e=$(date +%s)
  printf "%d %d %s\n" "$rc" "$((e - s))" "$(cat "$f")" > "$base.res"
  printf "[%s] rc=%d %ds %s\n" "$(date +%H:%M:%S)" "$rc" "$((e - s))" "$(cat "$f")"
' _

wall=$SECONDS

echo
echo "=== gate summary (recipe order) ==="
failed=0
for i in $(seq 1 "$n"); do
  base="$LOGDIR/$(printf '%03d' "$i")"
  if [ -f "$base.res" ]; then
    read -r rc secs cmd <"$base.res"
    if [ "$rc" -eq 0 ]; then
      printf 'ok    %3ds  %s\n' "$secs" "$cmd"
    else
      failed=$((failed + 1))
      printf 'FAIL  %3ds  %s\n' "$secs" "$cmd"
      echo "--- log tail: $cmd ---"
      tail -20 "$base.log"
    fi
  else
    failed=$((failed + 1))
    printf 'FAIL      ?  suite %03d (no result recorded)\n' "$i"
  fi
done

echo
if [ "$failed" -eq 0 ]; then
  echo "GATE-PARALLEL-RC=0  suites=$n wall=${wall}s jobs=$JOBS"
  exit 0
fi
echo "GATE-PARALLEL-RC=1  failed=$failed/$n wall=${wall}s jobs=$JOBS"
exit 1
