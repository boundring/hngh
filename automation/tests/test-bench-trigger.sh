#!/usr/bin/env bash
# test-bench-trigger.sh — event-driven bench trigger contract (plan
# 2026-09-10 bench-trigger lane). Hermetic: sandbox stats/digest/demote/
# failfirst/budget state, stub bench + stub report-queue, no real model
# loads. Covers: unbenched-name fires a scoped bench (BENCH_MODELS is ONE
# model), no-op when the diff is empty, quiet-guard defers (speed active +
# recent session), recalibrate fires on a stale digest only (top +
# demoted-not-cleared), outcomes feed record_model_outcome.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
trap 'cp -r "$sb" /tmp/opencode/tbtdump; rm -rf "$sb"' EXIT
mkdir -p "$sb/stats" "$sb/state/failfirst" "$sb/logs" "$sb/archive/digest" \
  "$sb/scripts"
: >"$sb/queue.log"
: >"$sb/bench-calls"
fails=0
ck() {
  if [ "$2" = "$3" ]; then echo "ok: $1"; else
    echo "FAIL: $1 (want [$2] got [$3])"
    fails=$((fails + 1))
  fi
}

# stub bench: records the scoped BENCH_MODELS line and appends one scored
# row per model (STUB_SCORES="model=score ...", else STUB_SCORE, else 2)
cat >"$sb/stub-bench.sh" <<EOF
#!/usr/bin/env bash
printf 'BENCH_MODELS=%s\n' "\$BENCH_MODELS" >>"$sb/bench-calls"
python3 - "\$BENCH_MODELS" <<'PY' >>"$sb/stats/model-bench-$(date +%F).jsonl"
import json, os, sys
scores = dict(kv.split("=", 1) for kv in os.environ.get("STUB_SCORES", "").split() if "=" in kv)
default = os.environ.get("STUB_SCORE", "2")
for m in sys.argv[1].split():
    print(json.dumps({"model": m, "score": int(scores.get(m, default))}))
PY
EOF
chmod +x "$sb/stub-bench.sh"

# stub report-queue (alert_row runs `python3 $KERNEL/scripts/report-queue`,
# record_model_outcome runs `python3 $HNGH_HOME/scripts/report-queue`)
printf '#!/usr/bin/env python3\nimport sys\nopen("%s/queue.log", "a").write(" ".join(sys.argv[1:]) + "\\n")\n' \
  "$sb" >"$sb/scripts/report-queue"

# fixture bench history: m/alpha 4/5 (top), m/beta 3/5
printf '{"model": "m/alpha", "score": 4}\n{"model": "m/beta", "score": 3}\n' \
  >"$sb/stats/model-bench-2026-08-01.jsonl"
cat >"$sb/archive/digest/BENCH-2026-08-01.md" <<'EOF'
# Fleet bench 2026-08-01

| score | model | json | div0 | reader | fmt | fix |
|---|---|---|---|---|---|---|
| 4/5 | m/alpha | 1 | 1 | 1 | 1 | 0 |
| 3/5 | m/beta | 1 | 1 | 0 | 1 | 0 |

Best: m/alpha. Suggested chain: ranked order above with outright failures dropped.
EOF
# the 0801 fixture must never outdate the per-case stale-touch target:
touch -d "50 days ago" "$sb/archive/digest/BENCH-2026-08-01.md"
printf 'm/demoted\t2\t1\n' >"$sb/state/model-demote.tsv"
printf '2020-01-01T00:00:00Z | overnight|old | session-run\n' >"$sb/logs/budget.md"

ff_speed() { printf 'speed=%s\n' "$1" >"$sb/state/failfirst/failfirst-development"; }
ff_clear() { rm -f "$sb/state/failfirst/failfirst-development"; }
budget_now() {
  printf '%s | overnight|fresh | session-run\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    >>"$sb/logs/budget.md"
}
calls() { wc -l <"$sb/bench-calls"; }

run_verb() { # verb — env seams point everything at the sandbox
  STATE_FILE="$sb/STATE.md" HNGH_HOME="$sb" KERNEL="$sb" \
    BENCH_SCRIPT="$sb/stub-bench.sh" BENCH_STATS_DIR="$sb/stats" \
    BUDGET_LOG="$sb/logs/budget.md" DEMOTE_STATE="$sb/state/model-demote.tsv" \
    FAILFIRST_STATE_DIR="$sb/state/failfirst" DIGEST_DIR="$sb/archive/digest" \
    BENCH_MODELS="${BM:-}" UNSLOTH_FALLBACK_MODELS="${FM:-}" \
    bash "$root/jobs/bench-trigger.sh" "$1"
}

# 1. params row parses (get_param, real inventory)
ck "recalibrate days row" "30" \
  "$(AUTOMATION_ROOT="$root" bash -c ". '$root/lib/params.sh'; get_param benchmark-recalibrate-days 0")"

# 2. week drop-in mounts both verbs
ck "drop-in runs new-model-check" "1" \
  "$(grep -c 'bench-trigger.sh" new-model-check' "$root/cadence/week/02-bench-trigger.sh")"
ck "drop-in runs recalibrate-check" "1" \
  "$(grep -c 'bench-trigger.sh" recalibrate-check' "$root/cadence/week/02-bench-trigger.sh")"

# 3. unbenched name fires ONE scoped bench + operator-item with the delta
BM="m/alpha m/new" FM="m/beta" run_verb new-model-check
ck "scoped bench fired" "BENCH_MODELS=m/new" "$(tail -n1 "$sb/bench-calls")"
ck "one bench call so far" "1" "$(calls)"
ck "operator-item has delta" "1" \
  "$(grep -c 'm/new scored 2/5 vs top m/alpha 4/5' "$sb/queue.log")"
ck "breadcrumb fired" "1" \
  "$(grep -c '| bench-new-model | unbenched model: firing scoped bench m/new' "$sb/STATE.md")"

# 4. no-op when the config fleet is fully benched
BM="m/alpha m/beta" FM="m/beta" run_verb new-model-check
ck "no-op fires nothing" "1" "$(calls)"
ck "no-op breadcrumb" "1" "$(grep -c 'no-op: config fleet fully benched' "$sb/STATE.md")"

# 5. quiet guard: defer when development is at full speed AND a session
# ran within the window; fire when either condition is false
BM="m/new2" FM="" budget_now
run_verb new-model-check
ck "quiet guard defers" "1" "$(calls)"
ck "defer breadcrumb" "1" "$(grep -c '| bench-defer | quiet guard' "$sb/STATE.md")"
ff_speed 2
BM="m/new3" FM="m/beta" run_verb new-model-check
ck "throttled speed: no defer" "BENCH_MODELS=m/new3" "$(tail -n1 "$sb/bench-calls")"
ff_speed 1
: >"$sb/logs/budget.md"
printf '2020-01-01T00:00:00Z | overnight|old | session-run\n' >>"$sb/logs/budget.md"
BM="m/new4" FM="m/beta" run_verb new-model-check
ck "stale session: no defer" "BENCH_MODELS=m/new4" "$(tail -n1 "$sb/bench-calls")"

# 6. recalibrate: stale digest fires ONE run with top + demoted; ok clears
touch -d "40 days ago" "$sb/archive/digest/BENCH-2026-08-01.md"
BM="m/alpha" run_verb recalibrate-check
ck "recalibrate scoped run" "BENCH_MODELS=m/alpha m/demoted" "$(tail -n1 "$sb/bench-calls")"
ck "ok clears demotion" "m/demoted	0	0" "$(tail -n1 "$sb/state/model-demote.tsv")"
ck "clear alert filed" "1" \
  "$(grep -c 'model-demotion-cleared:m/demoted' "$sb/queue.log")"

# 7. fresh digest: recalibrate is a no-op
touch "$sb/archive/digest/BENCH-2026-08-01.md"
BM="m/alpha" run_verb recalibrate-check
ck "fresh digest fires nothing" "4" "$(calls)"

# 8. stale digest + every probe zero: server-down smell -> unknown, demotion
# neither reinforced nor cleared
touch -d "40 days ago" "$sb/archive/digest/BENCH-2026-08-01.md"
printf 'm/demoted\t2\t1\n' >"$sb/state/model-demote.tsv"
STUB_SCORE=0 BM="m/alpha" run_verb recalibrate-check
ck "all-zero records unknown" "1" \
  "$(grep -c 'm/alpha scored 0/5 -> record_model_outcome unknown' "$sb/STATE.md")"
ck "unknown leaves demotion" "m/demoted	2	1" "$(tail -n1 "$sb/state/model-demote.tsv")"

# 9. stale digest + top alive, demoted zero: bad-execution reinforces
touch -d "40 days ago" "$sb/archive/digest/BENCH-2026-08-01.md"
printf 'm/demoted\t2\t1\n' >"$sb/state/model-demote.tsv"
STUB_SCORES="m/alpha=4 m/demoted=0" BM="m/alpha" run_verb recalibrate-check
ck "zero with living top reinforces" "m/demoted	3	1" "$(tail -n1 "$sb/state/model-demote.tsv")"

# 10. retired day catch-up: breadcrumb note only, never a bench
if grep -q "jobs/model-bench.sh" "$root/cadence/day/10-bench-fresh.sh"; then
  ck "day drop-in retired" "0" "invocation found"
else
  ck "day drop-in retired" "0" "0"
fi
STATE_FILE="$sb/STATE.md" bash "$root/cadence/day/10-bench-fresh.sh"
ck "day drop-in note only" "1" \
  "$(grep -c 'staleness note only (nightly catch-up retired)' "$sb/STATE.md")"

echo "---"
[ "$fails" -eq 0 ] && echo "ALL PASS" || {
  echo "$fails FAILED"
  exit 1
}
