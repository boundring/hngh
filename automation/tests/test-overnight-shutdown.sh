#!/usr/bin/env bash
# test-overnight-shutdown.sh — crash-safety net proofs (plan 19 step 7):
#   a) SIGTERM mid-run -> shutdown-signal breadcrumb naming the in-flight
#      session, exit non-zero, and the kill lands before a new beat would
#      ever spawn
#   b) cold start right after -> reports the unclean exit (cold-start-
#      unclean breadcrumb) and does NOT double-spawn; a later clean run
#      (overnight-done ordering restored) resumes spawning
# Hermetic: sandbox tree, stub omp/bridge — nothing real is ever launched.
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
cat >"$kernel/docs/project/plans/seed.plan.md" <<'EOF'
<!-- plan: status=accepted risk=normal author=operator -->
# seed plan

## Steps

- [ ] touch the sandbox marker -- verify: marker exists
EOF
stubdir="$td/stubs"
mkdir -p "$stubdir"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$1" >> "$MARKER"\nsleep "${OMP_SLEEP:-0}"\nexit 0\n' >"$stubdir/omp"
chmod +x "$stubdir/omp"
printf '#!/usr/bin/env bash\necho "run run-42 started $*"\n' >"$stubdir/bridge-stub.sh"
chmod +x "$stubdir/bridge-stub.sh"
MARKER="$td/launched.marker"
STATE="$auto/STATE.md"

run_cycle() { # -> child runs with OMP_SLEEP from env
 env HNGH_HOME="$kernel" OVERNIGHT_LOCK="$td/cycle.lock" \
  OVERNIGHT_TIMEOUT="5" FAILFIRST_STATE_DIR="$td/ff" \
  OMP_STUB="$stubdir/omp" MARKER="$MARKER" \
  OMP_BRIDGE_BIN="$stubdir/bridge-stub.sh" \
  PATH="$stubdir:/usr/bin:/bin" OMP_SLEEP="${OMP_SLEEP:-0}" \
  bash "$auto/scripts/overnight-cycle.sh"
}

# --- (a) SIGTERM mid-run ---------------------------------------------------
# background the `env bash` command directly: `func &` would fork a
# subshell whose TERM disposition is default, never reaching the script.
OMP_SLEEP=5 env HNGH_HOME="$kernel" OVERNIGHT_LOCK="$td/cycle.lock" \
 OVERNIGHT_TIMEOUT="5" FAILFIRST_STATE_DIR="$td/ff" \
 OMP_STUB="$stubdir/omp" MARKER="$MARKER" \
 OMP_BRIDGE_BIN="$stubdir/bridge-stub.sh" \
 PATH="$stubdir:/usr/bin:/bin" \
 bash "$auto/scripts/overnight-cycle.sh" &
pid=$!
i=0
while [ ! -s "$MARKER" ] && [ "$i" -lt 100 ]; do
 sleep 0.1
 i=$((i + 1))
done
[ -s "$MARKER" ] || fail "session never launched in sandbox"
kill -TERM "$pid"
wait "$pid"
rc=$?
[ "$rc" -ne 0 ] || fail "cycle exited 0 on SIGTERM (rc=$rc)"
ok "SIGTERM exits non-zero (rc=$rc)"
grep -q 'shutdown-signal' "$STATE" || fail "no shutdown-signal breadcrumb"
grep -q 'in_flight=seed' "$STATE" || fail "breadcrumb missing in-flight session id"
ok "shutdown-signal breadcrumb records in_flight=seed"

# --- (b) cold start does not double-spawn ---------------------------------
OMP_SLEEP=0 run_cycle >/dev/null 2>&1
rc=$?
[ "$rc" -eq 0 ] || fail "cold start exited $rc"
grep -q 'cold-start-unclean' "$STATE" || fail "no cold-start-unclean breadcrumb"
[ "$(wc -l <"$MARKER")" -eq 1 ] || fail "cold start double-spawned (marker=$(wc -l <"$MARKER"))"
ok "cold start reports unclean exit and does not double-spawn"

# --- clean run after the skip resumes spawning -----------------------------
OMP_SLEEP=0 run_cycle >/dev/null 2>&1
[ "$(wc -l <"$MARKER")" -eq 2 ] || fail "clean run did not resume spawning"
ok "clean run resumes spawning"

echo "overnight-shutdown contract: all cases passed"
