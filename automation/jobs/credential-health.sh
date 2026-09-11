#!/usr/bin/env bash
# credential-health — probe every credential the automation jobs rely on
# (unsloth session/refresh pair + each hngh reviewer transport) and file an
# hngh report ALERT for any that cannot be verified. Fail-closed: exits 0.
# A 401-bearing session token self-heals via the flocked refresh in
# lib/model.sh; a decayed refresh pair (or missing token) is a genuine
# credential failure and becomes an alert row in the hngh repo. Never log
# token VALUES, never widen a trust boundary, never mint a broader credential.
set -u
. "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"
. "$AUTOMATION_ROOT/lib/model.sh"
. "$AUTOMATION_ROOT/lib/notify.sh"

report_root="${HNGH_REPORT_ROOT:-$HNGH_HOME}" # hngh repo by default; overridable for tests
report_queue="python3 $HNGH_HOME/scripts/report-queue"

# file an alert row + body in the hngh report ledger and breadcrumb it.
alert() { # name failure -> 0
  local name="$1" failure="$2"
  HNGH_REPORT_ROOT="$report_root" $report_queue --add alert "credential $name: $failure" &&
    breadcrumb "$JOB_NAME" "alert" "credential $name: $failure"
}

# authenticated probe of the unsloth session token; echoes the http code.
probe_token() { # -> http code
  local tok
  tok="$(cat "$TOKEN_FILE" 2>/dev/null)" || {
    printf 'missing'
    return
  }
  [ -n "$tok" ] || {
    printf 'missing'
    return
  }
  curl -s --max-time 10 -o /dev/null -w '%{http_code}' \
    -H "Authorization: Bearer $tok" "$UNSLOTH_URL/v1/models" 2>/dev/null ||
    echo 000
}

ok() { printf '%s' "$1" | grep -Eq '^[23][0-9][0-9]$'; }

# --- 1. unsloth session token (rotates on 401 via the flocked refresh) ---
code="$(probe_token)"
if ok "$code"; then
  breadcrumb "$JOB_NAME" "credential-health" "unsloth session ok (http=$code)"
elif [ "$code" = "401" ] || [ "$code" = "403" ]; then
  if refresh_unsloth_token; then
    after="$(probe_token)"
    if ok "$after"; then
      breadcrumb "$JOB_NAME" "credential-health" "session token was expired; rotated ok (http=$after)"
    else
      alert "unsloth-token" "refreshed but still http=$after after rotate"
    fi
  else
    alert "unsloth-token" "401; refresh failed (refresh pair may be decayed)"
  fi
elif [ "$code" = "missing" ]; then
  alert "unsloth-token" "session token file missing ($TOKEN_FILE)"
elif [ "$code" = "000" ]; then
  breadcrumb "$JOB_NAME" "credential-health" "unsloth endpoint unreachable (http=$code); model server health is separate"
else
  alert "unsloth-token" "unexpected http=$code on session probe"
fi

# --- 2. reviewer transports (each conf points its token-file at the SAME pair) ---
for conf in "$HOME"/.hngh-automation/reviewer-*.conf; do
  [ -e "$conf" ] || continue
  name="$(basename "$conf" .conf)"
  python3 "$HNGH_HOME/scripts/probe-model-route" "$conf" >/dev/null 2>&1
  rc=$?
  if [ "$rc" = "0" ]; then
    breadcrumb "$JOB_NAME" "credential-health" "reviewer $name reachable"
  elif [ "$rc" = "2" ]; then
    alert "reviewer-$name" "malformed transport config (probe-model-route refused)"
  else
    alert "reviewer-$name" "endpoint not reachable (probe-model-route rc=$rc)"
  fi
done

# --- 3. deck model endpoint (cadence-params row `deck-model-endpoint`) ---
# Unconfigured = skip silently (the leg does not exist yet). Configured but
# not answering is a breadcrumb, not an alert: the deck is a wall-powered
# gaming device that may simply be off, and the model chain degrades to
# archive-only without it — nothing breaks.
deck_url="$(get_param deck-model-endpoint '')"
if [ -n "$deck_url" ]; then
  code="$(curl -s --max-time 10 -o /dev/null -w '%{http_code}' "$deck_url/health" 2>/dev/null)" || code=000
  if ok "$code"; then
    breadcrumb "$JOB_NAME" "credential-health" "deck model endpoint ok (http=$code)"
  else
    breadcrumb "$JOB_NAME" "credential-health" "deck endpoint $deck_url not answering (http=$code); device may be off"
  fi
fi

# --- 4. kimi leg (Moonshot platform; cadence-params rows
# `kimi-endpoint`/`kimi-model`) ---
# Every outcome is a breadcrumb, not
# an alert; the key VALUE is never read, logged, or sent on the wire. The
# probe reports WHICH source armed the leg (env name or key file), never
# the value. Unconfigured = silent (the leg does not exist yet).
kimi_key_src=""
[ -z "$kimi_key_src" ] && [ -n "${MOONSHOTAI_API_KEY:-}" ] && kimi_key_src="env MOONSHOTAI_API_KEY"
[ -z "$kimi_key_src" ] && [ -n "${KIMI_AI_KEY:-}" ] && kimi_key_src="env KIMI_AI_KEY"
[ -z "$kimi_key_src" ] && [ -n "${KIMI_FOR_CODING_KEY:-}" ] && kimi_key_src="env KIMI_FOR_CODING_KEY"
kimi_key_file="${KIMI_KEY_FILE:-$HOME/.config/hngh/kimi-key}"
[ -z "$kimi_key_src" ] && [ -f "$kimi_key_file" ] && kimi_key_src="key file"
if [ -n "$kimi_key_src" ]; then
  # probe with the SAME key resolution and endpoint kimi_chat uses - the
  # 2026-09-10 lesson: an unauthenticated GET read 401 for five days while
  # real kimi_chat calls succeeded (the probe measured its own missing
  # header, not the credential). Key values never logged.
  kimi_key=""
  [ -n "${MOONSHOTAI_API_KEY:-}" ] && kimi_key="$MOONSHOTAI_API_KEY"
  [ -z "$kimi_key" ] && [ -n "${KIMI_AI_KEY:-}" ] && kimi_key="$KIMI_AI_KEY"
  [ -z "$kimi_key" ] && [ -n "${KIMI_FOR_CODING_KEY:-}" ] && kimi_key="$KIMI_FOR_CODING_KEY"
  [ -z "$kimi_key" ] && [ -f "${KIMI_KEY_FILE:-$HOME/.config/hngh/kimi-key}" ] &&
    [ "$(stat -c %a "${KIMI_KEY_FILE:-$HOME/.config/hngh/kimi-key}")" = "600" ] &&
    kimi_key="$(cat "${KIMI_KEY_FILE:-$HOME/.config/hngh/kimi-key}" 2>/dev/null)"
  kimi_url="${KIMI_URL:-$(get_param kimi-endpoint 'https://api.kimi.com/coding/v1/chat/completions')}"
  kimi_models_url="${kimi_url%/chat/completions}/models"
  code="$(curl -s --max-time 10 -o /dev/null -w '%{http_code}' \
    -H "Authorization: Bearer $kimi_key" "$kimi_models_url" 2>/dev/null)" || code=000
  if [ "$code" = "000" ]; then
    breadcrumb "$JOB_NAME" "credential-health" "kimi ($kimi_key_src) endpoint not answering (http=$code)"
  elif [ "$code" = "401" ] || [ "$code" = "403" ]; then
    breadcrumb "$JOB_NAME" "credential-health" "kimi ($kimi_key_src) rejected by endpoint (http=$code) - credential failure, operator attention"
  else
    breadcrumb "$JOB_NAME" "credential-health" "kimi ($kimi_key_src) ok; models endpoint http=$code; gated on kimi-model row"
  fi
fi

# --- 5. opencode-go leg (opencode.ai/zen/go/v1; cadence-params rows
# `opencode-url`/`opencode-model`; docs/OPENCODE-GO.md) ---
# Same philosophy as the kimi probe: every outcome is a breadcrumb,
# not an alert; the key VALUE is never logged or sent on the wire. The probe
# exercises the SAME authenticated path ocgo_chat uses (Bearer header; the
# 2026-09-10 lesson: a headerless probe measures only its own missing
# header). Unconfigured = silent (the leg does not exist yet).
ocgo_key_src=""
[ -n "${OPENCODE_API_KEY:-}" ] && ocgo_key_src="env OPENCODE_API_KEY"
ocgo_key_file="${OPENCODE_KEY_FILE:-$HOME/.config/hngh/opencode-key}"
[ -z "$ocgo_key_src" ] && [ -f "$ocgo_key_file" ] && ocgo_key_src="key file"
if [ -n "$ocgo_key_src" ]; then
  ocgo_key=""
  [ -n "${OPENCODE_API_KEY:-}" ] && ocgo_key="$OPENCODE_API_KEY"
  [ -z "$ocgo_key" ] && [ -f "${OPENCODE_KEY_FILE:-$HOME/.config/hngh/opencode-key}" ] &&
    [ "$(stat -c %a "${OPENCODE_KEY_FILE:-$HOME/.config/hngh/opencode-key}")" = "600" ] &&
    ocgo_key="$(cat "${OPENCODE_KEY_FILE:-$HOME/.config/hngh/opencode-key}" 2>/dev/null)"
  ocgo_url="${OCGO_URL:-$(get_param opencode-url 'https://opencode.ai/zen/go/v1/chat/completions')}"
  ocgo_models_url="${ocgo_url%/chat/completions}/models"
  code="$(curl -s --max-time 10 -o /dev/null -w '%{http_code}' \
    -H "Authorization: Bearer $ocgo_key" "$ocgo_models_url" 2>/dev/null)" || code=000
  if [ "$code" = "000" ]; then
    breadcrumb "$JOB_NAME" "credential-health" "ocgo ($ocgo_key_src) endpoint not answering (http=$code)"
  elif [ "$code" = "401" ] || [ "$code" = "403" ]; then
    breadcrumb "$JOB_NAME" "credential-health" "ocgo ($ocgo_key_src) rejected by endpoint (http=$code) - credential failure, operator attention"
  else
    breadcrumb "$JOB_NAME" "credential-health" "ocgo ($ocgo_key_src) ok; models endpoint http=$code; gated on opencode-model row"
  fi
fi

# --- 6. notify seam (lib/notify.sh) ---
# Presence-only: reports WHICH channels are armed (names only — token/url
# VALUES are never read, logged, or sent). Dormant = silent (no channels
# armed yet is the normal operator setup state, not an alert).
armed="$(notify_channels)"
if [ -n "$armed" ]; then
  breadcrumb "$JOB_NAME" "credential-health" "notify seam armed: $armed"
fi

exit 0
