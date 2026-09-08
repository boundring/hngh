# notify.sh — channel-agnostic notification seam (email / telegram / webhook).
# notify_event <class> <subject> <body-or-file>
#
# Channels (each armed independently; all fail-closed, notify_event always
# exits 0):
#   email    — armed when the notify-email conf exists (env
#              HNGH_NOTIFY_EMAIL_CONF or ~/.hngh-automation/notify-email.conf);
#              shells out to scripts/notify-email.py send exactly the way
#              cadence/day/09-email-digest.sh does. Absent conf -> silent.
#   telegram — armed when TELEGRAM_BOT_TOKEN+TELEGRAM_CHAT_ID are set (env) OR
#              ~/.config/hngh/telegram-notify.env (mode 600, KEY=VALUE lines)
#              parses. POSTs to api.telegram.org sendMessage.
#   webhook  — armed when HNGH_WEBHOOK_URL is set OR
#              ~/.config/hngh/webhook-notify.env carries WEBHOOK_URL=.
#              POSTs {"class","subject","body","ts"} as JSON.
#
# Rate/burst: per-channel 60s minimum between sends (stamp files under
# ${HNGH_NOTIFY_STAMP_DIR:-/tmp/hngh-notify-stamps}; HNGH_NOTIFY_MIN_INTERVAL
# overrides the window) so a burst of events cannot flood the phone. A
# suppressed send is silent, exit 0, not an error. Failed sends are a
# breadcrumb + exit 0 — never retried in-function, never an error.
#
# KEY RULE: token/url VALUES are never logged, echoed, or tested. Presence
# checks and source names only (env NAME or "key file").
#
# Requires lib/common.sh + lib/breadcrumbs.sh sourced first.

HNGH_NOTIFY_MIN_INTERVAL="${HNGH_NOTIFY_MIN_INTERVAL:-60}"
HNGH_NOTIFY_STAMP_DIR="${HNGH_NOTIFY_STAMP_DIR:-/tmp/hngh-notify-stamps}"
HNGH_TELEGRAM_NOTIFY_FILE="${HNGH_TELEGRAM_NOTIFY_FILE:-$HOME/.config/hngh/telegram-notify.env}"
HNGH_WEBHOOK_NOTIFY_FILE="${HNGH_WEBHOOK_NOTIFY_FILE:-$HOME/.config/hngh/webhook-notify.env}"

notify_email_conf() { printf '%s' "${HNGH_NOTIFY_EMAIL_CONF:-$HOME/.hngh-automation/notify-email.conf}"; }

# parse one KEY=VALUE from a mode-600 key file; prints value, never logs it.
_notify_kv() { # file key -> value|"" ("" also when perms too open)
  local file="$1" key="$2" perms
  [ -f "$file" ] || return 0
  perms=$(stat -c '%a' "$file" 2>/dev/null) || return 0
  [ "$perms" = "600" ] || return 0
  grep -E "^${key}=" "$file" 2>/dev/null | head -n 1 | cut -d= -f2-
}

_notify_rate_ok() { # channel -> 0 if allowed (and stamps), 1 if suppressed
  mkdir -p "$HNGH_NOTIFY_STAMP_DIR" 2>/dev/null || return 0
  local stamp="$HNGH_NOTIFY_STAMP_DIR/$1" now last
  now=$(date +%s)
  last=$(cat "$stamp" 2>/dev/null || printf '0')
  if [ $((now - last)) -lt "$HNGH_NOTIFY_MIN_INTERVAL" ]; then return 1; fi
  printf '%s' "$now" >"$stamp" 2>/dev/null || true
  return 0
}

notify_channels() { # -> space-separated names of armed channels (names only)
  local armed="" v
  [ -f "$(notify_email_conf)" ] && armed="email"
  if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
    armed="$armed telegram"
  elif [ -n "$(_notify_kv "$HNGH_TELEGRAM_NOTIFY_FILE" TELEGRAM_BOT_TOKEN)" ] &&
    [ -n "$(_notify_kv "$HNGH_TELEGRAM_NOTIFY_FILE" TELEGRAM_CHAT_ID)" ]; then
    armed="$armed telegram"
  fi
  if [ -n "${HNGH_WEBHOOK_URL:-}" ]; then
    armed="$armed webhook"
  elif [ -n "$(_notify_kv "$HNGH_WEBHOOK_NOTIFY_FILE" WEBHOOK_URL)" ]; then
    armed="$armed webhook"
  fi
  printf '%s' "${armed# }"
}

_notify_send_email() { # subject body-file -> 0
  local out rc
  out="$(timeout 45 python3 "$AUTOMATION_ROOT/scripts/notify-email.py" send \
    --subject "$1" --body-file "$2" 2>&1)"
  rc=$?
  if [ "$rc" != "0" ]; then
    breadcrumb "$JOB_NAME" "notify-seam" "email send failed rc=$rc"
  fi
  return 0
}

_notify_send_telegram() { # subject body -> 0
  local token chat_id code
  if [ -n "${TELEGRAM_BOT_TOKEN:-}" ]; then token="$TELEGRAM_BOT_TOKEN"; else token="$(_notify_kv "$HNGH_TELEGRAM_NOTIFY_FILE" TELEGRAM_BOT_TOKEN)"; fi
  if [ -n "${TELEGRAM_CHAT_ID:-}" ]; then chat_id="$TELEGRAM_CHAT_ID"; else chat_id="$(_notify_kv "$HNGH_TELEGRAM_NOTIFY_FILE" TELEGRAM_CHAT_ID)"; fi
  code="$(curl -s --max-time 20 -o /dev/null -w '%{http_code}' \
    --data-urlencode "chat_id=$chat_id" \
    --data-urlencode "text=$1
$2" \
    "https://api.telegram.org/bot${token}/sendMessage" 2>/dev/null)" || code=000
  [ "$code" = "200" ] || breadcrumb "$JOB_NAME" "notify-seam" \
    "telegram-notify failed: HTTP $code"
  return 0
}

_notify_send_webhook() { # class subject body -> 0
  local url code
  if [ -n "${HNGH_WEBHOOK_URL:-}" ]; then url="$HNGH_WEBHOOK_URL"; else url="$(_notify_kv "$HNGH_WEBHOOK_NOTIFY_FILE" WEBHOOK_URL)"; fi
  code="$(curl -s --max-time 20 -o /dev/null -w '%{http_code}' \
    -H 'Content-Type: application/json' \
    --data "$(python3 -c 'import json,sys;print(json.dumps({"class":sys.argv[1],"subject":sys.argv[2],"body":sys.argv[3],"ts":int(__import__("time").time())}))' "$1" "$2" "$3")" \
    "$url" 2>/dev/null)" || code=000
  [ "$code" = "200" ] || breadcrumb "$JOB_NAME" "notify-seam" \
    "webhook-notify failed: HTTP $code"
  return 0
}

notify_event() { # class subject body-or-file -> 0 always
  local class="$1" subject="$2" bodyarg="$3" body armed
  if [ -f "$bodyarg" ]; then body="$(cat "$bodyarg")"; else body="$bodyarg"; fi
  armed="$(notify_channels)"
  case "$armed" in
  *email*) _notify_rate_ok email && {
    local tmp
    tmp="$(mktemp)"
    printf '%s' "$body" >"$tmp"
    _notify_send_email "$subject" "$tmp"
    rm -f "$tmp"
  } ;;
  esac
  case "$armed" in
  *telegram*) _notify_rate_ok telegram && _notify_send_telegram "$subject" "$body" ;;
  esac
  case "$armed" in
  *webhook*) _notify_rate_ok webhook && _notify_send_webhook "$class" "$subject" "$body" ;;
  esac
  return 0
}
