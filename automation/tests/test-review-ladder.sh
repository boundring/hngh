#!/usr/bin/env bash
# test-review-ladder.sh — stall-recovery step 10: the review/digest model
# leg rides MODEL_PIN=review (deck -> kimi -> zai -> ocgo, local bench
# LAST) and an unparseable review demotes the serving model
# (record_model_outcome bad-execution). Hermetic: stub HTTP legs, sandbox
# git repos, no real quota endpoints, no real telemetry db.
set -u
# fixture containment: never inherit repo selection from the caller's shell (2026-09-17 kernel-contamination lesson)
unset GIT_DIR GIT_WORK_TREE
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
stubdir="$(mktemp -d)"
stub_pids=""
trap 'rm -rf "$sb" "$stubdir"; [ -z "$stub_pids" ] || kill $stub_pids 2>/dev/null' EXIT
mkdir -p "$sb/lib" "$sb/archive" "$sb/kernel/scripts" "$sb/jobs" "$sb/state" "$sb/digest"
for f in common.sh breadcrumbs.sh params.sh model.sh model-demote.sh scrub.sh scrub.py; do
  ln -s "$root/lib/$f" "$sb/lib/"
done
# the beat script recomputes AUTOMATION_ROOT from $0 (04-review-prep.sh
# sources "$(dirname "$0")/../.."/lib/common.sh), so it must run through a
# sandbox-tree path or it leaks the real repo's config.env and params.
mkdir -p "$sb/cadence/calendar/daily"
ln -s "$root/cadence/calendar/daily/04-review-prep.sh" "$sb/cadence/calendar/daily/"
: >"$sb/cadence-params.tsv" # no rows unless a case arms one
: >"$sb/STATE.md"
# stubs the model_call emit path and the review beat call into
printf '%s\n' \
  'import os, sys' \
  'log = os.path.join(os.environ.get("AUTOMATION_ROOT", "."), "telemetry.log")' \
  'open(log, "a").write(" ".join(sys.argv[1:]) + "\n")' >"$sb/jobs/telemetry.py"
printf '%s\n' \
  'import os, sys' \
  'root = os.environ.get("HNGH_REPORT_ROOT", ".")' \
  'open(os.path.join(root, "queue.log"), "a").write("\t".join(sys.argv[1:]) + "\n")' \
  >"$sb/kernel/scripts/report-queue"
chmod +x "$sb/kernel/scripts/report-queue"

. "$root/tests/stub-lib.sh"

fails=0
ck() { # desc expected actual
  if [ "$2" = "$3" ]; then echo "ok: $1"; else
    echo "FAIL: $1 (want [$2] got [$3])"
    fails=$((fails + 1))
  fi
}
used() { cat "$sb/tmp-modelused.txt" 2>/dev/null || true; }
set_row() { printf '%s\t%s\ttest\ttest\n' "$1" "$2" >"$sb/cadence-params.tsv"; }
call() { # prompt -> stdout (MODEL_PIN=review; every leg dead unless armed)
  (
    export AUTOMATION_ROOT="$sb" STATE_FILE="$sb/STATE.md" JOB_NAME=test
    # honor caller-armed token files (the unsloth last-resort case arms them)
    export HOME="$sb" TOKEN_FILE="${TOKEN_FILE:-$sb/nope}" \
      REFRESH_FILE="${REFRESH_FILE:-$sb/nope2}"
    export REMOTE_TOKEN_FILE="$sb/nope3" REMOTE_URL=http://127.0.0.1:1
    export UNSLOTH_URL="${UNSLOTH_URL:-http://127.0.0.1:1}" \
      OLLAMA_URL=http://127.0.0.1:1
    export OLLAMA_MODEL=stub-ollama
    export MODEL=stub-model UNSLOTH_FALLBACK_MODELS="" MODEL_TIMEOUT=5
    export HNGH_LOADCTX_PIN=0 # no /load POST: pre-pin contracts only (2026-09-22 context lane)
    export MODEL_MAX_TOKENS=3072 MODEL_PIN=review
    export HNGH_TELEMETRY_DB="$sb/telemetry.db"
    printf '%s' "$1" | bash -c '. "'"$root"'/lib/model.sh"; model_call'
  )
}

# --- ladder order: all four quota legs armed live -> deck answers -------
STUB_CONTENT=deck-says-hi stub_start deck
STUB_CONTENT=kimi-says-hi stub_start kimi
STUB_CONTENT=zai-says-hi stub_start zai
STUB_CONTENT=ocgo-says-hi stub_start ocgo
set_row deck-model-endpoint "http://127.0.0.1:$(cat "$stubdir/deck-port")"
export KIMI_MODEL=k3 KIMI_AI_KEY=kk KIMI_DAILY_CAP_CALLS=40
export KIMI_URL="http://127.0.0.1:$(cat "$stubdir/kimi-port")"
export ZAI_MODEL=glm-5.3-flash Z_AI_API_KEY=zz
export ZAI_URL="http://127.0.0.1:$(cat "$stubdir/zai-port")"
export OCGO_MODEL=glm-5.3-flash OPENCODE_API_KEY=oo
export OCGO_URL="http://127.0.0.1:$(cat "$stubdir/ocgo-port")"
out="$(call p1)"
ck "ladder: deck answers first" "deck-says-hi" "$out"
ck "ladder: MODEL_USED=deck" "deck:deck" "$(used)"
ck "ladder: kimi never POSTed" "0" "$(wc -l <"$stubdir/kimi-hits")"
ck "ladder: zai never POSTed" "0" "$(wc -l <"$stubdir/zai-hits")"

# --- deck dead -> kimi; zai/ocgo untouched ------------------------------
set_row deck-model-endpoint "http://127.0.0.1:1"
out="$(call p2)"
ck "deck dead: kimi answers" "kimi-says-hi" "$out"
ck "deck dead: MODEL_USED=kimi:k3" "kimi:k3" "$(used)"
ck "deck dead: zai never POSTed" "0" "$(wc -l <"$stubdir/zai-hits")"

# --- kimi dead -> zai ----------------------------------------------------
export KIMI_URL=http://127.0.0.1:1
out="$(call p3)"
ck "kimi dead: zai answers" "zai-says-hi" "$out"
ck "kimi dead: MODEL_USED=zai" "zai:glm-5.3-flash" "$(used)"
ck "kimi dead: ocgo never POSTed" "0" "$(wc -l <"$stubdir/ocgo-hits")"

# --- zai dead -> ocgo -----------------------------------------------------
export ZAI_URL=http://127.0.0.1:1
out="$(call p4)"
ck "zai dead: ocgo answers" "ocgo-says-hi" "$out"
ck "zai dead: MODEL_USED=ocgo" "ocgo:glm-5.3-flash" "$(used)"

# --- all quota legs dead -> local bench (unsloth) as LAST resort ---------
export OCGO_URL=http://127.0.0.1:1
printf 'bench-tok' >"$sb/tok"
chmod 600 "$sb/tok" # unsloth leg mode-gates its token file (gap-unsloth-tokenfile-600-gate)
STUB_CONTENT=bench-says-hi stub_start unsloth
export UNSLOTH_URL="http://127.0.0.1:$(cat "$stubdir/unsloth-port")"
export TOKEN_FILE="$sb/tok" REFRESH_FILE="$sb/rtok"
out="$(call p5)"
ck "quota all dead: local bench answers" "bench-says-hi" "$out"
ck "quota all dead: MODEL_USED=unsloth" "unsloth:stub-model" "$(used)"

# --- local bench dead too -> archive-only --------------------------------
export TOKEN_FILE="$sb/nope" REFRESH_FILE="$sb/nope2" UNSLOTH_URL=http://127.0.0.1:1
out="$(call p6)"
ck "all dead: empty stdout" "" "$out"
ck "all dead: archive-only used" "none:archive-only" "$(used)"
ls "$sb"/archive/skipped-*.txt >/dev/null 2>&1 &&
  echo "ok: all dead: prompt archived" ||
  {
    echo "FAIL: all dead: prompt not archived"
    fails=$((fails + 1))
  }

# --- review beat sandbox: unparseable -> bad-execution demotion ----------
git -C "$sb/kernel" init -q
git -C "$sb" init -q
gitc() { git -C "$1" -c user.email=t@t -c user.name=t commit -q --allow-empty -m t; }
gitc "$sb/kernel"
gitc "$sb"
run_beat() { # (runs cadence/calendar/daily/04-review-prep.sh; caller set the stub row)
  (
    export AUTOMATION_ROOT="$sb" STATE_FILE="$sb/STATE.md" JOB_NAME=review-test
    export HOME="$sb" DIGEST_DIR="$sb/digest" HNGH_HOME="$sb/kernel"
    # model-demote.sh's REPORT call does not set HNGH_REPORT_ROOT itself;
    # without this the report stub writes ./queue.log into the caller's cwd
    export HNGH_REPORT_ROOT="$sb/kernel"
    export HNGH_HOME_DIR="$sb/hnghhome" MODEL_TIMEOUT=5 MODEL_MAX_TOKENS=512
    export DEMOTE_STATE="$sb/state/model-demote.tsv"
    export HNGH_TELEMETRY_DB="$sb/telemetry.db"
    export TOKEN_FILE="$sb/nope" REFRESH_FILE="$sb/nope2" REMOTE_TOKEN_FILE="$sb/nope3"
    export UNSLOTH_URL=http://127.0.0.1:1 OLLAMA_URL=http://127.0.0.1:1
    unset KIMI_URL KIMI_AI_KEY KIMI_MODEL ZAI_URL Z_AI_API_KEY ZAI_MODEL
    unset OCGO_URL OPENCODE_API_KEY OCGO_MODEL
    bash "$sb/cadence/calendar/daily/04-review-prep.sh" >/dev/null 2>&1
  )
}
STUB_CONTENT="print Hello world" stub_start deck2
set_row deck-model-endpoint "http://127.0.0.1:$(cat "$stubdir/deck2-port")"
run_beat
ck "unparseable beat: exits 0" "0" "$?"
ck "unparseable: demotion row deck:deck x1" \
  "$(printf 'deck:deck\t1')" \
  "$(awk -F'\t' '$1=="deck:deck"{print $1"\t"$2}' "$sb/state/model-demote.tsv")"
# the tsv persists only model/count/demoted (never the class string), so
# prove the bad-execution class the only way the contract exposes it: a
# second unparseable beat increments the counter (dead/unknown would not)
# and crosses the threshold-2 demotion alert.
run_beat
ck "unparseable x2: counter deck:deck x2" \
  "$(printf 'deck:deck\t2')" \
  "$(awk -F'\t' '$1=="deck:deck"{print $1"\t"$2}' "$sb/state/model-demote.tsv")"
grep -q 'model deck:deck demoted' "$sb/kernel/queue.log" &&
  echo "ok: unparseable x2: demotion alert filed" ||
  {
    echo "FAIL: unparseable x2: no demotion alert"
    fails=$((fails + 1))
  }
grep -q 'unparseable' "$sb/kernel/queue.log" &&
  echo "ok: unparseable: alert filed" ||
  {
    echo "FAIL: unparseable: no alert row"
    fails=$((fails + 1))
  }

# --- parseable review -> no demotion, review-done ------------------------
STUB_CONTENT="$(printf '## hngh\n- nit: stub finding\n## hngh-automation\nno findings')" \
  stub_start deck3
set_row deck-model-endpoint "http://127.0.0.1:$(cat "$stubdir/deck3-port")"
rm -f "$sb/state/model-demote.tsv"
run_beat
ck "parseable beat: exits 0" "0" "$?"
[ -s "$sb/state/model-demote.tsv" ] &&
  {
    echo "FAIL: parseable beat: model demoted"
    fails=$((fails + 1))
  } ||
  echo "ok: parseable beat: no demotion"
grep -q 'via deck:deck' "$sb/STATE.md" &&
  echo "ok: parseable beat: review-done breadcrumb" ||
  {
    echo "FAIL: parseable beat: no review-done"
    fails=$((fails + 1))
  }
[ -f "$sb/digest/REVIEW-$(date -u +%Y-%m-%d).md" ] &&
  echo "ok: parseable beat: REVIEW digest written" ||
  {
    echo "FAIL: parseable beat: no REVIEW digest"
    fails=$((fails + 1))
  }
grep -q 'terse markdown list' "$stubdir/deck3-bodies" &&
  echo "ok: parseable beat: review packet sent to model" ||
  {
    echo "FAIL: parseable beat: empty prompt — packet never reached the model"
    fails=$((fails + 1))
  }

[ "$fails" = 0 ] && echo "test-review-ladder: all pass" || {
  echo "test-review-ladder: $fails failure(s)"
  exit 1
}
