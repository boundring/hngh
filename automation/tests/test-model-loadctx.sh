#!/usr/bin/env bash
# test-model-loadctx.sh -- the Unsloth load context pin (plan
# 2026-09-22-vram-small-model-guardrails step 1) + xiaomi quota leg
# (step 2b):
#   (a) 2xx /load -> exactly one load POST whose body carries the
#       max_seq_length value (the ctx-standard row here is 7777, not
#       16384, so a body carrying 7777 proves the row was read)
#   (b) non-200 /load -> the chat attempt still runs and a load-ctx
#       breadcrumb saying "continuing unpinned" is written (fail-open)
#   (c) HNGH_LOADCTX_PIN=0 -> zero /load POSTs (hermetic kill switch)
#   (d) MODEL_CTX env beats the ctx-standard row
#   (e) xiaomi leg: no key -> skipped fail-closed (no xiaomi: tag);
#       key env + stub URL -> one POST, MODEL_USED=xiaomi:mimo-v2.6-pro
#   argv hygiene: no bearer/key value ever rides an argv (curl or
#   report-queue) -- the stdin curl-config (-K -) law
# Hermetic: no network at all -- a fake curl answers canned JSON and
# logs argv + request bodies; fake $HNGH_HOME report-queue argv logger
# (test-memory-gate.sh pattern); sandbox repo copy.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d /tmp/hngh-loadctx-test.XXXXXX)"
trap 'rm -rf "$sb"' EXIT
fake="$sb/fake"
mkdir -p "$sb/home/db" "$sb/lib" "$sb/jobs" "$sb/archive" "$sb/.config/hngh" "$fake/bin"
cp -r "$root/lib/." "$sb/lib/"
cp "$root/jobs/telemetry.py" "$sb/jobs/"
# crumbs seam: the journal db is the source of record; reads go through
# the export bridge (STATE.md is a derived export, never materialized)
export HNGH_CRUMBS_DB="$sb/crumbs.db"
journal() { python3 "$root/lib/crumbs-db.py" export --db "$HNGH_CRUMBS_DB" 2>/dev/null; }
# ctx-standard row is deliberately NOT 16384: a pin body carrying 7777
# proves the row was read (the 16384 fallback would never emit it)
printf 'ctx-standard\t7777\ttest\ttest row\n' >"$sb/cadence-params.tsv"
printf 'stub-token-never-real' >"$sb/unsloth-token"
chmod 600 "$sb/unsloth-token" # unsloth leg mode-gates its token file
HNGH_HOME="$sb/hngh"
export HNGH_HOME
mkdir -p "$HNGH_HOME/scripts"
export FAKE_QUEUE_LOG="$fake/queue-calls.log"
cat >"$HNGH_HOME/scripts/report-queue" <<'EOF'
#!/usr/bin/env python3
import os, sys

with open(os.environ["FAKE_QUEUE_LOG"], "a") as f:
    f.write(" ".join(sys.argv[1:]) + "\n")
EOF
chmod +x "$HNGH_HOME/scripts/report-queue"
export HNGH_NOTIFY_EMAIL_CONF="$fake/no-conf"
# fake curl: argv + request logger answering canned JSON (no network).
# Every invocation logs its argv (the argv-hygiene proof) and the URL
# path + body, then replies per path: /api/inference/load answers
# $FAKE_LOAD_STATUS (default 200), everything else its canned shape.
cat >"$fake/bin/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${FAKE_CURL_ARGV_LOG:?}"
out="" fmt="" body="" url=""
while [ $# -gt 0 ]; do
 case "$1" in
 -o) out="$2"; shift 2 ;;
 -w) fmt="$2"; shift 2 ;;
 -d)
  case "$2" in @*) body="$(cat "${2#@}")" ;; *) body="$2" ;; esac
  shift 2 ;;
 -K) [ "${2:-}" = "-" ] && cat >/dev/null; shift 2 ;;
 -H | -X | --max-time | --connect-timeout | --noproxy | --cacert) shift 2 ;;
 http://* | https://*) url="$1"; shift ;;
 *) shift ;;
 esac
done
p="/${url#*://}"
p="/${p#*/}"
case "$p" in
 */api/inference/load) status="${FAKE_LOAD_STATUS:-200}"; resp='{"ok":true}' ;;
 */api/inference/status) status=200; resp='{"context_length":65536}' ;;
 */stub-xiaomi*) status=200
  resp='{"choices":[{"message":{"content":"xiaomi-says-hi"}}],"usage":{"prompt_tokens":3,"completion_tokens":2}}' ;;
 */v1/chat/completions) status=200
  resp='{"choices":[{"message":{"content":"unsloth-says-hi"}}],"usage":{"prompt_tokens":3,"completion_tokens":2},"finish_reason":"stop"}' ;;
 *) status=404; resp='{}' ;;
esac
printf '%s\t%s\n' "$p" "$body" >>"${FAKE_CURL_REQ_LOG:?}"
[ -z "$out" ] || [ "$out" = /dev/null ] || printf '%s' "$resp" >"$out"
if [ -n "$fmt" ]; then
 fmt="${fmt//"%{http_code}"/$status}"
 printf '%s' "${fmt//"%{time_total}"/0.01}"
fi
exit 0
EOF
chmod +x "$fake/bin/curl"
fails=0
ck() { # desc expected actual
 if [ "$2" = "$3" ]; then echo "ok: $1"; else
  echo "FAIL: $1 (want [$2] got [$3])"
  fails=$((fails + 1))
 fi
}
hits() { # pattern -> request-log line count (0 when none)
 local n
 n="$(grep -c "$1" "$fake/curl-req.log" 2>/dev/null)"
 printf '%s' "${n:-0}"
}
count() { # pattern file -> match count (0 when absent)
 local n
 n="$(grep -c "$1" "$2" 2>/dev/null)"
 printf '%s' "${n:-0}"
}
reset_logs() {
 : >"$fake/curl-req.log"
 : >"$fake/curl-argv.log"
 : >"$FAKE_QUEUE_LOG"
 rm -f "$HNGH_CRUMBS_DB" # fresh journal per case: counts stay per-case
}
leg() { # model.sh code [K=V ...] -> stdout of one sandbox run
 (
  export PATH="$fake/bin:$PATH"
  export FAKE_CURL_ARGV_LOG="$fake/curl-argv.log" FAKE_CURL_REQ_LOG="$fake/curl-req.log"
  export AUTOMATION_ROOT="$sb" JOB_NAME=test
  export HOME="$sb" HNGH_HOME_DIR="$sb/home"
  export TOKEN_FILE="$sb/unsloth-token" REFRESH_FILE="$sb/nope"
  export UNSLOTH_URL="http://127.0.0.1:1/studio" MODEL=stub-model MODEL_TIMEOUT=5
  unset MODEL_CTX HNGH_LOADCTX_PIN FAKE_LOAD_STATUS
  unset XIAOMI_AI_API_KEY XIAOMI_URL XIAOMI_MODEL XIAOMI_KEY_FILE
  code="$1"
  shift
  for kv in "$@"; do export "$kv"; done
  bash -c ". \"$AUTOMATION_ROOT/lib/model.sh\"; $code" </dev/null
 )
}
# (a) 2xx pin: exactly one load POST carrying the row's max_seq_length
reset_logs
out="$(leg 'unsloth_chat "say ok" 16 stub-model')"
ck "2xx pin: chat answered" "unsloth-says-hi" "$out"
ck "2xx pin: one load POST" "1" "$(hits '/api/inference/load')"
ck "2xx pin: body carries ctx-standard row 7777" "1" "$(hits 'max_seq_length[^0-9]*7777')"
ck "argv hygiene: bearer never on curl argv" "0" "$(count 'stub-token-never-real' "$fake/curl-argv.log")"
ck "argv hygiene: bearer never on report-queue argv" "0" "$(count 'stub-token-never-real' "$FAKE_QUEUE_LOG")"

# (b) non-200 load: fail-open to unpinned + one breadcrumb
reset_logs
out="$(leg 'unsloth_chat "say ok" 16 stub-model' FAKE_LOAD_STATUS=500)"
ck "non-200 load: chat attempt still ran" "unsloth-says-hi" "$out"
ck "non-200 load: chat POST happened" "1" "$(hits '/v1/chat/completions')"
ck "non-200 load: one load-ctx breadcrumb" "1" "$(count 'load-ctx' <(journal))"
ck "non-200 load: breadcrumb says continuing unpinned" "1" "$(count 'continuing unpinned' <(journal))"

# (c) HNGH_LOADCTX_PIN=0: zero load POSTs (hermetic kill switch)
reset_logs
out="$(leg 'unsloth_chat "say ok" 16 stub-model' HNGH_LOADCTX_PIN=0)"
ck "pin off: chat answered" "unsloth-says-hi" "$out"
ck "pin off: zero load POSTs" "0" "$(hits '/api/inference/load')"
ck "pin off: chat POST happened" "1" "$(hits '/v1/chat/completions')"

# (d) MODEL_CTX env beats the ctx-standard row
reset_logs
out="$(leg 'unsloth_chat "say ok" 16 stub-model' MODEL_CTX=4321)"
ck "MODEL_CTX beats row: body carries 4321" "1" "$(hits 'max_seq_length[^0-9]*4321')"
ck "MODEL_CTX beats row: row value absent" "0" "$(hits '7777')"

# (e) xiaomi leg: no key fails closed; key + stub URL answers once
reset_logs
rm -f "$sb/tmp-modelused.txt"
leg '_xiaomi_leg "say ok" 16' XIAOMI_URL="http://127.0.0.1:1/stub-xiaomi/v1/chat/completions" XIAOMI_MODEL=mimo-v2.6-pro >/dev/null
ck "xiaomi no key: zero xiaomi POSTs" "0" "$(hits 'stub-xiaomi')"
ck "xiaomi no key: MODEL_USED not xiaomi:" "0" "$(count '^xiaomi:' "$sb/tmp-modelused.txt")"
reset_logs
rm -f "$sb/tmp-modelused.txt"
leg '_xiaomi_leg "say ok" 16' XIAOMI_AI_API_KEY=stub-xiaomi-key-never-real \
 XIAOMI_URL="http://127.0.0.1:1/stub-xiaomi/v1/chat/completions" XIAOMI_MODEL=mimo-v2.6-pro >/dev/null
ck "xiaomi armed: exactly one POST" "1" "$(hits 'stub-xiaomi')"
ck "xiaomi armed: MODEL_USED tagged" "xiaomi:mimo-v2.6-pro" "$(cat "$sb/tmp-modelused.txt" 2>/dev/null)"
ck "xiaomi argv hygiene: key never on curl argv" "0" "$(count 'stub-xiaomi-key-never-real' "$fake/curl-argv.log")"
ck "xiaomi argv hygiene: key never on report-queue argv" "0" "$(count 'stub-xiaomi-key-never-real' "$FAKE_QUEUE_LOG")"

# (f) ocgo pacing gate (2026-09-22 quota-tier re-arm): cap 0 blocks the
#     leg forever (the dead-leg shape that kept ocgo dark); a real cap
#     admits the call
reset_logs
rm -f "$sb/tmp-modelused.txt"
leg '_ocgo_leg "say ok" 16' OCGO_URL="http://127.0.0.1:1/stub-ocgo/v1/chat/completions" \
 OCGO_MODEL=glm-test OPENCODE_API_KEY=stub-ocgo-key \
 OCGO_CAP_5H_CALLS=60 OCGO_CAP_7D_CALLS=150 OCGO_CAP_MONTH_CALLS=0 >/dev/null
ck "ocgo cap 0: leg stays blocked" "0" "$(hits 'stub-ocgo')"
ck "ocgo cap 0: MODEL_USED not ocgo:" "0" "$(count '^ocgo:' "$sb/tmp-modelused.txt")"
reset_logs
rm -f "$sb/tmp-modelused.txt"
leg '_ocgo_leg "say ok" 16' OCGO_URL="http://127.0.0.1:1/stub-ocgo/v1/chat/completions" \
 OCGO_MODEL=glm-test OPENCODE_API_KEY=stub-ocgo-key \
 OCGO_CAP_5H_CALLS=60 OCGO_CAP_7D_CALLS=150 OCGO_CAP_MONTH_CALLS=300 >/dev/null
ck "ocgo cap>0: exactly one POST" "1" "$(hits 'stub-ocgo')"
ck "ocgo cap>0: MODEL_USED tagged" "ocgo:glm-test" "$(cat "$sb/tmp-modelused.txt" 2>/dev/null)"

if [ "$fails" -gt 0 ]; then
 echo "loadctx contract: $fails FAILURES"
 exit 1
fi
echo "loadctx contract: all cases passed"
