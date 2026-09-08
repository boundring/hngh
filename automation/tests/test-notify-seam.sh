#!/usr/bin/env bash
# test-notify-seam.sh — hermetic proof for lib/notify.sh: disarmed-all -> silent
# exit 0; email dispatch invokes scripts/notify-email.py with send/subject/
# body-file; telegram armed via env pair or mode-600 key file -> stub curl
# receives chat_id+text; webhook armed -> JSON {class,subject,body,ts} lands;
# 60s burst limiter suppresses the second immediate send. Token/url VALUES are
# never printed anywhere in captured output. Stub curl + stub notify-email.py
# via PATH; sandbox AUTOMATION_ROOT/HOME; no real endpoints, no real secrets.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
trap 'rm -rf "$sb"' EXIT
mkdir -p "$sb/lib" "$sb/bin" "$sb/scripts" "$sb/.config/hngh" "$sb/stamps"
ln -s "$root/lib/notify.sh" "$sb/lib/"

# stub curl: records args to $CURL_LOG, answers HTTP 200.
cat >"$sb/bin/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CURL_LOG"
echo "200"
EOF
chmod +x "$sb/bin/curl"

# stub notify-email.py: records argv + body-file content, exits 0.
cat >"$sb/scripts/notify-email.py" <<'EOF'
#!/usr/bin/env python3
import os, sys
with open(os.environ["EMAIL_STUB_LOG"], "a") as f:
    f.write(" ".join(sys.argv[1:]) + "\n")
    for i, a in enumerate(sys.argv):
        if a == "--body-file":
            f.write(open(sys.argv[i + 1]).read() + "\n")
EOF
chmod +x "$sb/scripts/notify-email.py"

# one notify_event in the sandbox; per-case env passed as K=V args.
call() { # class subject body [K=V ...] -> stdout
  local cls="$1" subj="$2" body="$3"
  shift 3
  local kv
  (
    export AUTOMATION_ROOT="$sb" HOME="$sb" PATH="$sb/bin:$PATH"
    export JOB_NAME=test HNGH_REPORT_ROOT="$sb"
    export HNGH_NOTIFY_STAMP_DIR="$sb/stamps" CURL_LOG="$sb/curl.log"
    export EMAIL_STUB_LOG="$sb/email.log"
    export HNGH_TELEGRAM_NOTIFY_FILE="$sb/.config/hngh/telegram-notify.env"
    export HNGH_WEBHOOK_NOTIFY_FILE="$sb/.config/hngh/webhook-notify.env"
    rm -f "$sb/curl.log" "$sb/email.log"
    : >"$sb/STATE.md"
    # the operator's session may arm real channels — hermetic tests start bare
    unset TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID HNGH_WEBHOOK_URL
    unset HNGH_NOTIFY_EMAIL_CONF
    for kv in "$@"; do export "$kv"; done
    . "$root/lib/common.sh"
    # common.sh resets AUTOMATION_ROOT to the real repo — repoint at the sandbox
    export AUTOMATION_ROOT="$sb" STATE_FILE="$sb/STATE.md"
    . "$root/lib/breadcrumbs.sh"
    . "$sb/lib/notify.sh"
    notify_event "$cls" "$subj" "$body"
    printf 'rc=%s channels=[%s]' "$?" "$(notify_channels)"
  )
}
fails=0
ck() { # desc expected actual
  if [ "$2" = "$3" ]; then echo "ok: $1"; else
    echo "FAIL: $1 (want [$2] got [$3])"
    fails=$((fails + 1))
  fi
}
no_secret() { # desc value — the secret string must not appear in any seam
  # output (stdout/exit traces or breadcrumbs). curl.log is the stub's wire
  # record and inherently contains the URL token, like the real transport.
  if grep -qF "$2" "$sb/STATE.md" 2>/dev/null || printf '%s' "$CAPTURED" | grep -qF "$2"; then
    echo "FAIL: $1: secret leaked"
    fails=$((fails + 1))
  else
    echo "ok: $1: value never printed"
  fi
}

# --- 1. disarmed-all -> silent exit 0, no stub traffic.
out="$(call test hello body-1)"
ck "disarmed-all: silent exit 0" "rc=0 channels=[]" "$out"
[ -e "$sb/curl.log" ] && {
  echo "FAIL: disarmed-all: curl called"
  fails=$((fails + 1))
}
[ -e "$sb/email.log" ] && {
  echo "FAIL: disarmed-all: email stub called"
  fails=$((fails + 1))
}
echo "ok: disarmed-all: no stub traffic"

rst() { rm -rf "$sb/stamps"; mkdir -p "$sb/stamps"; }
rst

# --- 2. email armed via conf -> stub gets send --subject --body-file + body.
printf 'smtp-stub' >"$sb/notify-email.conf"
out="$(call test subj-email body-email HNGH_NOTIFY_EMAIL_CONF="$sb/notify-email.conf")"
ck "email: armed" "rc=0 channels=[email]" "$out"
grep -q "^send --subject subj-email --body-file" "$sb/email.log" &&
  echo "ok: email: stub invoked with send/subject/body-file" || {
  echo "FAIL: email: bad stub args"
  fails=$((fails + 1))
}
grep -q "body-email" "$sb/email.log" &&
  echo "ok: email: body delivered" || {
  echo "FAIL: email: no body"
  fails=$((fails + 1))
}
rm -f "$sb/notify-email.conf"

rst
# --- 3. telegram armed via env pair -> stub curl gets chat_id+text.
out="$(call test subj-tg body-tg TELEGRAM_BOT_TOKEN=stub-token-never-real \
  TELEGRAM_CHAT_ID=12345)"
ck "telegram env: armed" "rc=0 channels=[telegram]" "$out"
grep -q "data-urlencode chat_id=12345" "$sb/curl.log" &&
  echo "ok: telegram env: chat_id sent" || {
  echo "FAIL: telegram env: no chat_id"
  fails=$((fails + 1))
}
grep -q "body-tg" "$sb/curl.log" &&
  echo "ok: telegram env: text sent" || {
  echo "FAIL: telegram env: no text"
  fails=$((fails + 1))
}
CAPTURED="$out"
no_secret "telegram env" "stub-token-never-real"

rst
# --- 4. telegram armed via mode-600 key file (644 refused).
printf 'TELEGRAM_BOT_TOKEN=stub-file-token-never-real\nTELEGRAM_CHAT_ID=67890\n' \
  >"$sb/.config/hngh/telegram-notify.env"
chmod 600 "$sb/.config/hngh/telegram-notify.env"
out="$(call test subj-tg2 body-tg2)"
ck "telegram key file: armed" "rc=0 channels=[telegram]" "$out"
grep -q "chat_id=67890" "$sb/curl.log" &&
  echo "ok: telegram key file: chat_id sent" || {
  echo "FAIL: telegram key file: no chat_id"
  fails=$((fails + 1))
}
CAPTURED="$out"
no_secret "telegram key file" "stub-file-token-never-real"
rst
chmod 644 "$sb/.config/hngh/telegram-notify.env"
out="$(call test subj-tg3 body-tg3)"
ck "telegram key file 644: disarmed" "rc=0 channels=[]" "$out"
rm -f "$sb/.config/hngh/telegram-notify.env"

rst
# --- 5. webhook armed via env -> JSON body lands in stub.
out="$(call cls-w subj-w body-w HNGH_WEBHOOK_URL=http://127.0.0.1:1/hook)"
ck "webhook env: armed" "rc=0 channels=[webhook]" "$out"
grep -q 'Content-Type: application/json' "$sb/curl.log" &&
  echo "ok: webhook: json content type" || {
  echo "FAIL: webhook: no json type"
  fails=$((fails + 1))
}
grep -q '"class": *"cls-w"' "$sb/curl.log" &&
  grep -q '"subject": *"subj-w"' "$sb/curl.log" &&
  grep -q '"body": *"body-w"' "$sb/curl.log" &&
  grep -q '"ts"' "$sb/curl.log" &&
  echo "ok: webhook: json payload fields" || {
  echo "FAIL: webhook: payload fields missing"
  fails=$((fails + 1))
}
# webhook via key file
rst
printf 'WEBHOOK_URL=http://127.0.0.1:1/hook2\n' >"$sb/.config/hngh/webhook-notify.env"
chmod 600 "$sb/.config/hngh/webhook-notify.env"
out="$(call cls-w2 subj-w2 body-w2)"
ck "webhook key file: armed" "rc=0 channels=[webhook]" "$out"
grep -q "hook2" "$sb/curl.log" &&
  echo "ok: webhook key file: url used" || {
  echo "FAIL: webhook key file"
  fails=$((fails + 1))
}
rm -f "$sb/.config/hngh/webhook-notify.env"

rst
# --- 6. burst limiter: second immediate send on the same channel suppressed.
printf 'smtp-stub' >"$sb/notify-email.conf"
out="$(call burst s1 b1 TELEGRAM_BOT_TOKEN=stub-token-never-real TELEGRAM_CHAT_ID=1 \
  HNGH_WEBHOOK_URL=http://127.0.0.1:1/hook HNGH_NOTIFY_EMAIL_CONF="$sb/notify-email.conf")"
out="$(call burst s2 b2 TELEGRAM_BOT_TOKEN=stub-token-never-real TELEGRAM_CHAT_ID=1 \
  HNGH_WEBHOOK_URL=http://127.0.0.1:1/hook HNGH_NOTIFY_EMAIL_CONF="$sb/notify-email.conf")"
ck "burst: still exit 0" "rc=0 channels=[email telegram webhook]" "$out"
# second call: rate limiter suppressed every channel -> no stub traffic at all
[ ! -e "$sb/curl.log" ] && echo "ok: burst: telegram+webhook suppressed" || {
  echo "FAIL: burst: stub curl traffic on second send"; fails=$((fails + 1))
}
[ ! -e "$sb/email.log" ] && echo "ok: burst: email suppressed" || {
  echo "FAIL: burst: email stub traffic on second send"; fails=$((fails + 1))
}
echo "ok: burst: second send suppressed on every channel"

[ "$fails" = 0 ] && echo "test-notify-seam: all pass" || {
  echo "test-notify-seam: $fails failure(s)"
  exit 1
}
