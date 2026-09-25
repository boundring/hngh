#!/usr/bin/env bash
# test-research-gewu.sh -- refoundation P6 proofs at the gewu boundary
# (2026-09-25): the cached per-UTC-day orientation pack
# (scripts/context-pack.sh), the question-not-beat mint gate (unsourced
# synthesizer lines and slug-matching repeats land as questions under
# existing entries, never as new beats), and the ground-truth gate
# (an adopted verdict must name a specific evidence item).
# Hermetic: stub endpoints only, sandbox trees, no real model, no
# ~/.hngh writes, no live telemetry.
set -u
# fixture containment: never inherit repo selection from the caller's shell
unset GIT_DIR GIT_WORK_TREE
root="$(cd "$(dirname "$0")/.." && pwd)"
fails=0
ck() { # desc expected actual
 if [ "$2" = "$3" ]; then echo "ok: $1"; else
  echo "FAIL: $1 (want [$2] got [$3])"
  fails=$((fails + 1))
 fi
}

# --- a) context-pack.sh: built once per day, five headers, fail-soft ----
pa="$(mktemp -d)"
stubdir="$(mktemp -d)"
pb="" pc="" pd="" pe="" sbx="" stub_pids=""
trap 'rm -rf "$pa" "$pb" "$pc" "$pd" "$pe" "$sbx" "$stubdir"; [ -z "$stub_pids" ] || kill $stub_pids 2>/dev/null' EXIT
mkdir -p "$pa/logs"
pack_file="$pa/logs/context-pack-$(date -u +%F).txt"
AUTOMATION_ROOT="$pa" HNGH_HOME="$pa/kernel" HNGH_REPORT_ROOT="$pa/report-root" \
 bash "$root/scripts/context-pack.sh"
ck "pack: file built" "1" "$([ -s "$pack_file" ] && echo 1 || echo 0)"
ck "pack: five headers" "5" \
 "$(grep -cE '^== (dispositions|lessons|backlog|alerts|srcs) ==$' "$pack_file")"
m1="$(stat -c %Y "$pack_file")"
c1="$(cat "$pack_file")"
sleep 1
AUTOMATION_ROOT="$pa" HNGH_HOME="$pa/kernel" HNGH_REPORT_ROOT="$pa/report-root" \
 bash "$root/scripts/context-pack.sh"
ck "pack: second run leaves mtime (built once)" "$m1" "$(stat -c %Y "$pack_file")"
ck "pack: second run leaves content" "$c1" "$(cat "$pack_file")"

# populated inputs land in the right sections
printf 'line\taction\tverdict\treviewer\tevidence\tdate\tsupport\toppose\tfollowons\n' \
 >"$pa/research-dispositions.tsv"
printf 'loop-recognition\tadopted\t--\tm:x\tdocs/a.md\t2026-09-20\ts\to\tf\n' \
 >>"$pa/research-dispositions.tsv"
mkdir -p "$pa/kernel/docs/project" "$pa/docs"
printf '| ledger-sync | a lesson |\n' >"$pa/kernel/docs/project/lessons-index.md"
printf '## staging-discipline (2)\nbody\n' >"$pa/docs/BACKLOG.md"
rm -f "$pack_file"
AUTOMATION_ROOT="$pa" HNGH_HOME="$pa/kernel" HNGH_REPORT_ROOT="$pa/report-root" \
 bash "$root/scripts/context-pack.sh"
sec() { awk -v s="$1" '$0=="== "s" =="{on=1;next} on&&/^== [a-z]+ ==$/{on=0} on' "$pack_file"; }
ck "pack: dispositions section carries rows" "loop-recognition" \
 "$(sec dispositions | grep -m1 '^loop-recognition' | cut -f1)"
ck "pack: lessons title reaches srcs" "ledger-sync" \
 "$(sec srcs | grep -m1 '^ledger-sync$')"
ck "pack: backlog section carries titles" "staging-discipline" \
 "$(sec backlog | grep -m1 '^## staging-discipline' | sed 's/^## //;s/ (.*//')"
ck "pack: srcs carries the disposition id" "loop-recognition" \
 "$(sec srcs | grep -m1 '^loop-recognition$')"

# --- b) demand_synthesize consumes the cached pack (sentinel probe) ----
pb="$(mktemp -d)"
mkdir -p "$pb/lib" "$pb/jobs" "$pb/cadence" "$pb/scripts" "$pb/archive" \
 "$pb/dashboard" "$pb/kernel/scripts" "$pb/kernel/docs/research" \
 "$pb/kernel/docs/project" "$pb/docs" "$pb/logs" "$pb/report-root"
cp -r "$root/lib/." "$pb/lib/"
cp -r "$root/jobs/telemetry.py" "$pb/jobs/"
cp -r "$root/cadence/." "$pb/cadence/"
cp "$root/../scripts/report-queue" "$pb/kernel/scripts/"
cp "$root/scripts/context-pack.sh" "$pb/scripts/"
: >"$pb/cadence-params.tsv"
: >"$pb/STATE.md"
export PB_CRUMBS="$pb/crumbs.db"
crumbs() { python3 "$root/lib/crumbs-db.py" export --db "$PB_CRUMBS" 2>/dev/null; }
. "$root/tests/stub-lib.sh"
stub_start stubU # unsloth (local chain)
stub_start stubK # kimi
stubK_port="$(cat "$stubdir/stubK-port")"
stubU_port="$(cat "$stubdir/stubU-port")"
printf 'stub-token-never-real' >"$pb/unsloth-token"
chmod 600 "$pb/unsloth-token"
day="$(date -u +%Y-%m-%d)"
kimi_env=("KIMI_AI_KEY=stub-key-never-real" "KIMI_MODEL=kimi-test-model"
 "KIMI_URL=http://127.0.0.1:$stubK_port")
BEAT_ENV=(
 AUTOMATION_ROOT="$pb" HNGH_CRUMBS_DB="$PB_CRUMBS" JOB_NAME=33-research-beat.sh
 HNGH_HOME="$pb/kernel" HNGH_REPORT_ROOT="$pb/report-root"
 RESEARCH_SYNTH_STAMP_FILE="$pb/synth-stamp"
 FAILFIRST_STATE_DIR="$pb/ff" RESEARCH_LOCK_FILE="$pb/lock"
 TOKEN_FILE="$pb/unsloth-token" REFRESH_FILE="$pb/nope"
 REMOTE_TOKEN_FILE="$pb/nope3" REMOTE_URL=http://127.0.0.1:1
 UNSLOTH_URL=http://127.0.0.1:$stubU_port OLLAMA_URL=http://127.0.0.1:1
 OLLAMA_MODEL=stub-ollama MODEL=stub-model UNSLOTH_FALLBACK_MODELS=""
 HNGH_LOADCTX_PIN=0
 MODEL_TIMEOUT=5 MODEL_MAX_TOKENS=4096 KIMI_KEY_FILE="$pb/.config/hngh/kimi-key"
)
beat_run() { # [K=V ...] -> one hour-beat run; caller args win
 (
  cd "$pb"
  rm -f "$pb/beat-stamp"
  env -i PATH="$PATH" HOME="$pb" "${BEAT_ENV[@]}" \
   RESEARCH_STAMP_FILE="$pb/beat-stamp" RESEARCH_BEAT_COUNT_FILE="$pb/beat-count" \
   RESEARCH_LOADAVG_FILE="$pb/loadavg" \
   "$@" \
   bash "$pb/cadence/hour/33-research-beat.sh" >/dev/null 2>&1
 )
}
reset_beat() { # -> empty pool, fresh subjects/stamp/counters
 rm -f "$pb/beat-stamp" "$pb/beat-count" "$pb/synth-stamp" "$pb/lock" \
  "$pb/research-dispositions.tsv"
 rm -rf "$pb/ff" "$pb/.hngh"
 : >"$stubdir/stubU-hits"
 : >"$stubdir/stubK-hits"
 : >"$pb/research-subjects.txt"
 : >"$pb/research-lines.tsv"
 printf '0.10 0.20 0.10 1/900 1234' >"$pb/loadavg"
}

# pre-seed the pack: the sentinel exists ONLY here, so a hit in the
# captured prompt proves the synth path read the cache, not a re-gather
sentinel="GEWU-SENTINEL-ALERT-42"
{
 printf '== dispositions ==\n\n'
 printf '== lessons ==\n\n'
 printf '== backlog ==\n\n'
 printf '== alerts ==\n%s\n' "$sentinel"
 printf '== srcs ==\n%s\n' "$sentinel"
} >"$pb/logs/context-pack-$day.txt"
p_mtime="$(stat -c %Y "$pb/logs/context-pack-$day.txt")"
reset_beat
printf 'synth-%s-1\tDoes the %s alert need a guardrail before retry?\nsynth-%s-2\tWholly unrelated musing about the weather.\n' \
 "$day" "$sentinel" "$day" >"$stubdir/synth-reply"
beat_run "${kimi_env[@]}"
printf '%s' "$(cat "$stubdir/stubU-bodies" "$stubdir/stubK-bodies" 2>/dev/null)" | grep -q "$sentinel" &&
 echo "ok: synth: cached pack consumed (sentinel reached the prompt)" ||
 {
  echo "FAIL: synth: sentinel missing from model prompt"
  fails=$((fails + 1))
 }
ck "synth: pack reused, not rebuilt" "$p_mtime" \
 "$(stat -c %Y "$pb/logs/context-pack-$day.txt")"
grep -q "^synth-$day-1	" "$pb/research-subjects.txt" &&
 echo "ok: synth: sourced subject appended" ||
 {
  echo "FAIL: synth: sourced subject not appended"
  fails=$((fails + 1))
 }
grep -q "^question-synth-$day-2	" "$pb/research-subjects.txt" &&
 echo "ok: synth: unsourced line recorded as question-synth" ||
 {
  echo "FAIL: synth: unsourced line not recorded as question"
  fails=$((fails + 1))
 }
grep -q "^synth-$day-2	" "$pb/research-subjects.txt" &&
 {
  echo "FAIL: synth: unsourced line minted a beat id"
  fails=$((fails + 1))
 } ||
 echo "ok: synth: unsourced line never minted a beat id"
grep -q "^synth-$day-1	" "$pb/research-lines.tsv" &&
 echo "ok: synth: sourced subject seeded a line" ||
 {
  echo "FAIL: synth: sourced subject did not seed a line"
  fails=$((fails + 1))
 }
grep -q "^question-synth-$day-2	" "$pb/research-lines.tsv" &&
 {
  echo "FAIL: synth: question row seeded a line"
  fails=$((fails + 1))
 } ||
 echo "ok: synth: question row never seeded a line"

# --- c) double-mint same cause lands under the existing id -------------
pc="$(mktemp -d)"
AUTOMATION_ROOT="$pc" . "$root/lib/causes.sh"
printf 'my-cause\tplanned\t2026-09-20T00:00:00Z\tdesc\n' >"$pc/research-lines.tsv"
AUTOMATION_ROOT="$pc" append_research_subject "My.Cause" \
 "why does my cause recur on consecutive runs?"
grep -q $'my-cause\twhy does my cause recur on consecutive runs?' \
 "$pc/research-subjects.txt" &&
 echo "ok: mint: matched question lands under existing open id" ||
 {
  echo "FAIL: mint: question not landed under existing id"
  fails=$((fails + 1))
 }
AUTOMATION_ROOT="$pc" append_research_subject "My.Cause" \
 "why does my cause recur on consecutive runs?"
ck "mint: identical question deduped (full line)" "1" \
 "$(wc -l <"$pc/research-subjects.txt" | tr -d ' ')"
AUTOMATION_ROOT="$pc" append_research_subject "My.Cause" \
 "a different question about the same cause"
ck "mint: distinct question appended under same id" "2" \
 "$(wc -l <"$pc/research-subjects.txt" | tr -d ' ')"
ck "mint: both rows carry the existing id" "2" \
 "$(grep -c '^my-cause	' "$pc/research-subjects.txt")"
# unmatched slug keeps today's behavior (new fail-<date> id)
AUTOMATION_ROOT="$pc" append_research_subject "solo-cause" "a solo question"
grep -q "^fail-$(date -u +%Y%m%d)-solo-cause	" "$pc/research-subjects.txt" &&
 echo "ok: mint: unmatched slug keeps fail-<date> id" ||
 {
  echo "FAIL: mint: unmatched slug lost the fail-<date> id"
  fails=$((fails + 1))
 }
# no lines file at all (lib-less sandbox shape) still mints
pd="$(mktemp -d)"
AUTOMATION_ROOT="$pd" append_research_subject "solo" "a solo question"
grep -q "^fail-$(date -u +%Y%m%d)-solo	" "$pd/research-subjects.txt" &&
 echo "ok: mint: no lines file -> fail-<date> id unchanged" ||
 {
  echo "FAIL: mint: no lines file broke the fail path"
  fails=$((fails + 1))
 }

# --- d) ensure_lines skips question rows (extracted, driven directly) --
sbx="$(mktemp -d)"
awk '/^ensure_lines\(\) \{/{f=1} f{print} f&&/^\}$/{exit}' \
 "$root/cadence/hour/33-research-beat.sh" >"$sbx/ensure_lines.sh"
grep -q '^ensure_lines()' "$sbx/ensure_lines.sh" ||
 {
  echo "FAIL: ensure_lines extraction"
  exit 1
 }
. "$root/lib/redact.sh"
breadcrumb() { :; }
JOB_NAME=test-gewu
LINES="$sbx/research-lines.tsv"
SUBJECTS="$sbx/research-subjects.txt"
: >"$LINES"
{
 printf 'question-synth-x	why does the thing fail?
'
 printf 'real-subject	a real question
'
} >"$SUBJECTS"
. "$sbx/ensure_lines.sh"
ensure_lines
grep -q "^real-subject	" "$LINES" &&
 echo "ok: ensure: plain subject seeded" ||
 {
  echo "FAIL: ensure: plain subject not seeded"
  fails=$((fails + 1))
 }
grep -q "^question-synth-x	" "$LINES" &&
 {
  echo "FAIL: ensure: question row seeded a line"
  fails=$((fails + 1))
 } ||
 echo "ok: ensure: question row skipped"

# --- e) patrol queue_repeat_subjects mints under the existing open id --
pe="$(mktemp -d)"
printf 'cache-race-stale-store\tplanned\t2026-09-20T00:00:00Z\tdesc\n' \
 >"$pe/research-lines.tsv"
: >"$pe/research-subjects.txt"
patrol_out="$(
 GEWU_ROOT="$root" python3 - "$root/jobs/patrol.py" "$pe" <<'EOF_PYE'
import importlib.util, os, sys, time
spec = importlib.util.spec_from_file_location("patrol", sys.argv[1])
patrol = importlib.util.module_from_spec(spec)
spec.loader.exec_module(patrol)
sb = sys.argv[2]
ctx = {"subjects": os.path.join(sb, "research-subjects.txt"),
       "research_lines": os.path.join(sb, "research-lines.tsv"),
       "now": time.mktime(time.strptime("2026-09-25", "%Y-%m-%d"))}
rids = patrol.queue_repeat_subjects(
    ctx,
    {("cache-race", "stale-store"), ("loner", "solo-flake")},
    {("cache-race", "stale-store"), ("loner", "solo-flake")})
print("\n".join(rids))
EOF_PYE
)"
ck "patrol: returns minted rid tokens" "1" \
 "$([ -n "$patrol_out" ] && echo 1 || echo 0)"
grep -q "^cache-race-stale-store	patrol: surface cache-race" \
 "$pe/research-subjects.txt" &&
 echo "ok: patrol: matching repeat lands under existing open id" ||
 {
  echo "FAIL: patrol: repeat did not land under existing id"
  fails=$((fails + 1))
 }
grep -q "^patrol-20260925-cache-race" "$pe/research-subjects.txt" &&
 {
  echo "FAIL: patrol: parallel rid minted despite match"
  fails=$((fails + 1))
 } ||
 echo "ok: patrol: no parallel rid minted for the matched repeat"
grep -q "^patrol-20260925-loner-solo-flake	" "$pe/research-subjects.txt" &&
 echo "ok: patrol: unmatched repeat keeps the rid mint" ||
 {
  echo "FAIL: patrol: unmatched repeat lost the rid mint"
  fails=$((fails + 1))
 }

# --- f) ground-truth gate: adopted needs a named evidence item ---------
awk '/^named_evidence\(\) \{/{f=1} f{print} f&&/^\}$/{exit}' \
 "$root/cadence/hour/33-research-beat.sh" >"$sbx/gate.sh"
awk '/^ground_truth_gate\(\) \{/{f=1} f{print} f&&/^\}$/{exit}' \
 "$root/cadence/hour/33-research-beat.sh" >>"$sbx/gate.sh"
grep -q '^ground_truth_gate()' "$sbx/gate.sh" ||
 {
  echo "FAIL: gate extraction"
  exit 1
 }
. "$sbx/gate.sh"
ground_truth_gate adopted "stub adopt" "FOLLOWON: q" \
 "plain agreement text with nothing named"
ck "gate: ungrounded adoption -> withheld" "withheld" "$gt_action"
case "$gt_reason" in
"withheld -- no named evidence item: "*) echo "ok: gate: reason prefixed" ;;
*)
 echo "FAIL: gate: reason not prefixed ($gt_reason)"
 fails=$((fails + 1))
 ;;
esac
ck "gate: withheld clears followons" "" "$gt_followons"
ground_truth_gate adopted "stub adopt" "FOLLOWON: q" \
 "corroborated by docs/foo.md:42 in the repo"
ck "gate: file:line evidence stays adopted" "adopted" "$gt_action"
ck "gate: adopted keeps followons" "FOLLOWON: q" "$gt_followons"
ground_truth_gate adopted "r" "" 'the trace:
```
boom
```'
ck "gate: fenced block counts as evidence" "adopted" "$gt_action"
ground_truth_gate adopted "r" "" 'repro:
$ ls -la
total 0'
ck "gate: verbatim command line counts as evidence" "adopted" "$gt_action"
ground_truth_gate adopted "r" "" "see docs/sub/dir/notes.md for the capture"
ck "gate: pathed filename counts as evidence" "adopted" "$gt_action"
ground_truth_gate parked "stub park" "" "plain agreement text with nothing named"
ck "gate: parked never gated" "parked" "$gt_action"
ck "gate: parked reason untouched" "stub park" "$gt_reason"

echo
if [ "$fails" -eq 0 ]; then echo "test-research-gewu: ALL OK"; else
 echo "test-research-gewu: $fails failure(s)"
 exit 1
fi
