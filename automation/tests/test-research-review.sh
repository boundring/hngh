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
# fixture containment: never inherit repo selection from the caller's shell (2026-09-17 kernel-contamination lesson)
unset GIT_DIR GIT_WORK_TREE
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
stubdir="$(mktemp -d)"
stub_pids=""
trap 'rm -rf "$sb" "$stubdir"; [ -z "$stub_pids" ] || kill $stub_pids 2>/dev/null' EXIT
mkdir -p "$sb/lib" "$sb/jobs" "$sb/cadence" "$sb/archive" "$sb/dashboard" \
 "$sb/digest" "$sb/kernel/docs/research" "$sb/kernel/scripts" "$sb/kernel/docs/project" \
 "$sb/.config/hngh" "$sb/report-root"
cp -r "$root/lib/." "$sb/lib/"
# typesafe stub (park-on-untyped harness): module mode answers ask_choices
# from TYPESAFE_STUB_VERDICT or the VERDICT line in state['adversarial']
# (conf TYPESAFE_STUB_CONF, default 0.90); no TYPESAFE_API_KEY -> {}
# fail-closed. CLI mode (beat triage glue) prints nothing -> legacy
# fallback, byte-equivalent to the real module's no-key behavior.
cat >"$sb/lib/typesafe.py" <<'PYEOF'
import os
import re
import sys


def ask_choices(state, questions):
    if not os.environ.get("TYPESAFE_API_KEY"):
        return {}
    verdict = os.environ.get("TYPESAFE_STUB_VERDICT", "")
    if not verdict:
        m = re.search(r"VERDICT:\s*(adopted|parked|killed)",
                      str(state.get("adversarial", "")))
        verdict = m.group(1) if m else "parked"
    try:
        conf = float(os.environ.get("TYPESAFE_STUB_CONF", "0.90"))
    except ValueError:
        conf = 0.90
    return {name: (verdict, conf) for name in questions}


if __name__ == "__main__":
    sys.exit(0)
PYEOF
cp -r "$root/jobs/telemetry.py" "$sb/jobs/"
cp -r "$root/cadence/." "$sb/cadence/"
cp "$root/../scripts/report-queue" "$sb/kernel/scripts/"
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
chmod 600 "$sb/unsloth-token" # unsloth leg mode-gates its token file (gap-unsloth-tokenfile-600-gate)
kimi_env=("KIMI_AI_KEY=stub-key-never-real" "KIMI_MODEL=kimi-test-model" "KIMI_URL=http://127.0.0.1:$stubK_port")

BEAT_ENV=(
 AUTOMATION_ROOT="$sb" STATE_FILE="$sb/STATE.md" JOB_NAME=33-research-beat.sh
 HNGH_HOME="$sb/kernel" HNGH_REPORT_ROOT="$sb/report-root"
 RESEARCH_SYNTH_STAMP_FILE="$sb/synth-stamp"
 FAILFIRST_STATE_DIR="$sb/ff" RESEARCH_LOCK_FILE="$sb/lock"
 TOKEN_FILE="$sb/unsloth-token" REFRESH_FILE="$sb/nope"
 REMOTE_TOKEN_FILE="$sb/nope3" REMOTE_URL=http://127.0.0.1:1
 UNSLOTH_URL=http://127.0.0.1:$stubU_port OLLAMA_URL=http://127.0.0.1:1
 OLLAMA_MODEL=stub-ollama MODEL=stub-model UNSLOTH_FALLBACK_MODELS="" HNGH_LOADCTX_PIN=0
 MODEL_TIMEOUT=5 MODEL_MAX_TOKENS=4096 KIMI_KEY_FILE="$sb/.config/hngh/kimi-key"
 TYPESAFE_API_KEY=stub-key-never-real
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
# ground-truth gate (P6): an adopted verdict needs a named evidence
# item in the SUPPORTIVE pass text -- the stub's default leg reply
# carries one for this case (default-reply hook, removed after)
printf '%s\n' 'corroborated by docs/research/2026-09-06-line-old.md:12 (stub evidence)' \
 >"$stubdir/default-reply"
beat_run "${kimi_env[@]}"
rm -f "$stubdir/default-reply"
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

# --- d) stale 6-column header upgraded to the writer schema ---------------
printf 'line\taction\tverdict\treviewer\tevidence\tdate\n' \
 >"$sb/research-dispositions.tsv"
printf 'old-line\tadopted\ta\tm\tdocs/old.md\t2026-09-01\n' \
 >>"$sb/research-dispositions.tsv"
printf 'line-old\tcrystallized\t2026-09-05T00:00:00Z\tcompaction patterns\n' \
 >"$sb/research-lines.tsv"
beat_run "${kimi_env[@]}"
hdr_nf="$(head -n 1 "$sb/research-dispositions.tsv" | awk -F'\t' '{print NF}')"
[ "$hdr_nf" -eq 9 ] &&
 echo "ok: stale header upgraded to 9 columns" ||
 {
  echo "FAIL: stale header field count: $hdr_nf"
  fails=$((fails + 1))
 }
grep -qxF $'old-line\tadopted\ta\tm\tdocs/old.md\t2026-09-01' \
 "$sb/research-dispositions.tsv" &&
 echo "ok: pre-existing row preserved under upgraded header" ||
 {
  echo "FAIL: pre-existing row lost during header upgrade"
  fails=$((fails + 1))
 }

# P8b helpers -------------------------------------------------------------
bodies() { # <report-root> <identity-substring> -> body sidecar count
 grep -rl "$2" "$1/docs/project/report-bodies" 2>/dev/null | wc -l | tr -d ' '
}
disp_run() { # <report-root> [K=V ...] -> one review-disposition run
 local rroot="$1"
 shift
 (
  cd "$sb"
  env -i PATH="$PATH" HOME="$sb" AUTOMATION_ROOT="$sb" \
   JOB_NAME=06-review-disposition.sh DIGEST_DIR="$sb/digest" \
   HNGH_HOME="$sb/kernel" HNGH_REPORT_ROOT="$rroot" "$@" \
   bash "$sb/cadence/calendar/daily/06-review-disposition.sh" >/dev/null 2>&1
 )
}

# --- e) review-disposition: typed-decided routes, untyped parks -----------
printf -- '- P1: auth bypass in webhook handler\n- nit: rename variable\n' \
 >"$sb/digest/REVIEW-$(date -u +%Y-%m-%d).md"
# positive control: typed decides both (P1 wins; severity_of RAISES the
# nit to P1) -> both findings route as review-finding rows, no gap row
disp_run "$sb/report-root" TYPESAFE_API_KEY=stub-key-never-real \
 TYPESAFE_STUB_VERDICT=P1 TYPESAFE_STUB_CONF=0.90
ck "review-disposition: typed-decided routes 2 findings" "2" \
 "$(bodies "$sb/report-root" review-finding:)"
ck "review-disposition: typed-decided files no gap row" "0" \
 "$(bodies "$sb/report-root" typed-gap:review-disposition)"
# no key -> every finding parks; legacy prefixes advisory in ONE gap row
disp_run "$sb/report-root2" TYPESAFE_API_KEY=
ck "review-disposition: untyped routes nothing" "0" \
 "$(bodies "$sb/report-root2" review-finding:)"
ck "review-disposition: untyped parks with ONE gap row" "1" \
 "$(bodies "$sb/report-root2" typed-gap:review-disposition)"
grep -rl "typed-gap:review-disposition" "$sb/report-root2/docs/project/report-bodies" |
 xargs grep -q "legacy prefixes: P1,nit (advisory only)" &&
 echo "ok: gap row lists legacy prefixes as advisory" ||
 {
  echo "FAIL: gap row lists legacy prefixes as advisory"
  fails=$((fails + 1))
 }
# typed but below the 0.5 floor -> parks too
disp_run "$sb/report-root3" TYPESAFE_API_KEY=stub-key-never-real \
 TYPESAFE_STUB_VERDICT=P1 TYPESAFE_STUB_CONF=0.30
ck "review-disposition: below-floor parks" "1" \
 "$(bodies "$sb/report-root3" typed-gap:review-disposition)"

# --- f) research beat: untyped verdict parks, legacy stays advisory -------
rm -f "$sb/research-dispositions.tsv" "$sb/research-subjects.txt"
seed_review
printf 'VERDICT: adopted -- stub adopt\n' >"$stubdir/verdict-reply"
# typed decides but conf 0.30 < 0.60 floor -> park
beat_run "${kimi_env[@]}" TYPESAFE_STUB_CONF=0.30
# no key -> seam fail-closed {} -> park; same gap identity dedups (7d)
beat_run "${kimi_env[@]}" TYPESAFE_API_KEY=
row="$(grep $'^line-old\t' "$sb/research-dispositions.tsv" | tail -n 1)"
[ "$(printf '%s' "$row" | awk -F'\t' '{print $2}')" = "parked" ] &&
 echo "ok: beat untyped verdict parks" ||
 {
  echo "FAIL: beat untyped verdict parks"
  fails=$((fails + 1))
 }
printf '%s' "$row" | awk -F'\t' '$3 ~ /^parked untyped: typed verdict unavailable/' |
 grep -q . &&
 echo "ok: parked reason cites untyped typed lane" ||
 {
  echo "FAIL: parked reason cites untyped typed lane"
  fails=$((fails + 1))
 }
ck "beat: ONE deduped typed-gap row across both parks" "1" \
 "$(bodies "$sb/report-root" typed-gap:research-beat)"
grep -rl "typed-gap:research-beat" "$sb/report-root/docs/project/report-bodies" |
 xargs grep -q "legacy VERDICT: adopted (advisory only)" &&
 echo "ok: beat gap row keeps legacy verdict advisory" ||
 {
  echo "FAIL: beat gap row keeps legacy verdict advisory"
  fails=$((fails + 1))
 }
[ ! -f "$sb/research-subjects.txt" ] &&
 echo "ok: parked verdict queues no follow-on subjects" ||
 {
  echo "FAIL: parked verdict queued follow-on subjects"
  fails=$((fails + 1))
 }
rm -f "$stubdir/verdict-reply"

echo
if [ "$fails" -eq 0 ]; then echo "ALL OK"; else
 echo "FAILED: $fails assertion(s)"
 exit 1
fi
