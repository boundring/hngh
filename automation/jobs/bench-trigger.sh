#!/usr/bin/env bash
# bench-trigger — event-driven benchmark triggers (plan
# docs/project/plans/2026-09-10-bench-trigger-lane.plan.md; design
# docs/design/bench-triggering.md: occasional, event-driven, never nightly).
# Verbs (one per invocation):
#   new-model-check    diff BENCH_MODELS + UNSLOTH_FALLBACK_MODELS against the
#                      models present in stats/model-bench-*.jsonl; an unbenched
#                      name fires jobs/model-bench.sh scoped to it
#                      (BENCH_MODELS=<name>) and files an operator-item with
#                      the ranking delta (score vs the newest digest top).
#   recalibrate-check  when the newest digest/BENCH-*.md is older than the
#                      benchmark-recalibrate-days row (default 30): re-bench
#                      the current top model plus every demoted-not-cleared
#                      model (state/model-demote.tsv) in ONE scoped run, then
#                      feed each score through record_model_outcome (ok clears
#                      the demotion, bad-execution reinforces it).
# Quiet guard (both verbs): defer (breadcrumb, no bench) while development is
# at full speed AND a session-run landed in logs/budget.md within the last 30
# minutes — the bench loads the host, sessions come first.
# Test seams: BENCH_SCRIPT, BENCH_STATS_DIR, BUDGET_LOG, DEMOTE_STATE,
# FAILFIRST_STATE_DIR, BENCH_QUIET_WINDOW_S, DIGEST_DIR/HNGH_HOME_DIR,
# REPORT/HNGH_HOME, HNGH_CRUMBS_DB (journal db; STATE.md is a derived
# export, never a seam).
set -u
. "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"
. "$AUTOMATION_ROOT/lib/params.sh"
. "$AUTOMATION_ROOT/lib/notify-email.sh"
. "$AUTOMATION_ROOT/lib/operator-item.sh"
. "$AUTOMATION_ROOT/lib/model-demote.sh"

BENCH_SCRIPT="${BENCH_SCRIPT:-$AUTOMATION_ROOT/jobs/model-bench.sh}"
STATS_DIR="${BENCH_STATS_DIR:-$AUTOMATION_ROOT/stats}"
BUDGET_LOG="${BUDGET_LOG:-$AUTOMATION_ROOT/logs/budget.md}"
DEMOTE_STATE="${DEMOTE_STATE:-$AUTOMATION_ROOT/state/model-demote.tsv}"
FF_STATE="${FAILFIRST_STATE_DIR:-$AUTOMATION_ROOT/state/failfirst}/failfirst-development"
QUIET_WINDOW="${BENCH_QUIET_WINDOW_S:-1800}"

quiet_busy() { # -> 0 when the bench must defer (host busy)
  # "speed is active" = development at full speed (FF_SPEED=1, the engine's
  # own default when the state file is absent) AND a session ran recently.
  local speed=1 k v ts now last
  if [ -r "$FF_STATE" ]; then
    while IFS='=' read -r k v; do
      [ "$k" = "speed" ] && case "$v" in 1 | 2 | 3) speed="$v" ;; esac
    done <"$FF_STATE"
  fi
  [ "$speed" = "1" ] || return 1
  last="$(grep ' | session-run' "$BUDGET_LOG" 2>/dev/null | tail -n1 | cut -d' ' -f1)"
  [ -n "$last" ] || return 1
  ts="$(date -u -d "$last" +%s 2>/dev/null)" || return 1
  now="$(date +%s)"
  [ "$((now - ts))" -lt "$QUIET_WINDOW" ]
}

benched_models() { # -> one model per line, from stats/model-bench-*.jsonl
  python3 - "$STATS_DIR" <<'PY'
import glob, json, os, sys
seen = set()
for p in glob.glob(os.path.join(sys.argv[1], "model-bench-*.jsonl")):
    for ln in open(p, errors="replace"):
        try:
            m = json.loads(ln).get("model", "")
        except ValueError:
            continue
        if m:
            seen.add(m)
print("\n".join(sorted(seen)))
PY
}

digest_top() { # -> "model score" (Best line of newest BENCH-*.md; "" when none)
  local d top sc
  d="$(ls -t "$DIGEST_DIR"/BENCH-*.md 2>/dev/null | head -n1)"
  [ -n "$d" ] || return 0
  top="$(sed -n 's/^Best: \(.*\)\. Suggested chain: .*/\1/p' "$d" | head -n1)"
  [ -n "$top" ] || return 0
  sc="$(grep -F "| $top |" "$d" | head -n1 |
    awk -F'|' '{gsub(/ /, "", $2); print $2}' | cut -d/ -f1)"
  printf '%s %s\n' "$top" "${sc:-?}"
}

latest_score() { # model -> newest score for it across the jsonl history ("?" none)
  python3 - "$STATS_DIR" "$1" <<'PY'
import glob, json, os, sys
score = "?"
for p in sorted(glob.glob(os.path.join(sys.argv[1], "model-bench-*.jsonl"))):
    for ln in open(p, errors="replace"):
        try:
            r = json.loads(ln)
        except ValueError:
            continue
        if r.get("model") == sys.argv[2] and isinstance(r.get("score"), int):
            score = r["score"]
print(score)
PY
}

fire_bench() { # models... — one scoped run through the test seam
  BENCH_MODELS="$*" bash "$BENCH_SCRIPT" || true
}

new_model_check() {
  local benched unbenched="" m top tsc name sc
  benched="$(benched_models)"
  for m in $BENCH_MODELS $UNSLOTH_FALLBACK_MODELS; do
    case " $unbenched " in *" $m "*) continue ;; esac
    printf '%s\n' "$benched" | grep -qxF "$m" || unbenched="$unbenched $m"
  done
  unbenched="${unbenched# }"
  if [ -z "$unbenched" ]; then
    breadcrumb "$JOB_NAME" "bench-new-model" "no-op: config fleet fully benched"
    return 0
  fi
  if quiet_busy; then
    breadcrumb "$JOB_NAME" "bench-defer" \
      "quiet guard: development active + session within ${QUIET_WINDOW}s — new-model deferred ($unbenched)"
    return 0
  fi
  top="$(digest_top)" # pre-bench top: the scoped run rewrites today's digest
  tsc="${top#* }"
  top="${top%% *}"
  for name in $unbenched; do
    breadcrumb "$JOB_NAME" "bench-new-model" "unbenched model: firing scoped bench $name"
    fire_bench "$name"
    sc="$(latest_score "$name")"
    operator_item "bench-new-model:$name" \
      "bench new-model trigger fired: $name scored ${sc}/5 vs top $top ${tsc:-?}/5 (newest BENCH digest) — ranking delta for the operator"
  done
}

recalibrate_check() {
  local days newest age top tsc demoted="" row targets m sc out alive=0
  days="$(get_param benchmark-recalibrate-days 30)"
  case "$days" in '' | *[!0-9]* | 0) days=30 ;; esac
  newest="$(ls -t "$DIGEST_DIR"/BENCH-*.md 2>/dev/null | head -n1)"
  if [ -z "$newest" ]; then
    breadcrumb "$JOB_NAME" "bench-recalibrate" "no digest yet — nothing to recalibrate against"
    return 0
  fi
  age=$(($(date +%s) - $(stat -c %Y "$newest" 2>/dev/null || echo 0)))
  if [ "$age" -lt "$((days * 86400))" ]; then
    breadcrumb "$JOB_NAME" "bench-recalibrate" \
      "fresh: $(basename "$newest") ${age}s old < ${days}d — no recalibration pending"
    return 0
  fi
  top="$(digest_top)"
  tsc="${top#* }"
  top="${top%% *}"
  if [ -z "$top" ]; then
    breadcrumb "$JOB_NAME" "bench-recalibrate" "stale digest has no Best line — deferring"
    return 0
  fi
  if [ -r "$DEMOTE_STATE" ]; then
    while IFS=$'\t' read -r row _cnt dflag _rest; do
      [ "$dflag" = "1" ] && demoted="$demoted $row"
    done <"$DEMOTE_STATE"
  fi
  demoted="${demoted# }"
  if quiet_busy; then
    breadcrumb "$JOB_NAME" "bench-defer" \
      "quiet guard: development active + session within ${QUIET_WINDOW}s — recalibrate deferred"
    return 0
  fi
  targets="$top"
  case " $demoted " in *" $top "*) : ;; *) targets="$top $demoted" ;; esac
  breadcrumb "$JOB_NAME" "bench-recalibrate" \
    "digest ${age}s old >= ${days}d: re-benching targets [$targets] (top=$top, demoted-not-cleared=[${demoted:-none}])"
  fire_bench $targets
  for m in $targets; do
    sc="$(latest_score "$m")"
    case "$sc" in *[!0-9]* | '') : ;; *) [ "$sc" -gt 0 ] && alive=1 ;; esac
  done
  for m in $targets; do       # ponytail: whole-run-zero reads as a down local
    sc="$(latest_score "$m")" # server, not model evidence — record unknown
    case "$sc" in
    '' | *[!0-9]*) out=unknown ;;
    0) [ "$alive" = 0 ] && out=unknown || out=bad-execution ;;
    *) out=ok ;;
    esac
    record_model_outcome "$m" "$out"
    breadcrumb "$JOB_NAME" "bench-recalibrate" "$m scored ${sc}/5 -> record_model_outcome $out"
  done
}

case "${1:-}" in
new-model-check) new_model_check ;;
recalibrate-check) recalibrate_check ;;
*)
  printf 'usage: jobs/bench-trigger.sh new-model-check|recalibrate-check\n' >&2
  breadcrumb "$JOB_NAME" "bench-trigger" "unknown verb '${1:-}' — no bench"
  ;;
esac
exit 0
