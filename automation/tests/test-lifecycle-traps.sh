#!/usr/bin/env bash
# test-lifecycle-traps.sh — lifecycle accommodation (stall-recovery plan
# step 7), hermetic (sandbox tree, stub omp/bridge, sandbox HOME/TMPDIR,
# nothing real is ever launched):
#   a) SIGTERM mid-beat: the shutdown breadcrumb carries every in-flight
#      plan slug WITH its disposition (a fast sibling that already
#      finished shows cancelled; the slow one shows running) and the
#      beat exits 1 via the trap (clean exit, not a signal kill);
#   b) cold-start guard: the next beat after that unclean stop skips
#      the session batch (no double-spawn), still exits 0 and writes
#      the overnight-done breadcrumb that restores the ordering;
#   c) model-health defaults the failfirst state to the durable
#      $AUTOMATION_ROOT/state/failfirst dir (never /tmp); the
#      FAILFIRST_STATE_DIR override stays honored.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
td="$(mktemp -d)"
trap 'rm -rf "$td"' EXIT
fails=0
ck() {
  if [ "$2" = "$3" ]; then echo "ok: $1"; else
    echo "FAIL: $1 (want [$2] got [$3])"
    fails=$((fails + 1))
  fi
}
bad() {
  echo "FAIL: $1"
  fails=$((fails + 1))
}

auto="$td/automation"
mkdir -p "$auto/lib" "$auto/scripts" "$auto/logs" "$td/tmp" "$td/stubs" "$td/home"
for f in common.sh breadcrumbs.sh causes.sh notify-email.sh credentials.sh \
  params.sh context-pack.sh launch-session.sh model.sh model-demote.sh \
  failfirst.sh memory-gate.sh beat-blockers.sh; do
  cp "$root/lib/$f" "$auto/lib/"
done
cp "$root/scripts/overnight-cycle.sh" "$auto/scripts/"
cp "$root/scripts/accept-plans.py" "$auto/scripts/"
printf '# Inventory\nsessions-day-max\t12\ttest\ttest row\n' \
  >"$auto/cadence-params.tsv"
kernel="$td/kernel"
mkdir -p "$kernel/docs/project/plans" "$kernel/scripts"
printf '#!/usr/bin/env python3\nimport os, sys\nopen(os.environ["KERNEL_ALERTS"], "a").write(" ".join(sys.argv[1:]) + "\\n")\n' \
  >"$kernel/scripts/report-queue"
chmod +x "$kernel/scripts/report-queue"
KERNEL_ALERTS="$td/alerts.tsv"
: >"$KERNEL_ALERTS"
MARKER="$td/launched.marker"
STATE="$auto/STATE.md"

# omp stub: trap-fast's session completes immediately (cancelled);
# trap-slow's session blocks mid-flight until the test TERM's the tree
cat >"$td/stubs/omp" <<'STUB'
#!/usr/bin/env bash
printf 'launch:executor\n' >>"$MARKER"
case "$*" in *trap-slow*) sleep 60; exit 0 ;; esac
echo "step done"
exit 0
STUB
printf '#!/usr/bin/env bash\necho "run run-42 started $*"\n' \
  >"$td/stubs/bridge"
chmod +x "$td/stubs/omp" "$td/stubs/bridge"

plan_with_step() { # slug step -> writes an accepted plan
  printf '<!-- plan: status=accepted risk=normal author=operator -->\n# plan\n\n## Steps\n\n- [ ] %s -- verify: marker exists\n' "$2" \
    >"$kernel/docs/project/plans/$1.plan.md"
}
cat >"$td/cycle.sh" <<EOF
#!/usr/bin/env bash
exec env HNGH_HOME="$kernel" OVERNIGHT_LOCK="$td/cycle.lock" \
  OVERNIGHT_TIMEOUT="30" FAILFIRST_STATE_DIR="$td/ff" TMPDIR="$td/tmp" \
  HNGH_RAM_FLOOR_MB=1 \
  HOME="$td/home" BEAT_BLOCKERS_FILE="$td/blockers.tsv" \
  OMP_STUB="$td/stubs/omp" MARKER="$MARKER" FORETHOUGHT_DEPTH="1" \
  OMP_BRIDGE_BIN="$td/stubs/bridge" KERNEL_ALERTS="$KERNEL_ALERTS" \
  PATH="$td/stubs:/usr/bin:/bin" \
  bash "$auto/scripts/overnight-cycle.sh"
EOF
run_cycle() {
  bash "$td/cycle.sh"
}

# --- (a) SIGTERM mid-beat ----------------------------------------------------
plan_with_step trap-fast 'touch the fast sandbox marker'
plan_with_step trap-slow 'sleep on the slow sandbox marker'
: >"$MARKER"
setsid bash "$td/cycle.sh" >/dev/null 2>&1 &
cyc=$!
n=0
while [ "$n" -lt 75 ] && [ "$(wc -l <"$MARKER" 2>/dev/null)" -lt 2 ]; do
  n=$((n + 1))
  sleep 0.2
done
[ "$(wc -l <"$MARKER")" -ge 2 ] ||
  bad "both sessions in flight before TERM (marker=$(cat "$MARKER" 2>/dev/null))"
inflight="$(grep -l 'trap-fast' "$td/tmp"/hngh-overnight-inflight.* 2>/dev/null || true)"
ffdone="trap-fast$(printf '\t')cancelled"
n=0
while [ "$n" -lt 50 ] && ! grep -q "$ffdone" "$inflight" 2>/dev/null; do
  n=$((n + 1))
  sleep 0.2
done
grep -q "$ffdone" "$inflight" 2>/dev/null ||
  bad "fast sibling final disposition not recorded before TERM"
pgid="$(ps -o pgid= -p "$cyc" 2>/dev/null | tr -d ' ')"
if [ "$pgid" != "$cyc" ]; then
  bad "cycle is not its own process-group leader (pid=$cyc pgid=$pgid)"
else
  kill -TERM -- "-$pgid" 2>/dev/null || bad "could not signal the cycle group"
fi
wait "$cyc"
ck "SIGTERM mid-beat: trap exit 1 (clean, not signal-killed)" "1" "$?"
line="$(grep 'shutdown-signal' "$STATE" 2>/dev/null | tail -n 1)"
[ -n "$line" ] || bad "no shutdown-signal breadcrumb in STATE.md"
printf '%s' "$line" | grep -q 'signal=TERM' ||
  bad "breadcrumb missing signal=TERM: $line"
printf '%s' "$line" | grep -q 'trap-slow=running' ||
  bad "breadcrumb missing in-flight slug+running: $line"
printf '%s' "$line" | grep -q 'trap-fast=cancelled' ||
  bad "breadcrumb missing completed slug+cancelled: $line"
echo "ok: SIGTERM mid-beat breadcrumb carries slug+disposition pairs"

# --- (b) cold-start guard: next beat skips the batch -------------------------
: >"$MARKER"
n=0
# systemd KillMode=control-group simulation: GNU timeout moves the
# session command into its own process group, so the group TERM alone
# cannot reach every member. Sweep every live pid carrying the beat's
# sandbox env (TMPDIR is unique to this unit) until the tree is gone.
beat_pids() { grep -l "$td/tmp" /proc/[0-9]*/environ 2>/dev/null | cut -d/ -f3; }
while [ "$n" -lt 75 ] && [ -n "$(beat_pids)" ]; do
  for p in $(beat_pids); do kill -TERM "$p" 2>/dev/null; done
  n=$((n + 1))
  sleep 0.2
done
[ -z "$(beat_pids)" ] || bad "beat processes survived the sweep: $(beat_pids | tr '\n' ' ')"
flock -n "$td/cycle.lock" /bin/true 2>/dev/null ||
  bad "previous beat's lock never released"
: >"$MARKER"
run_cycle >"$td/run2.log" 2>&1
ck "next beat after unclean stop exits 0" "0" "$?"
grep -q 'cold-start-unclean' "$STATE" ||
  bad "no cold-start-unclean breadcrumb on the next beat (log=$(cat "$td/run2.log"); state=$(tail -n 3 "$STATE"))"
[ -s "$MARKER" ] &&
  bad "cold-start guard did not skip the batch (double-spawn: $(cat "$MARKER"))"
grep -q 'overnight-done' "$STATE" ||
  bad "ordering not restored (no overnight-done after the skip)"
echo "ok: cold-start guard skips one batch after an unclean stop"

# --- (c) model-health: durable failfirst dir, /tmp default gone --------------
mh="$td/mh"
mkdir -p "$mh/automation/lib" "$mh/automation/scripts" \
  "$mh/automation/state/failfirst"
cp "$root/scripts/model-health" "$mh/automation/scripts/"
cp "$root/lib/common.sh" "$root/lib/model-demote.sh" "$mh/automation/lib/"
printf 'speed=cautious\noks=7\nlast=2026-09-14T00:00:00Z\n' \
  >"$mh/automation/state/failfirst/failfirst-development"
mh_json() { # [extra env] -> model-health JSON
  env -u FAILFIRST_STATE_DIR "$@" bash "$mh/automation/scripts/model-health"
}
speed() { python3 -c 'import json, sys; print(json.load(sys.stdin)["failfirst"]["speed"])'; }
ck "model-health default reads durable state (speed)" "cautious" \
  "$(mh_json | speed)"
ck "model-health default reads durable state (oks)" "7" \
  "$(mh_json | python3 -c 'import json, sys; print(json.load(sys.stdin)["failfirst"]["oks"])')"
mkdir -p "$td/ff2"
printf 'speed=full\noks=1\n' >"$td/ff2/failfirst-development"
ck "FAILFIRST_STATE_DIR override still honored" "full" \
  "$(mh_json FAILFIRST_STATE_DIR="$td/ff2" | speed)"

echo "---"
[ "$fails" -eq 0 ] && echo "ALL PASS" || {
  echo "$fails FAILED"
  exit 1
}
