#!/usr/bin/env bash
# test-research-review.sh -- two-sided review protocol proofs (2026-09-12
# operator directive): the review transition runs a supportive pass and an
# adversarial pass, cross-considers related crystallized findings, records
# BOTH passes in the dispositions support/oppose/followons columns, writes
# the committed sidecar transcript, and queues up to 2 follow-on subjects
# per pass (fail-<date> id convention) on an adopted verdict.
# Hermetic: stub endpoints only, sandbox repo copy, no real model, no
# ~/.hngh writes, no live telemetry.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
stubdir="$(mktemp -d)"
stub_pids=""
trap 'rm -rf "$sb" "$stubdir"; [ -z "$stub_pids" ] || kill $stub_pids 2>/dev/null' EXIT
mkdir -p "$sb/lib" "$sb/jobs" "$sb/cadence" "$sb/archive" "$sb/dashboard" \
 "$sb/digest" "$sb/kernel/docs/research" "$sb/kernel/scripts" "$sb/kernel/docs/project" \
 "$sb/.config/hngh" "$sb/report-root"
cp -r "$root/lib/." "$sb/lib/"
cp -r "$root/jobs/telemetry.py" "$sb/jobs/"
cp -r "$root/cadence/." "$sb/cadence/"
cp "$HOME/Projects/etc/hngh/scripts/report-queue" "$sb/kernel/scripts/"
: >"$sb/cadence-params.tsv"
: >"$sb/STATE.md"

git -C "$sb/kernel" init -q
git -C "$sb/kernel" config user.email test@hngh.local
git -C "$sb/kernel" config user.name test
git -C "$sb/kernel" commit -q --allow-empty -m seed

. "$root/tests/stub-lib.sh"
stub_start stubU # unsloth (local chain)
stub_start stubK # kimi
stubU_port="$(cat "$stubdir/stubU-port")"
stubK_port="$(cat "$stubdir/stubK-port")"
printf 'stub-token-never-real' >"$sb/unsloth-token"
kimi_env=("KIMI_AI_KEY=stub-key-never-real" "KIMI_MODEL=kimi-test-model" "KIMI_URL=http://127.0.0.1:$stubK_port")

BEAT_ENV=(
 AUTOMATION_ROOT="$sb" STATE_FILE="$sb/STATE.md" JOB_NAME=33-research-beat.sh
 HNGH_HOME="$sb/kernel" HNGH_REPORT_ROOT="$sb/report-root"
 RESEARCH_SYNTH_STAMP_FILE="$sb/synth-stamp"
 FAILFIRST_STATE_DIR="$sb/ff" RESEARCH_LOCK_FILE="$sb/lock"
 TOKEN_FILE="$sb/unsloth-token" REFRESH_FILE="$sb/nope"
 REMOTE_TOKEN_FILE="$sb/nope3" REMOTE_URL=http://127.0.0.1:1
 UNSLOTH_URL=http://127.0.0.1:$stubU_port OLLAMA_URL=http://127.0.0.1:1
 OLLAMA_MODEL=stub-ollama MODEL=stub-model UNSLOTH_FALLBACK_MODELS=""
 MODEL_TIMEOUT=5 MODEL_MAX_TOKENS=4096 KIMI_KEY_FILE="$sb/.config/hngh/kimi-key"
)
beat_run() { # [K=V ...] -> one hour-beat run; caller args win
 (
  cd "$sb"
  rm -f "$sb/beat-stamp"
  env -i PATH="$PATH" HOME="$sb" "${BEAT_ENV[@]}" \
   RESEARCH_STAMP_FILE="$sb/beat-stamp" RESEARCH_BEAT_COUNT_FILE="$sb/beat-count" \
   RESEARCH_LOADAVG_FILE="$sb/loadavg" \
   "$@" \
   bash "$sb/cadence/hour/33-research-beat.sh" >/dev/null 2>&1
 )
}
fails=0
ck() { # desc expected actual
 if [ "$2" = "$3" ]; then echo "ok: $1"; else
  echo "FAIL: $1 (expected $2, got $3)"
  fails=$((fails + 1))
 fi
}
seed_review() { # -> crystallized line-old (+ related line-rel doc)
 printf 'line-old\tcrystallized\t2026-09-05T00:00:00Z\tcompaction patterns\n' \
  >"$sb/research-lines.tsv"
 printf '# compaction patterns\n\ndoc-old body\n' \
  >"$sb/kernel/docs/research/2026-09-05-line-old.md"
 printf 'line-rel\tcrystallized\t2026-09-06T00:00:00Z\tunrelated\n' \
  >>"$sb/research-lines.tsv"
 printf '# compaction patterns survey\n\nrelated body\n' \
  >"$sb/kernel/docs/research/2026-09-04-line-rel.md"
}
today8="$(date -u +%Y%m%d)"

# --- a) two passes, both recorded, related findings cross-considered ------
seed_review
beat_run "${kimi_env[@]}"
ck "review: two kimi calls (supportive + adversarial)" "2" "$(wc -l <"$stubdir/stubK-hits" | tr -d ' ')"
sup_body="$(sed -n '1p' "$stubdir/stubK-bodies")"
opp_body="$(sed -n '2p' "$stubdir/stubK-bodies")"
printf '%s' "$sup_body" | grep -q 'SUPPORTIVE review pass' &&
 echo "ok: pass 1 is the supportive pass" ||
 {
  echo "FAIL: pass 1 not supportive"
  fails=$((fails + 1))
 }
printf '%s' "$opp_body" | grep -q 'ADVERSARIAL review pass' &&
 echo "ok: pass 2 is the adversarial pass" ||
 {
  echo "FAIL: pass 2 not adversarial"
  fails=$((fails + 1))
 }
printf '%s' "$opp_body" | grep -q 'DISCONFIRM' &&
 echo "ok: adversarial pass asks to disconfirm" ||
 {
  echo "FAIL: adversarial pass missing DISCONFIRM"
  fails=$((fails + 1))
 }
printf '%s' "$opp_body" | grep -q 'compaction patterns survey' &&
 echo "ok: related findings cross-considered in adversarial pass" ||
 {
  echo "FAIL: related findings not cross-considered"
  fails=$((fails + 1))
 }
row="$(grep $'^line-old\t' "$sb/research-dispositions.tsv" | tail -n 1)"
[ "$(printf '%s' "$row" | awk -F'\t' '{print NF}')" -eq 9 ] &&
 echo "ok: disposition row carries 9 fields" ||
 {
  echo "FAIL: disposition row field count: $(printf '%s' "$row" | awk -F'\t' '{print NF}')"
  fails=$((fails + 1))
 }
[ "$(printf '%s' "$row" | awk -F'\t' '{print $7}')" = "stub-says-hi" ] &&
 echo "ok: supportive pass recorded in column 7" ||
 {
  echo "FAIL: support column: $(printf '%s' "$row" | awk -F'\t' '{print $7}')"
  fails=$((fails + 1))
 }
[ -n "$(printf '%s' "$row" | awk -F'\t' '{print $8}')" ] &&
 echo "ok: adversarial pass recorded in column 8" ||
 {
  echo "FAIL: oppose column empty"
  fails=$((fails + 1))
 }
ls "$sb"/digest/RESEARCH-REVIEW-*-line-old.md >/dev/null 2>&1 &&
 echo "ok: sidecar review transcript written" ||
 {
  echo "FAIL: no sidecar transcript"
  fails=$((fails + 1))
 }
grep -q '## Supportive pass' "$sb"/digest/RESEARCH-REVIEW-*-line-old.md 2>/dev/null &&
 echo "ok: sidecar records both passes" ||
 {
  echo "FAIL: sidecar missing passes"
  fails=$((fails + 1))
 }

# --- b) adopted verdict queues follow-on subjects (fail-<date> ids) -------
printf 'VERDICT: adopted -- stub adopt\nFOLLOWON: why does compaction drift under load\nFOLLOWON: how do patterns compose across lanes\nFOLLOWON: third question over the per-pass cap\n' \
 >"$stubdir/verdict-reply"
printf 'line-old\tcrystallized\t2026-09-05T00:00:00Z\tcompaction patterns\n' \
 >"$sb/research-lines.tsv"
rm -f "$sb/research-dispositions.tsv"
beat_run "${kimi_env[@]}"
n="$(grep -c "^fail-$today8-" "$sb/research-subjects.txt" 2>/dev/null || true)"
ck "adopted: follow-on subjects queued (2 per pass cap)" "2" "$n"
row="$(grep $'^line-old\t' "$sb/research-dispositions.tsv" | tail -n 1)"
[ "$(printf '%s' "$row" | awk -F'\t' '{print $2}')" = "adopted" ] &&
 echo "ok: adopted verdict parsed" ||
 {
  echo "FAIL: verdict: $(printf '%s' "$row" | awk -F'\t' '{print $2}')"
  fails=$((fails + 1))
 }
[ -n "$(printf '%s' "$row" | awk -F'\t' '{print $9}')" ] &&
 echo "ok: followons recorded in column 9" ||
 {
  echo "FAIL: followons column empty"
  fails=$((fails + 1))
 }
grep -q "why does compaction drift under load" "$sb/research-subjects.txt" &&
 echo "ok: follow-on question text queued verbatim" ||
 {
  echo "FAIL: follow-on question text missing"
  fails=$((fails + 1))
 }

# --- c) non-adopted verdict queues nothing --------------------------------
rm -f "$stubdir/verdict-reply" "$sb/research-subjects.txt" \
 "$sb/research-dispositions.tsv"
printf 'line-old\tcrystallized\t2026-09-05T00:00:00Z\tcompaction patterns\n' \
 >"$sb/research-lines.tsv"
beat_run "${kimi_env[@]}"
[ -f "$sb/research-subjects.txt" ] &&
 {
  echo "FAIL: parked verdict queued subjects"
  fails=$((fails + 1))
 } ||
 echo "ok: parked verdict queues no follow-on subjects"

echo
if [ "$fails" -eq 0 ]; then echo "ALL OK"; else
 echo "FAILED: $fails assertion(s)"
 exit 1
fi
