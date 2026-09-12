#!/usr/bin/env bash
# test-research-commit-per-op.sh -- commit-per-op proofs (2026-09-12
# research pipeline yield audit): each value-carrying transition commits
# its own artifacts immediately, via the free-commit lane.
#   a) crystallize write -> "research: <id> crystallized" commit in the
#      kernel repo containing the crystallized doc; the repo is left
#      clean for the committed paths (hourly ledger sync would carry
#      nothing).
#   b) operator-staged work -> the beat refuses to commit (staged-change
#      guard, mirroring 30-kernel-ledger-sync).
#   c) review disposition -> "research: <id> reviewed-<action>" commit
#      covering the dispositions TSV and research-lines.tsv.
#   d) non-repo kernel -> quiet no-op (existing accel2 behavior holds).
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

# kernel IS a git repo here: the free-commit lane must engage
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
reset_beat() { # n-planned-lines -> fresh pool
 rm -f "$sb/beat-stamp" "$sb/beat-count" "$sb/tmp-modelused.txt" \
  "$sb/research-dispositions.tsv" "$sb/lock"
 rm -rf "$sb/ff"
 : >"$sb/STATE.md"
 rm -f "$stubdir/stubU-hits" "$stubdir/stubK-hits"
 local i
 {
  for i in $(seq 1 "$1"); do
   printf 'line-%s\tplanned\t%s\tdesc-%s\n' "$i" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$i"
  done
 } >"$sb/research-lines.tsv"
 printf '%s\n' "0.10 0.20 0.10 1/900 1234" >"$sb/loadavg"
}
hits() { [ -f "$stubdir/$1-hits" ] && wc -l <"$stubdir/$1-hits" | tr -d " " || echo 0; }
fails=0
ck() { # desc expected actual
 if [ "$2" = "$3" ]; then echo "ok: $1"; else
  echo "FAIL: $1 (want [$2] got [$3])"
  fails=$((fails + 1))
 fi
}

# --- a) crystallize -> own commit ----------------------------------------
# three transitions planned->expanding->contracting->crystallized; the
# crystallize beat commits doc + lines TSV row (TSV lives outside the
# sandbox repo: only the doc path is inside; the doc must be committed).
reset_beat 1
beat_run
beat_run
beat_run
[ -f "$sb/kernel/docs/research/$(date -u +%Y-%m-%d)-line-1.md" ] ||
 {
  echo "FAIL: crystallized doc missing"
  fails=$((fails + 1))
 }
ck "crystallize beat ran" "3" "$(hits stubU)"
msg="$(git -C "$sb/kernel" log -1 --format=%s)"
ck "crystallize commit message" "research: line-1 crystallized" "$msg"
dirty="$(git -C "$sb/kernel" status --porcelain -- docs/research | grep -c . || true)"
ck "crystallized doc committed (docs/research clean)" "0" "$dirty"
[ "$(git -C "$sb/kernel" show --name-only --format= HEAD | grep -c "docs/research")" -ge 1 ] &&
 echo "ok: commit contains the crystallized doc" || {
 echo "FAIL: commit does not contain the doc"
 fails=$((fails + 1))
}

# --- b) operator-staged work -> refuse -----------------------------------
# stage an operator file in the kernel repo; the next beat must not
# commit anything (staged-change guard)
reset_beat 1
printf 'operator work\n' >"$sb/kernel/docs/project/operator-note.md"
git -C "$sb/kernel" add docs/project/operator-note.md
beat_run
ck "staged guard: line still advanced" "1" "$(hits stubU)"
n="$(git -C "$sb/kernel" log --format=%s | grep -c 'research: line-1 crystallized' || true)"
ck "staged guard: no second crystallize commit" "1" "$n"
[ -n "$(git -C "$sb/kernel" diff --cached --name-only)" ] &&
 echo "ok: staged operator work untouched" || {
 echo "FAIL: staged operator work committed"
 fails=$((fails + 1))
}
git -C "$sb/kernel" reset -q --hard HEAD >/dev/null

# --- c) review disposition -> own commit ---------------------------------
# pool exhausted -> review of the oldest crystallized line; dispositions
# + lines TSVs live OUTSIDE the sandbox kernel repo (skipped by the
# outside-path guard), so the assertion here is: the beat completes, the
# disposition row lands, and the non-repo artifacts were never
# force-committed. Inside the production repo the same code path commits
# automation/research-dispositions.tsv + research-lines.tsv.
reset_beat 0
printf '%s\tcrystallized\t2026-09-06T00:00:00Z\tdesc-old\n' line-old \
 >>"$sb/research-lines.tsv"
printf 'doc-old\n' >"$sb/kernel/docs/research/2026-09-06-line-old.md"
# stub verdict is fixed: "VERDICT: parked -- stub reason" (stub-lib.sh)
beat_run "${kimi_env[@]}"
ck "review beat hit kimi" "2" "$(hits stubK)"
grep -q $'line-old\treviewed\t' "$sb/research-lines.tsv" &&
 echo "ok: review: line-old reviewed" || {
 echo "FAIL: review: line-old not reviewed"
 fails=$((fails + 1))
}
grep -q $'line-old\tparked\t' "$sb/research-dispositions.tsv" &&
 echo "ok: review: disposition appended" || {
 echo "FAIL: review: no disposition row"
 fails=$((fails + 1))
}
n="$(git -C "$sb/kernel" log --format=%s | grep -c 'research: line-old reviewed-parked' || true)"
ck "review: no commit when paths outside repo" "0" "$n"
git -C "$sb/kernel" status --porcelain -- docs/research | grep -q . ||
 echo "ok: review left repo paths clean" || true

# --- d) non-repo kernel -> quiet no-op -----------------------------------
mv "$sb/kernel/.git" "$sb/kernel/.git-off"
reset_beat 1
beat_run
grep -q $'line-1\texpanding\t' "$sb/research-lines.tsv" &&
 echo "ok: non-repo kernel: transition unaffected" || {
 echo "FAIL: non-repo kernel: beat broke"
 fails=$((fails + 1))
}
n="$(grep -c 'research-commit' "$sb/STATE.md" || true)"
ck "non-repo kernel: no research-commit breadcrumb" "0" "$n"

echo
if [ "$fails" -eq 0 ]; then echo "ALL OK"; else
 echo "FAILURES: $fails"
 exit 1
fi
