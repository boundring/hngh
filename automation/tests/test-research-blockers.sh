#!/usr/bin/env bash
# test-research-blockers.sh -- roguelike research operations (2026-09-12
# operator directive): research lines use the orchestrator blocker ledger
# (lib/beat-blockers.sh, scope research:<id>).
#   a) dead model lane twice with the same cause parks the line + files
#      the alert; parked lines are not picked while any other line lives;
#   b) success clears the row (one dead run, then a green run);
#   c) junk capture (tool-call syntax) twice parks with cause junk-capture;
#   d) blocker-park-cooldown-hours auto-unpark returns the line to the pool.
# Hermetic: stub endpoints only, sandbox repo copy, no real model.
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
: >"$sb/STATE.md"
printf 'blocker-park-cooldown-hours\t9999\thermetic test\tstay parked within sections a-c\n' \
 >"$sb/cadence-params.tsv"

git -C "$sb/kernel" init -q
git -C "$sb/kernel" config user.email test@hngh.local
git -C "$sb/kernel" config user.name test
git -C "$sb/kernel" commit -q --allow-empty -m seed

. "$root/tests/stub-lib.sh"
stub_start stubU # healthy local chain leg
# junk-capture leg: a model that answers only in tool-call syntax
STUB_CONTENT='<tool_call>
<parameter=command>
</parameter>
</tool_call>' stub_start stubJ
stubU_port="$(cat "$stubdir/stubU-port")"
stubJ_port="$(cat "$stubdir/stubJ-port")"
printf 'stub-token-never-real' >"$sb/unsloth-token"
DEAD=("UNSLOTH_URL=http://127.0.0.1:1" "OLLAMA_URL=http://127.0.0.1:1")

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
  rm -rf "$sb/ff" # fresh fail-first state: every run goes full speed
  env -i PATH="$PATH" HOME="$sb" "${BEAT_ENV[@]}" \
   RESEARCH_STAMP_FILE="$sb/beat-stamp" RESEARCH_BEAT_COUNT_FILE="$sb/beat-count" \
   RESEARCH_LOADAVG_FILE="$sb/loadavg" \
   "$@" \
   bash "$sb/cadence/hour/33-research-beat.sh" >/dev/null 2>&1
 )
}
reset_beat() { # n-planned-lines -> fresh pool + blocker ledger
 rm -f "$sb/beat-stamp" "$sb/beat-count" "$sb/research-dispositions.tsv" \
  "$sb/lock" "$sb/state/beat-blockers.tsv"
 : >"$sb/research-lines.tsv"
 local i=1
 while [ "$i" -le "$1" ]; do
  printf 'line-%s\tplanned\t2026-09-0%sT00:00:00Z\tdesc-%s\n' \
   "$i" "$i" "$i" >>"$sb/research-lines.tsv"
  i=$((i + 1))
 done
}
blk() { awk -F'\t' -v s="research:$1" '$2==s{print $3" "$5" "$6}' \
 "$sb/state/beat-blockers.tsv" 2>/dev/null; }
fails=0
ck() { if [ "$2" = "$3" ]; then echo "ok: $1"; else
 echo "FAIL: $1 (expected $2, got $3)"
 fails=$((fails + 1))
fi; }

# --- a) same-cause double failure (dead model lane) parks the line --------
reset_beat 2
beat_run "${DEAD[@]}"
ck "first dead run: attempt recorded" "model-lane-dead 1 active" "$(blk line-1)"
sleep 1
beat_run "${DEAD[@]}"
ck "second dead run: line parked" "model-lane-dead 2 parked" "$(blk line-1)"
grep -q 'parked after 2 consecutive model-lane-dead' "$sb/STATE.md" &&
 echo "ok: park alert filed" ||
 {
  echo "FAIL: no park alert"
  fails=$((fails + 1))
 }
beat_run # healthy chain: line-2 must advance, parked line-1 stays held
grep -q $'^line-2\texpanding\t' "$sb/research-lines.tsv" &&
 echo "ok: parked line skipped, sibling advanced" ||
 {
  echo "FAIL: line-2 not advanced"
  fails=$((fails + 1))
 }
grep -q $'^line-1\tplanned\t' "$sb/research-lines.tsv" &&
 echo "ok: parked line state held" ||
 {
  echo "FAIL: line-1 state moved"
  fails=$((fails + 1))
 }

# --- b) success clears the row --------------------------------------------
reset_beat 1
beat_run "${DEAD[@]}"
ck "one dead run: attempt active" "model-lane-dead 1 active" "$(blk line-1)"
beat_run # same line, healthy chain -> transition succeeds
grep -q $'^line-1\texpanding\t' "$sb/research-lines.tsv" &&
 echo "ok: line advanced after recovery" ||
 {
  echo "FAIL: line not advanced"
  fails=$((fails + 1))
 }
ck "success clears the blocker row" "" "$(blk line-1)"

# --- c) junk capture twice parks with its own cause ------------------------
reset_beat 1
beat_run "UNSLOTH_URL=http://127.0.0.1:$stubJ_port"
ck "first junk run: attempt recorded" "junk-capture 1 active" "$(blk line-1)"
sleep 1
beat_run "UNSLOTH_URL=http://127.0.0.1:$stubJ_port"
ck "second junk run: line parked" "junk-capture 2 parked" "$(blk line-1)"
grep -q 'parked after 2 consecutive junk-capture' "$sb/STATE.md" &&
 echo "ok: junk-capture park alert filed" ||
 {
  echo "FAIL: no junk-capture park alert"
  fails=$((fails + 1))
 }
grep -q $'^line-1\tplanned\t' "$sb/research-lines.tsv" &&
 echo "ok: junk-parked line state held for retry" ||
 {
  echo "FAIL: line-1 state moved"
  fails=$((fails + 1))
 }

# --- d) cooldown auto-unpark (blocker-park-cooldown-hours row) -------------
printf 'blocker-park-cooldown-hours\t0\thermetic test\tunpark immediately\n' \
 >"$sb/cadence-params.tsv"
sleep 1
beat_run # blocker_tick(0h) unparks at beat start; line-1 then advances
grep -q $'^line-1\texpanding\t' "$sb/research-lines.tsv" &&
 echo "ok: parked line auto-unparked and advanced" ||
 {
  echo "FAIL: line-1 not advanced after cooldown"
  fails=$((fails + 1))
 }
ck "unparked row released" "" "$(blk line-1)"

echo
if [ "$fails" -eq 0 ]; then echo "ALL OK"; else
 echo "FAILED: $fails assertion(s)"
 exit 1
fi
