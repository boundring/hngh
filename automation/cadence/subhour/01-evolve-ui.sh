#!/usr/bin/env bash
# 01-evolve-ui — one bounded evolution batch for the dashboard surface.
# Cadence drop-in (cadence/subhour): runs scripts/evolve-dashboard-style in the
# hngh kernel for a SINGLE bounded generation batch (hard cap 3 generations,
# deterministic seed), so each 10-minute tick advances the surface evolution
# loop by at most three graded candidates. Fail-closed: exits 0.
#
# Grading: defaults to the loop's deterministic --self-grade mode (no vision
# capture needed when no VL model is on the local server). When a capturing
# VL environment is present, export EVOLVE_UI_GRADE=1 to use the live
# grade-interface path instead.
set -u
# self-gate (31-heartbeat stamp pattern): one real run per 600s - the
# former 10m beat, paced by stamp since the 2026-09-24 tier collapse.
STAMP="/tmp/.hngh-cadence-01-evolve-ui-last"; now="$(date +%s)"
last="$(cat "$STAMP" 2>/dev/null || printf '0')"; last="${last//[!0-9]/}"; last="${last:-0}"
[ $((now - last)) -ge 600 ] || exit 0
printf '%s\n' "$now" >"$STAMP"

. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

KERNEL="${HNGH_HOME:-$(cd "$(dirname "$0")/../../.." && pwd)}"
EVOLVE="$KERNEL/scripts/evolve-dashboard-style"
GENS="${EVOLVE_UI_GENS:-3}" # hard cap: one batch, at most 3 gens
PRESET="${EVOLVE_UI_PRESET:-hngh}"
FLAKE="${EVOLVE_UI_FLAKE:-1}" # rotating seed -> varied candidates/tick

if [ ! -x "$EVOLVE" ]; then
 breadcrumb "$JOB_NAME" "evolve-ui-skip" "evolve-dashboard-style missing in $KERNEL"
 exit 0
fi

seed=$((FLAKE + ($(date -u +%s) / 600)))
extra=""
if [ "${EVOLVE_UI_GRADE:-0}" = "1" ]; then
 extra="--grade"
fi

out="$(cd "$KERNEL" && python3 "$EVOLVE" --preset "$PRESET" --gens "$GENS" \
 --seed "$seed" $extra 2>&1)"
rc=$?

if [ "$rc" = "0" ]; then
 breadcrumb "$JOB_NAME" "evolve-ui" "batch done ($PRESET gens=$GENS seed=$seed)"
else
 breadcrumb "$JOB_NAME" "evolve-ui-fail" "batch rc=$rc ($PRESET gens=$GENS seed=$seed)"
fi
exit 0
