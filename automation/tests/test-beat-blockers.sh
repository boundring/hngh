#!/usr/bin/env bash
# test-beat-blockers.sh — the orchestrator remediation loop (as-above-so-
# below, 2026-09-11), hermetic (sandbox tree, stub omp/bridge, nothing
# real is ever launched):
#   a) a blocker row forces the dream on a mechanical step; the dream
#      prompt carries the blocker line with the cause class
#   b) success clears the row
#   c) a second consecutive same-cause failure parks the plan
#      (blocker-escalate-n reached) + beat-parked alert
#   d) a parked plan leaves the rotation (no session launched for it)
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
td="$(mktemp -d)"
trap 'rm -rf "$td"' EXIT
ok() { echo "ok: $1"; }
fail() {
 echo "FAIL: $1"
 exit 1
}

auto="$td/automation"
mkdir -p "$auto/lib" "$auto/scripts" "$auto/logs"
for f in common.sh breadcrumbs.sh causes.sh notify-email.sh params.sh \
 context-pack.sh launch-session.sh model.sh model-demote.sh failfirst.sh \
 beat-blockers.sh; do
 cp "$root/lib/$f" "$auto/lib/"
done
cp "$root/scripts/overnight-cycle.sh" "$auto/scripts/"
cp "$root/scripts/accept-plans.py" "$auto/scripts/"
printf '# Inventory\nsessions-day-max\t12\ttest\ttest row\n' \
 >"$auto/cadence-params.tsv"
kernel="$td/kernel"
mkdir -p "$kernel/docs/project/plans" "$kernel/scripts"
stubdir="$td/stubs"
mkdir -p "$stubdir"
MARKER="$td/launched.marker"
STATE="$auto/STATE.md"
BLOCKERS="$auto/state/beat-blockers.tsv"

# omp stub: dream sessions write the brief; executors succeed or die with
# a deterministic bestiary tail ("budget exhausted" -> bad-execution)
cat >"$stubdir/omp" <<'STUB'
#!/usr/bin/env bash
case "$*" in
 *'DREAM pass'*|*'dream brief'*)
  printf 'launch:dream\n' >>"$MARKER"
  [ -n "${DREAM_OUT:-}" ] && printf 'sanity-checks: the sandbox marker exists\n' >"$DREAM_OUT"
  ;;
 *)
  printf 'launch:executor\n' >>"$MARKER"
  if [ "${EXEC_FAIL:-0}" = 1 ]; then
   echo "budget exhausted mid-step"
   exit 1
  fi
  echo "step done"
  ;;
esac
exit 0
STUB
chmod +x "$stubdir/omp"
printf '#!/usr/bin/env bash\necho "run run-42 started $*"\n' >"$stubdir/bridge-stub.sh"
chmod +x "$stubdir/bridge-stub.sh"
printf '#!/usr/bin/env python3\nimport os\nopen(os.environ["KERNEL_ALERTS"], "a").write(" ".join(os.sys.argv) + "\\n")\n' \
 >"$kernel/scripts/report-queue"
chmod +x "$kernel/scripts/report-queue"
KERNEL_ALERTS="$td/alerts.tsv"

plan_with_step() { # file step -> writes an accepted plan
 printf '<!-- plan: status=accepted risk=normal author=operator -->\n# plan\n\n## Steps\n\n- [ ] %s -- verify: marker exists\n' "$2" \
  >"$kernel/docs/project/plans/$1.plan.md"
}

run_cycle() {
 env HNGH_HOME="$kernel" OVERNIGHT_LOCK="$td/cycle.lock" \
  OVERNIGHT_TIMEOUT="5" FAILFIRST_STATE_DIR="$td/ff" \
  BEAT_BLOCKERS_FILE="$BLOCKERS" \
  OMP_STUB="$stubdir/omp" MARKER="$MARKER" \
  DREAM_OUT="${DREAM_OUT:-}" EXEC_FAIL="${EXEC_FAIL:-0}" \
  FORETHOUGHT_DEPTH="${FORETHOUGHT_DEPTH:-1}" \
  OMP_BRIDGE_BIN="$stubdir/bridge-stub.sh" \
  KERNEL_ALERTS="$KERNEL_ALERTS" \
  PATH="$stubdir:/usr/bin:/bin" \
  bash "$auto/scripts/overnight-cycle.sh"
}
seed_row() { # slug cause attempts — pre-seed a cycle-owned blocker row
 printf 'blk-test\t%s\t%s\t2026-09-11T00:00:00Z\t%s\tactive\n' \
  "$1" "$2" "${3:-1}" >>"$BLOCKERS"
}
seed_parked_row() { # slug cause attempts last-update — pre-seed a parked row
 printf 'blk-test\t%s\t%s\t2026-09-11T00:00:00Z\t%s\tparked\t%s\n' \
  "$1" "$2" "${3:-2}" "${4:-2026-09-11T00:00:00Z}" >>"$BLOCKERS"
}

# --- (u1) blocker_tick: parked row older than cooldown unparks, resets ------
rm -rf "$auto/state"
mkdir -p "$auto/state"
: >"$BLOCKERS"
. "$root/lib/beat-blockers.sh"
BEAT_BLOCKERS_FILE="$BLOCKERS"
seed_parked_row old bad-execution 2 2020-01-01T00:00:00Z
blocker_tick 24
awk -F'\t' -v OFS='\t' '$2=="old" && $6=="active" && $5==0 {ok=1} END{exit !ok}' "$BLOCKERS" ||
 fail "blocker_tick did not unpark the expired parked row (state+attempts reset)"
ok "blocker_tick: parked row older than cooldown -> active, attempts reset"

# --- (u2) blocker_tick: parked row within cooldown stays parked -------------
rm -f "$BLOCKERS"
seed_parked_row fresh bad-execution 2 "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
BEAT_BLOCKERS_FILE="$BLOCKERS" blocker_tick 24
awk -F'\t' -v OFS='\t' '$2=="fresh" && $6=="parked" && $5==2 {ok=1} END{exit !ok}' "$BLOCKERS" ||
 fail "blocker_tick unparked a row inside the cooldown window"
ok "blocker_tick: parked row within cooldown stays parked"

# --- (u3) unparked plan re-enters the rotation ------------------------------
rm -f "$MARKER" "$STATE"
rm -rf "$td/ff"
seed_parked_row old bad-execution 2 2020-01-01T00:00:00Z
plan_with_step old 'touch the sandbox marker'
DREAM_OUT="$auto/prompts/overnight/old.dream.md" run_cycle >/dev/null 2>&1
[ "$?" -eq 0 ] || fail "unpark cycle exited non-zero"
grep -q '^launch:dream$' "$MARKER" || fail "auto-unparked plan did not re-enter the rotation"
[ -f "$BLOCKERS" ] && grep -q 'old' "$BLOCKERS" && fail "unparked row did not clear on success"
ok "auto-unparked plan re-enters the rotation (row consumed: tick reset then success clears)"

# --- (a) blocker row forces the dream on a mechanical step -----------------
rm -f "$MARKER" "$STATE" "$BLOCKERS"
rm -f "$kernel"/docs/project/plans/*.plan.md
mkdir -p "$auto/state"
seed_row seed bad-execution 1
plan_with_step seed 'touch the sandbox marker'
DREAM_OUT="$auto/prompts/overnight/seed.dream.md" run_cycle >/dev/null 2>&1
[ "$?" -eq 0 ] || fail "blocker cycle exited non-zero"
grep -q '^launch:dream$' "$MARKER" || fail "blocker row did not force the dream"
grep -q 'cause class bad-execution' "$auto/prompts/overnight/seed.dream-prompt.md" ||
 fail "dream prompt missing the blocker cause-class line"
ok "blocker row forces dream + carries the cause-class line"

# --- (b) success clears the row --------------------------------------------
rm -f "$MARKER" "$STATE"
seed_row seed bad-execution
run_cycle >/dev/null 2>&1
n="$(wc -l <"$MARKER")"
[ "$n" -eq 2 ] || fail "success run launched $n sessions, expected 2 (dream + executor)"
[ -f "$BLOCKERS" ] && grep -q 'seed' "$BLOCKERS" && fail "success did not clear the blocker row"
ok "success clears the blocker row"

# --- (c) second consecutive same-cause failure parks the plan --------------
rm -f "$MARKER" "$STATE"
seed_row seed bad-execution 1 # one death already recorded
plan_with_step seed 'touch the sandbox marker'
EXEC_FAIL=1 DREAM_OUT="$auto/prompts/overnight/seed.dream.md" run_cycle >/dev/null 2>&1
[ "$?" -eq 0 ] || fail "escalation cycle exited non-zero"
awk -F'\t' -v OFS='\t' '$2=="seed" && $6=="parked" {p=1} END{exit !p}' "$BLOCKERS" ||
 fail "second same-cause death did not park the blocker row"
grep -q 'blocker-parked' "$STATE" || fail "no blocker-parked breadcrumb"
grep -q 'beat-parked:seed' "$KERNEL_ALERTS" || fail "no beat-parked alert row"
ok "second same-cause dream-informed failure parks the plan (bounded)"

# --- (d) a parked plan leaves the rotation ---------------------------------
rm -f "$MARKER" "$STATE"
rm -rf "$td/ff"
rm -f "$kernel"/docs/project/plans/*.plan.md
plan_with_step alive 'touch the sandbox marker'
run_cycle >/dev/null 2>&1
[ "$?" -eq 0 ] || fail "skip cycle exited non-zero"
grep -q '^launch:.*seed' "$MARKER" && fail "parked plan still launched"
grep -q 'launch:executor' "$MARKER" || fail "healthy sibling plan did not run"
ok "parked plan leaves the rotation; sibling plan still runs"

echo "beat-blockers contract: all cases passed"
