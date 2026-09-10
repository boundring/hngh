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
sed -n '/^select_model() {/,/^}/p' "$LIB_OC" >"$sb/select_model.snippet"

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

echo "---"
[ "$fails" -eq 0 ] && echo "ALL PASS" || {
  echo "$fails FAILED"
  exit 1
}
