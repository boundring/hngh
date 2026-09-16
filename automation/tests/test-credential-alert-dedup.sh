#!/usr/bin/env bash
# test-credential-alert-dedup.sh — the credential-health alert seam must
# dedup repeatable findings against the PUBLIC report ledger (public-push
# exposure, 2026-09-16): the same failing condition observed run after run
# must fold into one row (identity) and re-fire only when the underlying
# evidence changes — never append one row per run. Hermetic: a fake
# report-queue records invocations; no network, no real ledger writes.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
cleanup() { rm -rf "$sb"; }
trap cleanup EXIT
fails=0
ck() {
  if [ "$2" = "$3" ]; then echo "ok: $1"; else
    echo "FAIL: $1 (want [$2] got [$3])"
    fails=$((fails + 1))
  fi
}

# source the job's alert() seam directly (single source of truth): stub
# common.sh's seams first so the job sources harmlessly, then override the
# probe harness vars before the alert-seam contract checks below.
export FAKE_QUEUE_LOG="$sb/calls.log"
: >"$FAKE_QUEUE_LOG"
export AUTOMATION_ROOT="$root"
export HNGH_HOME="$sb/hngh-home" # fake kernel root; report-queue is faked
mkdir -p "$HNGH_HOME"
export STATE_FILE="$sb/STATE.md"
: >"$STATE_FILE"
export HNGH_REPORT_ROOT="$sb/report-root"
export JOB_NAME="credential-health-test"

# minimal stand-ins for the job's sourced libs (only what sourcing needs)
params_sh="$sb/params.sh"
cat >"$params_sh" <<'EOF'
get_param() { printf '%s' "$2"; }
EOF
# stand-in must be defined BEFORE the job header sources params.sh
get_param() { printf '%s' "$2"; }
job="$sb/job.sh"
sed -e "s#^\. \"\$(cd \"\$(dirname \"\$0\")/..\" && pwd)/lib/common.sh\"#: #" \
    -e "s#^\. \"\$AUTOMATION_ROOT/lib/breadcrumbs.sh\"#. \"$root/lib/breadcrumbs.sh\" #" \
    -e "s#^\. \"\$AUTOMATION_ROOT/lib/model.sh\"#: #" \
    -e "s#^\. \"\$AUTOMATION_ROOT/lib/notify.sh\"#: #" \
    -e "s#^\. \"\$AUTOMATION_ROOT/lib/params.sh\"#. \"$params_sh\" #" \
    -e "s#^report_queue=.*#report_queue=\"\$HNGH_HOME/scripts/report-queue\"#" \
    "$root/jobs/credential-health.sh" |
  # keep the header + redact_home + alert() definitions; the probe
  # sections below would run real seams if sourced, so cut at alert's end
  awk '/^alert\(\)/{f=1} {print} f && /^\}$/{exit}' >"$job"
# shellcheck disable=SC1090
. "$job" || exit 1
# the seam under test is the job's own alert(); no copied logic
type alert >/dev/null 2>&1 || { echo "FAIL: alert() not sourced"; exit 1; }

# fake report-queue at the path the job invokes: log argv, exit 0
mkdir -p "$HNGH_HOME/scripts"
cat >"$HNGH_HOME/scripts/report-queue" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_QUEUE_LOG"
exit 0
EOF
chmod +x "$HNGH_HOME/scripts/report-queue"
: >"$FAKE_QUEUE_LOG"
: >"$STATE_FILE"

# 1. every alert carries --identity (row-flood guard, kind + identity dedup)
alert "unsloth-token" "refresh failed (pair decayed)"
alert "unsloth-token" "refresh failed (pair decayed)"
n_id="$(grep -c -- '--identity credential:unsloth-token:' "$FAKE_QUEUE_LOG")"
ck "every alert passes --identity" "2" "$n_id"

# 2. every alert carries a non-empty --evidence (re-fire-only-on-change)
n_ev="$(grep -c -- '--evidence [0-9a-z]' "$FAKE_QUEUE_LOG")"
ck "every alert passes --evidence" "2" "$n_ev"

# 3. identity is stable across identical findings (dedup key, no per-run salt)
first_ident="$(sed -n 's/.*--identity \(credential:[^ ]*\) .*/\1/p' "$FAKE_QUEUE_LOG" | head -1)"
second_ident="$(sed -n 's/.*--identity \(credential:[^ ]*\) .*/\1/p' "$FAKE_QUEUE_LOG" | tail -1)"
ck "identical findings share one identity" "$first_ident" "$second_ident"

# 4. http-code findings key evidence on the code (changed code = re-fire)
: >"$FAKE_QUEUE_LOG"
alert "unsloth-token" "unexpected http=500 on session probe"
alert "unsloth-token" "unexpected http=502 on session probe"
evs="$(sed -n 's/.*--evidence \(http=[0-9]*\).*/\1/p' "$FAKE_QUEUE_LOG" | tr '\n' ' ')"
ck "evidence keys on the observed http code" "http=500 http=502 " "$evs"

# 5. no absolute home path may reach the alert text (redaction upstream)
: >"$FAKE_QUEUE_LOG"
alert "unsloth-token" "session token file missing ($HOME/.hngh-automation/unsloth.token)"
grep -q "$HOME" "$FAKE_QUEUE_LOG" && got=leak || got=clean
ck "alert text free of absolute home path" "clean" "$got"
ck "redacted row names the tilde path" "1" \
  "$(grep -c '~/\.hngh-automation/unsloth\.token' "$FAKE_QUEUE_LOG")"

echo "---"
[ "$fails" -eq 0 ] && echo "ALL PASS" || {
  echo "$fails FAILED"
  exit 1
}
