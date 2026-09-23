#!/usr/bin/env bash
# test-research-doc-writer-redact.sh -- the crystallized research-doc
# writer seam must never emit raw machine-local path tokens onto the
# git-tracked, publicly pushed docs/research surface (2026-09-17 GAP,
# wiki-health-wiring-reconcile::gate: the crystallize transition
# printf'd the RAW line text as the doc title and the RAW model body
# with no redact_home -- docfilter.py covers injection + char cap
# only -- so docs/research/2026-09-17-fail-20260916-If-the-probe-*.
# md line 1 landed carrying a literal /home/<user> path and 144
# tracked research docs carried 'bricker').
#
# Red-first: this suite FAILS against the unguarded writer and passes
# once redact_home (lib/scrub.py, the single tilde token family,
# fail-closed) covers the crystallized-doc TITLE emitter and the body
# gets a same-family double-cover, plus the digest beat copy for
# symmetry. Two-lane reality: the model body arrives pre-scrubbed from
# the model_call chokepoint (lib/model.sh _scrub_paths, the marker
# family of the same lib/scrub.py), so the body assertions prove
# markers + URL preservation; the TITLE is direct lines-TSV text and
# must arrive tilde-rendered (raw -> ~/..., existing tilde untouched --
# the redact_home fixpoint invariant).
#
# Hermetic: full-beat harness (stub model chain, sandbox kernel git
# repo, sandbox digest/archive under HOME), no real model, no
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
 "$sb/.config/hngh" "$sb/report-root" "$sb/.hngh/archive/digest"
cp -r "$root/lib/." "$sb/lib/"
[ -f "$sb/lib/scrub.py" ] || {
 echo "FAIL: sandbox lib/scrub.py missing"
 exit 1
}
# scrub.sh resolves lib/scrub.py from $AUTOMATION_ROOT; a broken copy
# must fail this suite loudly, never fake a pass through redact_home's
# fail-closed empty output.
SCRUB_PROBE="$(AUTOMATION_ROOT="$sb" bash -c \
 '. "'"$sb"'/lib/scrub.sh"; redact_home_impl "/home/probe/x"')"
[ "$SCRUB_PROBE" = "~/x" ] || {
 echo "FAIL: sandbox redact_home broken: $SCRUB_PROBE"
 exit 1
}
cp -r "$root/jobs/telemetry.py" "$sb/jobs/"
cp -r "$root/cadence/." "$sb/cadence/"
cp "$root/../scripts/report-queue" "$sb/kernel/scripts/"
: >"$sb/cadence-params.tsv"
: >"$sb/STATE.md"

# kernel IS a git repo here: the free-commit lane must engage (the
# crystallized doc lands on the public surface through research_commit)
git -C "$sb/kernel" init -q
git -C "$sb/kernel" config user.email test@hngh.local
git -C "$sb/kernel" config user.name test
git -C "$sb/kernel" commit -q --allow-empty -m seed

. "$root/tests/stub-lib.sh"
# Pathy model body: absolute /home + /tmp tokens, an already-tilde
# token (fixpoint: must stay), and a URL whose path contains /home
# (wire data: must stay verbatim).
STUB_CONTENT='The gate lives at /home/testuser/Projects/etc/hngh/tests and the
scratch state at /tmp/hngh-scratch. Prior note ~/Projects/notes.md
already uses the ledger convention, and https://x.io/home/u/f is wire
data that must survive verbatim.' stub_start stubU
stubU_port="$(cat "$stubdir/stubU-port")"
printf 'stub-token-never-real' >"$sb/unsloth-token"
chmod 600 "$sb/unsloth-token"

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
  echo "FAIL: $1 (want [$2] got [$3])"
  fails=$((fails + 1))
 fi
}
no_raw() { # desc file -> fails if the file carries a raw /home/testuser
 if grep -q '/home/testuser' "$2" 2>/dev/null; then
  echo "FAIL: $1 (raw /home/testuser in $2)"
  fails=$((fails + 1))
 else
  echo "ok: $1"
 fi
}

# Pathy line id + question text seeded straight into the lines TSV
# (the production writer reads column 4 verbatim and titles the
# crystallized doc with it; the id mirrors the real leaked shape,
# fail-<date>-<slug> derived from a pathy question).
PATHY_ID="fail-20260916-If-the-probe-returns-a-clean-negative-for-the"
day="$(date -u +%Y-%m-%d)"
doc="$sb/kernel/docs/research/$day-$PATHY_ID.md"
digest="$sb/.hngh/archive/digest/RESEARCH-BEAT-$day-$PATHY_ID.md"
printf '0.10 0.20 0.10 1/900 1234\n' >"$sb/loadavg"
printf '%s\tplanned\t%s\tIf the probe returns a clean negative for /home/testuser/Projects/etc/hngh/tests (prior note ~/Projects/notes.md) does the gate pass?\n' \
 "$PATHY_ID" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$sb/research-lines.tsv"

# three transitions planned->expanding->contracting->crystallized; the
# crystallize beat writes + commits the doc
beat_run
beat_run
beat_run

# (1) the crystallized doc exists and was committed
[ -f "$doc" ] || {
 echo "FAIL: crystallized doc missing: $doc"
 fails=$((fails + 1))
}
msg="$(git -C "$sb/kernel" log -1 --format=%s)"
ck "crystallize commit message" "research: $PATHY_ID crystallized" "$msg"

# (2) THE GAP: zero raw /home tokens anywhere in the committed doc,
# title line AND body alike
no_raw "crystallized doc: no raw /home token" "$doc"
# HEAD-blob proof (the public surface, not just the worktree):
blob="$(mktemp)"
git -C "$sb/kernel" show "HEAD:docs/research/$(basename "$doc")" >"$blob" 2>/dev/null
if [ -s "$blob" ]; then
 no_raw "HEAD blob carries no raw /home" "$blob"
else
 echo "FAIL: crystallized doc not committed to HEAD"
 fails=$((fails + 1))
fi
rm -f "$blob"

# (3) title lane: redact_home rendered the raw path in place (tilde
# family) and left the pre-existing tilde token untouched (fixpoint)
title_head="$(head -1 "$doc")"
case "$title_head" in
*'~/Projects/etc/hngh/tests'*) echo "ok: title raw path tilde-rendered" ;;
*)
 echo "FAIL: title raw path not tilde-rendered: $title_head"
 fails=$((fails + 1))
 ;;
esac
case "$title_head" in
*'~/Projects/notes.md'*) echo "ok: title pre-existing tilde preserved (fixpoint)" ;;
*)
 echo "FAIL: title pre-existing tilde clobbered: $title_head"
 fails=$((fails + 1))
 ;;
esac

# (4) body lane: arrives marker-scrubbed from the model chokepoint; the
# URL home component must survive verbatim (wire data, not filesystem)
grep -qF 'https://x.io/home/u/f' "$doc" ||
 {
  echo "FAIL: URL home component clobbered"
  fails=$((fails + 1))
 }
grep -qF '[redacted path]' "$doc" ||
 {
  echo "FAIL: body marker lane missing"
  fails=$((fails + 1))
 }
echo "ok: body marker lane + URL preservation in crystallized doc"

# (5) digest beat copy (symmetry): pathy FILENAME and CONTENT both clean
if [ -f "$digest" ]; then
 no_raw "digest copy: no raw /home token" "$digest"
 grep -qF '[redacted path]' "$digest" ||
  {
   echo "FAIL: digest body marker lane missing"
   fails=$((fails + 1))
  }
 case "$(head -2 "$digest" | tail -1)" in
 *'/home/testuser'*)
  echo "FAIL: digest header line leaked"
  fails=$((fails + 1))
  ;;
 *) echo "ok: digest header line clean" ;;
 esac
else
 echo "FAIL: digest copy missing: $digest"
 fails=$((fails + 1))
fi

if [ "$fails" -eq 0 ]; then
 echo "test-research-doc-writer-redact: all assertions passed"
else
 echo "test-research-doc-writer-redact: $fails assertion(s) failed"
 exit 1
fi
