#!/usr/bin/env bash
# test-session-class.sh — session-class plumbing (cost-tiering plan
# 2026-09-10-cost-tiering step 1), hermetic (sandbox tree, stub omp/bridge
# — nothing real is ever launched):
#   a) the step_class helper: tagged T1 / tagged T2 / tag on a wrapped
#      continuation line / untagged / malformed fixture plans return the
#      right class (untagged and malformed fail closed to T2)
#   b) the budget session-run row carries the class field: class=T1 for a
#      T1-tagged step, class=T2 for an untagged step (stub bridge pattern
#      from test-plan-priority-selector.sh)
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
 beat-blockers.sh memory-gate.sh; do
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
# bridge stub: --run-start "overnight-<slug>" is the slot signal.
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

PLANFILE="$kernel/docs/project/plans/seed.plan.md"
plan_with_step() { # step-first-line -> writes an accepted plan
 printf '<!-- plan: status=accepted risk=normal author=operator -->\n# plan\n\n## Steps\n\n- [ ] %s -- verify: marker exists\n' \
  "$1" >"$PLANFILE"
}

# --- (a) step_class helper --------------------------------------------------
eval "$(sed -n '/^step_class()/,/^}/p' "$root/scripts/overnight-cycle.sh")"
[ "$(type -t step_class)" = "function" ] ||
 fail "step_class not defined in overnight-cycle.sh"

plan_with_step 'deck facts tagging class=T1; wire the row'
[ "$(step_class "$PLANFILE")" = "T1" ] ||
 fail "class=T1-tagged step did not return T1"
ok "step_class returns T1 for a class=T1-tagged step"

plan_with_step 'digest wiring class=T2; keep the ladder'
[ "$(step_class "$PLANFILE")" = "T2" ] ||
 fail "class=T2-tagged step did not return T2"
ok "step_class returns T2 for a class=T2-tagged step"

# tag on a wrapped continuation line (plan step text blocks wrap)
printf '<!-- plan: status=accepted risk=normal author=operator -->\n# plan\n\n## Steps\n\n- [ ] step spanning\n      wrapped lines class=T1\n      more text\n' \
 >"$PLANFILE"
[ "$(step_class "$PLANFILE")" = "T1" ] ||
 fail "tag on a wrapped continuation line was not found"
ok "step_class finds the tag on a wrapped continuation line"

plan_with_step 'untagged step: plumb the row'
[ "$(step_class "$PLANFILE")" = "T2" ] ||
 fail "untagged step did not default to T2"
ok "step_class defaults to T2 for an untagged step"

plan_with_step 'malformed tag class=T9 must fail closed'
[ "$(step_class "$PLANFILE")" = "T2" ] ||
 fail "malformed class tag did not default to T2"
ok "step_class fails closed to T2 on a malformed class tag"

[ "$(step_class "$td/absent.plan.md")" = "T2" ] ||
 fail "absent plan file did not default to T2"
ok "step_class defaults to T2 for an absent plan file"

# --- (b) budget row carries the class field ---------------------------------
run_cycle() {
 env HNGH_HOME="$kernel" OVERNIGHT_LOCK="$td/cycle.lock" \
  OVERNIGHT_TIMEOUT="5" FAILFIRST_STATE_DIR="$td/ff" \
  FORETHOUGHT_DEPTH="0" OVERNIGHT_MAX_SESSIONS_DAY="1" \
  OVERNIGHT_MODEL="stub-model" HNGH_RAM_FLOOR_MB="1" \
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
reset_runs
plan_with_step 'deck facts tagging class=T1; wire the row'
run_cycle >/dev/null 2>&1
[ "$?" -eq 0 ] || fail "T1 cycle exited non-zero"
grep -q 'session-run | class=T1' "$auto/logs/budget.md" ||
 fail "budget row missing class=T1 (rows: $(cat "$auto/logs/budget.md" 2>/dev/null | tr '\n' ';'))"
ok "budget session-run row carries class=T1 for a T1-tagged step"

reset_runs
plan_with_step 'untagged step: plumb the row'
run_cycle >/dev/null 2>&1
[ "$?" -eq 0 ] || fail "untagged cycle exited non-zero"
grep -q 'session-run | class=T2' "$auto/logs/budget.md" ||
 fail "budget row missing class=T2 (rows: $(cat "$auto/logs/budget.md" 2>/dev/null | tr '\n' ';'))"
ok "budget session-run row carries class=T2 for an untagged step"

echo "session-class contract: all cases passed"
