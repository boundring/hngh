#!/usr/bin/env bash
# test-overnight-forethought.sh — forethought dream pass, hermetic
# (design: docs/research/2026-09-10-forethought-and-decomposition.md s2/s3/s5):
#   a) depth=0 -> no dream launch (one session, executor only)
#   b) depth=1 + kernel-touching step -> ONE dream launch with role=dream
#      (dream pack carries the dream role hint; five-field prompt; the
#      dream's sanity-checks are appended to the executor prompt)
#   c) depth=1 + mechanical step -> no dream
#   d) dream dead/empty -> fail-open breadcrumb, executor still launches
# Sandbox tree, stub omp/bridge — nothing real is ever launched.
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
 context-pack.sh launch-session.sh model.sh model-demote.sh failfirst.sh; do
 cp "$root/lib/$f" "$auto/lib/"
done
cp "$root/scripts/overnight-cycle.sh" "$auto/scripts/"
cp "$root/scripts/accept-plans.py" "$auto/scripts/"
printf '# Inventory\nsessions-day-max\t8\ttest\ttest row\n' \
 >"$auto/cadence-params.tsv"
kernel="$td/kernel"
mkdir -p "$kernel/docs/project/plans"
stubdir="$td/stubs"
mkdir -p "$stubdir"
MARKER="$td/launched.marker"
STATE="$auto/STATE.md"

# omp stub: records args; a dream session (objective contains 'DREAM pass')
# writes its dream brief to $DREAM_OUT unless DREAM_FAIL=1 (then it dies).
cat >"$stubdir/omp" <<'STUB'
#!/usr/bin/env bash
case "$*" in
 *'DREAM pass'*|*'dream brief'*)
  printf 'launch:dream\n' >>"$MARKER"
  [ "${DREAM_FAIL:-0}" = 1 ] && exit 1
  [ -n "${DREAM_OUT:-}" ] && printf 'sanity-checks: the sandbox marker exists\n' >"$DREAM_OUT"
  ;;
 *)
  printf 'launch:executor\n' >>"$MARKER"
  ;;
esac
exit 0
STUB
chmod +x "$stubdir/omp"
printf '#!/usr/bin/env bash\necho "run run-42 started $*"\n' >"$stubdir/bridge-stub.sh"
chmod +x "$stubdir/bridge-stub.sh"

plan_with_step() { # step -> writes accepted seed plan
 printf '<!-- plan: status=accepted risk=normal author=operator -->\n# seed plan\n\n## Steps\n\n- [ ] %s -- verify: marker exists\n' "$1" \
  >"$kernel/docs/project/plans/seed.plan.md"
}

run_cycle() {
 env HNGH_HOME="$kernel" OVERNIGHT_LOCK="$td/cycle.lock" \
  OVERNIGHT_TIMEOUT="5" FAILFIRST_STATE_DIR="$td/ff" \
  OMP_STUB="$stubdir/omp" MARKER="$MARKER" DREAM_OUT="${DREAM_OUT:-}" \
  DREAM_FAIL="${DREAM_FAIL:-0}" FORETHOUGHT_DEPTH="${FORETHOUGHT_DEPTH:-}" \
  OMP_BRIDGE_BIN="$stubdir/bridge-stub.sh" \
  PATH="$stubdir:/usr/bin:/bin" \
  bash "$auto/scripts/overnight-cycle.sh"
}
reset_runs() {
 : >"$MARKER"
 rm -f "$STATE"
 rm -rf "$td/ff"
}

# --- (a) depth=0: no dream launch ------------------------------------------
reset_runs
plan_with_step 'update src/foo guard'
DREAM_OUT="$auto/prompts/overnight/seed.dream.md" FORETHOUGHT_DEPTH=0 run_cycle >/dev/null 2>&1
[ "$?" -eq 0 ] || fail "depth=0 cycle exited non-zero"
n="$(wc -l <"$MARKER")"
[ "$n" -eq 1 ] || fail "depth=0 launched $n sessions, expected 1 (executor only)"
grep -q 'launch:dream' "$MARKER" && fail "depth=0 launched a dream session"
ok "depth=0: no dream launch, executor only"

# --- (b) depth=1 + kernel-touching step: dream runs, executor is dream-informed
reset_runs
plan_with_step 'update src/foo guard'
DREAM_OUT="$auto/prompts/overnight/seed.dream.md" FORETHOUGHT_DEPTH=1 run_cycle >/dev/null 2>&1
[ "$?" -eq 0 ] || fail "depth=1 kernel step cycle exited non-zero"
n="$(wc -l <"$MARKER")"
[ "$n" -eq 2 ] || fail "depth=1 kernel step launched $n sessions, expected 2 (dream + executor)"
[ "$(head -1 "$MARKER")" = "launch:dream" ] || fail "first launch was not the dream session"
# dream role hint present in the dream session's context pack
grep -q 'advisory-only dream pass' \
 "$auto/prompts/overnight/seed-dream.context.txt" ||
 fail "dream context pack missing the dream role hint"
# five-field dream prompt exists and cites the design schema, not a restatement
dp="$auto/prompts/overnight/seed.dream-prompt.md"
grep -q 'requirements' "$dp" && grep -q 'sanity-checks' "$dp" ||
 fail "dream prompt missing the five dream fields"
grep -q '2026-09-10-forethought-and-decomposition.md' "$dp" ||
 fail "dream prompt does not cite the design doc field schema"
# the executor prompt carries the dream's sanity-checks
grep -q 'Dream sanity-checks' "$auto/prompts/overnight/seed.md" ||
 fail "executor prompt missing dream sanity-checks"
ok "depth=1 kernel step: dream launched (role=dream pack, five-field prompt), executor dream-informed"

# --- (c) depth=1 + mechanical step: no dream --------------------------------
reset_runs
plan_with_step 'touch the sandbox marker'
DREAM_OUT="$auto/prompts/overnight/seed.dream.md" FORETHOUGHT_DEPTH=1 run_cycle >/dev/null 2>&1
n="$(wc -l <"$MARKER")"
[ "$n" -eq 1 ] || fail "mechanical step launched $n sessions, expected 1 (no dream)"
grep -q 'launch:dream' "$MARKER" && fail "mechanical step dreamed"
ok "depth=1 mechanical step: no dream"

# --- (d) dream dead: fail-open breadcrumb, executor still launches ----------
reset_runs
plan_with_step 'update src/foo guard'
DREAM_OUT="$auto/prompts/overnight/seed.dream.md" DREAM_FAIL=1 \
 FORETHOUGHT_DEPTH=1 run_cycle >/dev/null 2>&1
[ "$?" -eq 0 ] || fail "dream-failure cycle exited non-zero"
n="$(wc -l <"$MARKER")"
[ "$n" -eq 2 ] || fail "dream-failure launched $n sessions, expected 2 (dead dream + executor)"
grep -q 'forethought-dream-skip' "$STATE" ||
 fail "no forethought-dream-skip breadcrumb on dream failure"
grep -q 'Dream sanity-checks' "$auto/prompts/overnight/seed.md" &&
 fail "executor prompt got sanity-checks from a dead dream"
ok "dream failure: fail-open breadcrumb + step still launches undreamed"

echo "overnight-forethought contract: all cases passed"
