#!/usr/bin/env bash
# test-quota-routing.sh - stall-recovery step 9: session-model-preference
# quota routing. Ladder: env > quota-row model (when configured and not
# demoted) > local-bench > paid-fallback. budget.md session-run rows tag
# source=quota vs source=cash. Hermetic: sandbox params/state, stub gates.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
trap 'rm -rf "$sb"' EXIT
mkdir -p "$sb/state" "$sb/stats"
fails=0
ck() {
  if [ "$2" = "$3" ]; then echo "ok: $1"; else
    echo "FAIL: $1 (want [$2] got [$3])"
    fails=$((fails + 1))
  fi
}
LIB_OC="$root/scripts/overnight-cycle.sh"
DEM_LIB="$root/lib/model-demote.sh"
# select_model reads OVERNIGHT_MODEL/OVERNIGHT_PAID_MODEL and
# SESSION_MODEL_QUOTA_KEY_PRESENT straight from the environment; a cadence
# unit exports OVERNIGHT_MODEL, so scrub before each case or the env
# short-circuit outranks the leg under test (hermeticity, 2026-09-10).
sed -n '/^best_bench_model() {/,/^}/p; /^select_model() {/,/^}/p' "$LIB_OC" >"$sb/select_model.snippet"

sm() { # env assignments as KEY=VAL... then eval select_model
  env -u OVERNIGHT_MODEL -u OVERNIGHT_PAID_MODEL -u SESSION_MODEL_QUOTA_KEY_PRESENT \
    "$@" DEMOTE_STATE="$sb/state/model-demote.tsv" AUTOMATION_ROOT="$sb" \
    HNGH_HOME="$root/.." ROOT="$sb" \
    bash -c ". '$root/lib/params.sh'; . '$DEM_LIB'; quota_leg_healthy() { case \"\$1\" in *dead*) return 1;; *) return 0;; esac; }; . '$sb/select_model.snippet'; select_model"
}


# 1. env short-circuit stays first
ck "env outranks quota row" "flash|env" \
  "$(sm OVERNIGHT_MODEL=flash SESSION_MODEL_PREFERENCE=kimi:k3 SESSION_MODEL_QUOTA_KEY_PRESENT=1 | tr -d ' ')"
params() { # gate-value -> write sandbox cadence-params.tsv
  printf 'session-model-quota-keys\t%s\ttest\ttest\n' "$1" >"$sb/cadence-params.tsv"
  printf 'session-model-preference\t%s\ttest\ttest\n' "$2" >>"$sb/cadence-params.tsv"
}
# 2. quota row, keys present -> quota model wins over local-bench and paid
#    (no bench data, no env) -> quota
params 1 openrouter/quota-model
ck "quota row wins when configured" "openrouter/quota-model|quota" \
  "$(sm)"
# 3. no key config -> refuse quota leg, fall to paid-fallback
params 0 openrouter/quota-model
ck "no-key quota row refused" "zai/glm-5.3|paid-fallback" \
  "$(sm)"
# 4. demoted quota model is skipped
printf 'openrouter/quota-model\t2\t1\tbad-execution\t20260910\n' >"$sb/state/model-demote.tsv"
params 1 openrouter/quota-model
ck "demoted quota model skipped" "zai/glm-5.3|paid-fallback" \
  "$(sm)"
# 5. multiple preference entries: first non-demoted wins
# (state reset: only kimi:k3 demoted - openrouter cleared by an ok)
printf 'kimi:k3\t2\t1\tbad-execution\t20260910\n' >"$sb/state/model-demote.tsv"
params 1 kimi:k3,openrouter/quota-model
ck "first non-demoted preference wins" "openrouter/quota-model|quota" \
  "$(sm)"
# 5b. unhealthy quota leg is skipped (health gate), no wasted session
params 1 kimi:dead-leg
ck "unhealthy quota leg skipped" "zai/glm-5.3|paid-fallback" \
  "$(sm)"

# 6. source tagging: launch-session writes source= field into budget row
#    (function-level: source_of MODEL PREF) -> quota|paid|bench|env
params 1 kimi:k3,openrouter/quota-model
src() { # model via
  env DEMOTE_STATE="$sb/state/model-demote.tsv" AUTOMATION_ROOT="$sb" \
    HNGH_HOME="$root/.." \
    bash -c ". '$root/lib/params.sh'; . '$DEM_LIB'; session_model_source \"\$1\" \"\$2\"" _ "$1" "$2"
}
ck "quota source tag" "quota" "$(src openrouter/quota-model yes)"
ck "paid source tag" "paid" "$(src zai/glm-5.3 no)"
ck "env source tag" "env" "$(src flash env)"
ck "bench source tag" "bench" "$(src unsloth/x local-bench)"
# --- 10. cost-tiering step 2: class-aware select_model ----------------------
# select_model [class]: T1 pins the local-bench rung (quota and paid skipped
# unless the bench is empty/demoted), T2 keeps env > quota > local-bench >
# paid, T3 leaves the ladder untouched but files the T3 operator-item (the
# director should take it). Demotion + health gates apply to every rung.
# operator_item is stubbed to a log file (lib/operator-item.sh is the real
# surface; the row is the contract).
OPITEMS="$sb/op-items.log"
smc() { # class [K=V ...] -> select_model "$1"
  local cls="$1"
  shift
  env -u OVERNIGHT_MODEL -u OVERNIGHT_PAID_MODEL -u SESSION_MODEL_QUOTA_KEY_PRESENT \
    "$@" DEMOTE_STATE="$sb/state/model-demote.tsv" AUTOMATION_ROOT="$sb" \
    HNGH_HOME="$root/.." ROOT="$sb" OPERATOR_ITEMS_LOG="$OPITEMS" \
    bash -c ". '$root/lib/params.sh'; . '$DEM_LIB'; quota_leg_healthy() { case \"\$1\" in *dead*) return 1;; *) return 0;; esac; }; operator_item() { printf '%s\t%s\n' \"\$1\" \"\$2\" >>\"\$OPERATOR_ITEMS_LOG\"; }; . '$sb/select_model.snippet'; select_model \"$cls\""
}
bench_seed() { # model -> fresh score-5 bench row (select_model's glob window)
  mkdir -p "$sb/stats"
  python3 - "$1" <<PY
import json, time
with open("$sb/stats/model-bench-t.jsonl", "w") as fh:
    fh.write(json.dumps({"model": "$1", "score": 5, "ts": time.time()}) + "\\n")
PY
}
bench_clear() { rm -f "$sb/stats"/model-bench-*.jsonl; }

# 10a. T1 pins local-bench over a healthy configured quota row
bench_clear
bench_seed unsloth/bench-model
params 1 openrouter/quota-model
: >"$OPITEMS"
ck "T1 pins local-bench over a healthy quota row" "unsloth/bench-model|local-bench" \
  "$(smc T1)"
ck "T1 files no operator-item" "0" "$(wc -l <"$OPITEMS" | tr -d ' ')"

# 10b. T1 with an empty bench falls through to the T2 ladder (quota)
bench_clear
ck "T1 empty bench falls through to quota" "openrouter/quota-model|quota" "$(smc T1)"

# 10c. T1 with a demoted bench model falls through (demotion gate per rung)
bench_seed unsloth/bench-model
printf 'unsloth/bench-model\t2\t1\tbad-execution\t20260914\n' >"$sb/state/model-demote.tsv"
ck "T1 demoted bench falls through to quota" "openrouter/quota-model|quota" "$(smc T1)"
rm -f "$sb/state/model-demote.tsv"

# 10d. T1 respects the env override (operator steering outranks the pin)
ck "T1 env override wins" "flash|env" "$(smc T1 OVERNIGHT_MODEL=flash | tr -d ' ')"

# 10e. T2 keeps the ladder: quota outranks the bench even when one exists
ck "T2 quota outranks bench" "openrouter/quota-model|quota" "$(smc T2)"
# 10f. T2 no-key quota refused -> bench (not paid)
params 0 openrouter/quota-model
ck "T2 no-key quota refused -> bench" "unsloth/bench-model|local-bench" "$(smc T2)"
# 10g. T2 demoted quota skipped -> bench (demotion gate per class)
printf 'openrouter/quota-model\t2\t1\tbad-execution\t20260914\n' >"$sb/state/model-demote.tsv"
ck "T2 demoted quota skipped -> bench" "unsloth/bench-model|local-bench" "$(smc T2)"
rm -f "$sb/state/model-demote.tsv"
bench_clear
# 10h. T2 empty bench -> paid fallback (ladder tail unchanged)
ck "T2 empty bench -> paid" "zai/glm-5.3|paid-fallback" "$(smc T2)"

# 10i. T3 keeps the T2 ladder (quota wins) AND files the operator-item
bench_seed unsloth/bench-model
params 1 openrouter/quota-model
: >"$OPITEMS"
ck "T3 keeps the T2 ladder" "openrouter/quota-model|quota" "$(smc T3)"
[ "$(wc -l <"$OPITEMS" | tr -d ' ')" -ge 1 ] &&
  echo "ok: T3 files the operator-item" || {
  echo "FAIL: T3 operator-item missing"
  fails=$((fails + 1))
}
grep -q 'director' "$OPITEMS" &&
  echo "ok: T3 operator-item names the director" || {
  echo "FAIL: T3 operator-item lacks the director note"
  fails=$((fails + 1))
}

# 10j. T1/T2 file no operator-item (only T3 does)
: >"$OPITEMS"
smc T2 >/dev/null
smc T1 >/dev/null
ck "T1/T2 file no operator-item" "0" "$(wc -l <"$OPITEMS" | tr -d ' ')"

# 10k. T1 bench-empty + unhealthy quota leg -> paid (health gate applies)
bench_clear
params 1 kimi:dead-leg
ck "T1 bench-empty + unhealthy quota -> paid" "zai/glm-5.3|paid-fallback" "$(smc T1)"

echo "---"
[ "$fails" -eq 0 ] && echo "ALL PASS" || {
  echo "$fails FAILED"
  exit 1
}
