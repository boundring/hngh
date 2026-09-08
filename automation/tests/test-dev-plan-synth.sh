#!/usr/bin/env bash
# test-dev-plan-synth.sh -- contract proofs for the grow side of the demand
# synthesizer (scripts/overnight-cycle.sh synthesize_dev_plan), 2026-09-08:
#   1. accepted-plans queue dry + recent verdict=adopted research -> a
#      development plan is synthesized from the adopted findings (local
#      chain, pinned) and lands in the kernel plans feed as status=proposed;
#      accept-plans admission then accepts it (runnable Verification lines,
#      gates green stubbed true).
#   2. the daily bound holds: a second beat the same day synthesizes nothing.
#   3. malformed model output (no verifiable steps) is discarded, never fed
#      to admission.
# Hermetic: sandbox repo copies, stub model endpoint, stub gates — no real
# model chain, no real sessions, no spend, no writes outside the sandbox.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
stubdir="$(mktemp -d)"
stub_pids=""
trap 'rm -rf "$sb" "$stubdir"; [ -z "$stub_pids" ] || kill $stub_pids 2>/dev/null' EXIT

ok() { echo "ok: $1"; }
need() { "$@" || {
  echo "FAIL: $*"
  exit 1
}; } # every case fatal

mkdir -p "$sb/lib" "$sb/scripts" "$sb/digest" "$sb/logs" \
  "$sb/kernel/docs/project/plans" "$sb/kernel/docs/research" "$sb/kernel/scripts"
cp -r "$root/lib/." "$sb/lib/"
cp "$root/scripts/overnight-cycle.sh" "$root/scripts/accept-plans.py" "$sb/scripts/"
printf 'stub\n' >"$sb/kernel/scripts/report-queue" # alert rows fail closed
chmod +x "$sb/kernel/scripts/report-queue"

PLAN_BODY='Rationale: the adopted ctx-compaction-strategies line is actionable now.

## Steps

- [ ] add lib/ctx-pack.sh with a size-capped pack builder
  Verification: bash -n lib/ctx-pack.sh
- [ ] wire the pack into the overnight brief
  Verification: make test
- [ ] record pack sizes in the session ledger
  Verification: grep -q ctx-pack lib/launch-session.sh'

# adopted research line dated today with a real evidence doc in the sandbox
today="$(date -u +%F)"
doc="$sb/kernel/docs/research/2026-09-08-ctx-compaction.md"
printf 'findings: pack, do not re-derive; cap every packet\n' >"$doc"
printf 'line\taction\tverdict\treviewer\tevidence\tdate\n' >"$sb/research-dispositions.tsv"
printf 'ctx-compaction-strategies\tadopted\tadopted -- actionable now\tmodel:stub\t%s\t%s\n' \
  "$doc" "$today" >>"$sb/research-dispositions.tsv"

# draft-plan marker present: the legacy authoring leg stays out of the way
printf 'seed draft\n' >"$sb/digest/DRAFT-PLAN-$today.md"

. "$root/tests/stub-lib.sh"
printf 'stub-token-never-real' >"$sb/unsloth-token"
: >"$sb/STATE.md"

run_cycle() { # [extra K=V...] -> runs one overnight beat in the sandbox
  env "$@" \
    HNGH_HOME="$sb/kernel" \
    HOME="$sb" \
    STATE_FILE="$sb/STATE.md" \
    JOB_NAME=test \
    OVERNIGHT_LOCK="$sb/cycle.lock" \
    OVERNIGHT_TIMEOUT="5" \
    FAILFIRST_STATE_DIR="$sb/ff" \
    TOKEN_FILE="$sb/unsloth-token" REFRESH_FILE="$sb/nope" \
    REMOTE_TOKEN_FILE="$sb/nope3" REMOTE_URL="http://127.0.0.1:1" \
    OLLAMA_URL="http://127.0.0.1:1" OLLAMA_MODEL=stub-ollama \
    MODEL=stub-model UNSLOTH_FALLBACK_MODELS="" MODEL_TIMEOUT=5 \
    KIMI_KEY_FILE="$sb/.config/hngh/kimi-key" \
    LOBEHUB_KEY_FILE="$sb/.config/hngh/lobehub-key" \
    bash "$sb/scripts/overnight-cycle.sh" >/dev/null 2>&1
  return 0
}

synth_plans() { # -> count of synthesized plan files in the kernel feed
  ls "$sb/kernel/docs/project/plans/"*-dev-*.plan.md 2>/dev/null | wc -l | tr -d ' '
}

crumb() { # event -> 0 when the breadcrumb exists in the sandbox STATE.md
  grep -q " | $1 | " "$sb/STATE.md" 2>/dev/null
}

# --- 1. queue dry + adopted research -> proposed plan, admitted -----------
STUB_CONTENT="$PLAN_BODY" stub_start stubU
run_cycle UNSLOTH_URL="http://127.0.0.1:$(cat "$stubdir/stubU-port")"
need test "$(synth_plans)" = "1"
plan_file="$(ls "$sb/kernel/docs/project/plans/"*-dev-*.plan.md)"
grep -q 'status=proposed' "$plan_file"
need grep -q '^- \[ \]' "$plan_file"
need grep -q "$doc" "$stubdir/stubU-bodies" # the adopted evidence doc was read
ok "queue dry + adopted research: synthesized plan proposed to the kernel feed"

# admission: runnable Verification + both gates green -> accepted
out="$(ACCEPT_KERNEL_GATE="true" ACCEPT_AUTOMATION_GATE="true" \
  HNGH_HOME="$sb/kernel" HNGH_AUTOMATION_ROOT="$sb" ACCEPT_LOG="$sb/accept.log" \
  python3 "$sb/scripts/accept-plans.py" 2>/dev/null)"
need grep -q '^accepted ' <<<"$out"
grep -q 'status=accepted' "$plan_file"
ok "synthesized plan passes accept-plans admission (status flipped to accepted)"

# --- 2. the daily bound: a second beat synthesizes nothing ----------------
rm -f "$sb/kernel/docs/project/plans/"*-dev-*.plan.md # re-dry the queue
before="$(synth_plans)"
run_cycle UNSLOTH_URL="http://127.0.0.1:$(cat "$stubdir/stubU-port")"
need test "$(synth_plans)" = "$before"
need crumb dev-synth-skip
ok "daily synthesis bound holds on the second beat"

# --- 3. malformed model output is discarded, never admitted ---------------
rm -f "$sb/kernel/docs/project/plans/"*-dev-*.plan.md "$sb/digest/"SYNTH-PLAN-*
mv "$sb/STATE.md" "$sb/STATE.md.1"
kill $stub_pids 2>/dev/null
wait $stub_pids 2>/dev/null
stub_pids=""
STUB_CONTENT="no steps here at all" stub_start stubU2
run_cycle UNSLOTH_URL="http://127.0.0.1:$(cat "$stubdir/stubU2-port")"
need test "$(synth_plans)" = "0"
need crumb dev-synth-fail
ok "malformed synthesis discarded (no plan, alert trail)"

echo "dev plan synthesis contract: all cases passed"
