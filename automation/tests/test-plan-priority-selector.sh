#!/usr/bin/env bash
# test-plan-priority-selector.sh — selector priority support (plan
# 2026-09-09-automation-schedule-optimization step 2), hermetic (sandbox
# tree, stub omp/bridge — nothing real is ever launched):
#   a) an accepted plan carrying `priority=high` in the front-matter
#      comment sorts ahead of a non-flagged plan that wins on filename
#      order (slot 0 = the flagged plan)
#   b) multiple `priority=high` plans keep filename order among
#      themselves
#   c) no flag anywhere preserves the current filename order
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
printf '# Inventory\nsessions-day-max\t8\ttest\ttest row\n' \
 >"$auto/cadence-params.tsv"
kernel="$td/kernel"
mkdir -p "$kernel/docs/project/plans" "$kernel/scripts"
stubdir="$td/stubs"
mkdir -p "$stubdir"
MARKER="$td/launched.marker"
STATE="$auto/STATE.md"

# omp stub: no-op executor (FORETHOUGHT_DEPTH=0 keeps the batch
# executor-only; the bridge stub below is the launch signal).
cat >"$stubdir/omp" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
chmod +x "$stubdir/omp"
chmod +x "$stubdir/omp"
# bridge stub: --run-start "overnight-<slug>" is the slot signal; the
# bridge records the run id AND the plan slug per launch.
cat >"$stubdir/bridge-stub.sh" <<'BSTUB'
#!/usr/bin/env bash
printf 'run run-42 started %s\n' "$*"
case "$*" in
 *--run-start*)
  slug="$(printf '%s' "$*" | sed -n 's/.*overnight-\([a-zA-Z0-9-]*\).*/\1/p')"
  [ -n "${MARKER:-}" ] && [ -n "$slug" ] && printf '%s\n' "$slug" >>"$MARKER"
  ;;
esac
exit 0
BSTUB
chmod +x "$stubdir/bridge-stub.sh"
printf '#!/usr/bin/env python3\nimport sys\nsys.exit(0)\n' \
 >"$kernel/scripts/report-queue"
chmod +x "$kernel/scripts/report-queue"

plan_with_step() { # file slug flagged step -> writes an accepted plan
 local front="<!-- plan: status=accepted risk=normal author=operator -->"
 local flagged="${2:-plain}" step="touch the sandbox marker"
 [ "$flagged" = "flagged" ] && \
  front="<!-- plan: status=accepted risk=normal priority=high author=operator -->"
 printf '%s\n# plan\n\n## Steps\n\n- [ ] %s -- verify: marker exists\n' \
  "$front" "$step" >"$kernel/docs/project/plans/$1.plan.md"
}

run_cycle() {
 env HNGH_HOME="$kernel" OVERNIGHT_LOCK="$td/cycle.lock" \
  OVERNIGHT_TIMEOUT="5" FAILFIRST_STATE_DIR="$td/ff" \
  FORETHOUGHT_DEPTH="0" OVERNIGHT_MAX_SESSIONS_DAY="1" \
  OVERNIGHT_MODEL="stub-model" \
  OMP_BIN_CMD="$stubdir/omp" MARKER="$MARKER" \
  OMP_BRIDGE_BIN="$stubdir/bridge-stub.sh" \
  PATH="$stubdir:/usr/bin:/bin" \
  bash "$auto/scripts/overnight-cycle.sh"
}

reset_runs() {
 : >"$auto/logs/budget.md"
 : >"$MARKER"
 rm -f "$STATE"
 rm -rf "$td/ff"
 rm -f "$kernel"/docs/project/plans/*.plan.md
}
 : >"$auto/logs/budget.md"
 : >"$MARKER"
 rm -f "$STATE"
 rm -rf "$td/ff"
 rm -f "$kernel"/docs/project/plans/*.plan.md

slot0() { # -> the plan slug launched as slot 0 (bridge stub records it)
 head -n1 "$MARKER"
}

# --- (a) priority=high sorts ahead of filename order -----------------------
reset_runs
plan_with_step a-plain plain
plan_with_step z-priority flagged
run_cycle >/dev/null 2>&1
[ "$?" -eq 0 ] || fail "priority cycle exited non-zero"
[ "$(wc -l <"$MARKER")" -eq 1 ] || fail "expected exactly one launch, got $(wc -l <"$MARKER")"
[ "$(slot0)" = "z-priority" ] ||
 fail "priority=high plan did not take slot 0 (slot0=$(slot0))"
ok "priority=high plan sorts ahead of filename order"

# --- (b) multiple priority=high plans keep filename order ------------------
reset_runs
plan_with_step a-priority flagged
plan_with_step z-priority flagged
run_cycle >/dev/null 2>&1
[ "$?" -eq 0 ] || fail "dual-priority cycle exited non-zero"
[ "$(slot0)" = "a-priority" ] ||
 fail "flagged plans did not keep filename order (slot0=$(slot0))"
ok "multiple priority=high plans keep filename order among themselves"

# --- (c) no flag preserves the current order -------------------------------
reset_runs
plan_with_step a-plain plain
plan_with_step z-plain plain
run_cycle >/dev/null 2>&1
[ "$?" -eq 0 ] || fail "plain cycle exited non-zero"
[ "$(slot0)" = "a-plain" ] ||
 fail "unflagged order changed (slot0=$(slot0))"
ok "no flag preserves the current filename order"


echo "plan-priority-selector contract: all cases passed"
echo "plan-priority-selector contract: all cases passed"
