# notify-email.sh — optional email side-channel for alert rows.
# The report-queue row is the contract; email is convenience. The row is
# ALWAYS written. Email goes out immediately only for IMMEDIATE-class
# alerts (classify_alert rubric in scripts/notify-email.py: park/
# critical, service-ctl, serving down/recovered, agent-stall, git-push
# failures, credential/config touches, ceremony/verdict failures,
# kernel tree-skew, budget cap) — everything else defers to the daily
# digest so routine noise never spams the inbox. When notify-email.conf
# exists immediate alerts are relayed through scripts/notify-email.py
# (timeout-capped, best-effort); when it is absent the channel is
# silently dormant (one breadcrumb per UTC day max — missing creds are
# an operator setup item, never an alert).
# Requires lib/common.sh + lib/breadcrumbs.sh sourced first.
KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
EMAIL_NOTIFY="$AUTOMATION_ROOT/scripts/notify-email.py"
EMAIL_LOG="${HNGH_NOTIFY_EMAIL_LOG:-$AUTOMATION_ROOT/logs/notify-email.log}"

email_conf_path() { # -> config path (env seam wins, for tests)
  printf '%s' "${HNGH_NOTIFY_EMAIL_CONF:-$HOME/.hngh-automation/notify-email.conf}"
}

email_dormant_crumb() { # at most one breadcrumb per UTC day
  local stamp="$AUTOMATION_ROOT/logs/.email-dormant-$(date -u +%F)"
  [ -e "$stamp" ] && return 0
  : >"$stamp" 2>/dev/null || return 0
  breadcrumb "$JOB_NAME" "notify-email" "config absent — email channel dormant"
}

email_sidechannel() { # subject body -> 0 always
  local subject="$1" body="$2" conf tmp out rc
  conf="$(email_conf_path)"
  [ -f "$conf" ] || {
    email_dormant_crumb
    return 0
  }
  tmp="$(mktemp)"
  printf '%s' "$body" >"$tmp"
  out="$(timeout 45 python3 "$EMAIL_NOTIFY" send --subject "$subject" \
    --body-file "$tmp" 2>&1)"
  rc=$?
  rm -f "$tmp"
  if [ "$rc" != "0" ]; then
    printf '%s | send failed rc=%d: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      "$rc" "$out" >>"$EMAIL_LOG" 2>/dev/null || true
  fi
  return 0
}

alert_row() { # identity window subject text — row first (the contract),
  # then the importance classification; only immediate-class alerts
  # trigger the email side-channel. A mail failure never fails the row.
  HNGH_REPORT_ROOT="${HNGH_REPORT_ROOT:-$KERNEL}" python3 \
    "$KERNEL/scripts/report-queue" --add alert "$4" \
    --identity "$1" --window "$2" >/dev/null 2>&1 || true
  if [ ! -f "$(email_conf_path)" ]; then
    email_dormant_crumb
    return 0
  fi
  cls="$(timeout 10 python3 "$EMAIL_NOTIFY" classify --text "$4" \
    2>/dev/null || printf 'digest')"
  [ "$cls" = "immediate" ] && email_sidechannel "$3" "$4"
  return 0
}
