# model.sh — model-call with fail-closed fallback chain.
#   model_call [MAX_TOKENS]   <- stdin prompt
#   echoes the completion text (EMPTY output only in archive-only mode);
#   writes $MODEL_USED to $AUTOMATION_ROOT/tmp-modelused.txt so callers can
#   read it from OUTSIDE the command-substitution subshell.
# Chain: unsloth (401 auto-refresh + empty-content retry) -> zai (Z.AI
# subscription quota leg, 5h + weekly paced, see zai_chat) -> remote
# (budget-gated, see remote_chat) -> ollama -> deck (param-gated, see
# deck_chat) -> kimi (quota leg, see kimi_chat) -> ocgo (quota leg,
# OpenCode Go, every-window paced, see ocgo_chat) -> archive-only.
# MODEL_PIN routes a call:
#   local  unsloth -> ollama only (remote, deck, and the quota legs kimi/
#          ocgo are skipped): news/ux-review/bench pin local
#          (low-stakes or probing local models).
#   ocgo   ocgo first (OpenCode Go GLM quota, 5h-window paced), then
#          unsloth -> ollama -> deck -> archive; remote + kimi
#          skipped. Research volume rotates onto it
#          (opencode-research-share).
#   kimi   kimi first (K3 quota primary), then unsloth -> ollama ->
#          deck -> archive; remote skipped. Intelligence-shaped
#          bounded work (research transitions, fresh-eyes review) rotates
#          onto the quota here, spread across the window by
#          quota_pace_blocked + kimi-daily-cap.
#   deck   deck first (second-server overflow), then unsloth -> ollama ->
#          kimi -> archive; remote skipped.
#   zai    zai first (Z.AI subscription, 5h + weekly paced), then
#          unsloth -> ollama -> deck -> archive; remote + kimi skipped.
#   review deck -> kimi -> zai -> ocgo first (the current quota ladder),
#          then unsloth -> ollama -> archive; remote skipped. The
#          fresh-eyes review (04-review-prep) and the digest model leg
#          (morning-digest) ride this lane: quota legs first, the local
#          bench LAST resort (2026-09-09 evidence: the old kimi pin fell
#          through to the unsloth bench and REVIEW-2026-09-09.md recorded
#          a bench non-review).
#   remote remote first (openrouter, budget-gated) with the model from
#          REMOTE_MODEL_CODING / cadence-params `remote-model-coding`
#          (task-class route: coding completions that generate whole
#          files or patches, per the operator's 2026-09-13 benchmark
#          priorities), then unsloth -> ollama -> deck -> archive;
#          kimi/ocgo skipped. A miss (no key file, cap, 429) falls
#          through to the local chain.
#   feedback remote first (openrouter, budget-gated) with the model from
#          REMOTE_MODEL_FEEDBACK / cadence-params `remote-model-feedback`
#          (design-feedback/coverage second opinions on design docs and
#          plans; the contributor-priced Muse Spark legs, per the
#          operator's 2026-09-13 addendum -- $0.10/$0.20 per 1M in/out),
#          then unsloth -> ollama -> deck -> archive; kimi/ocgo skipped.
#   other  ignored: the full chain runs.
# A pinned quota leg that misses (pace-block, 429, endpoint down) falls
# through to the local chain inside model_call -- research/reviews never
# block on quota state. Delegated-session spend is governed separately by
# the session caps; remote/openrouter stays budget-gated last-resort for
# sessions only.
# Every step exits 0 unless a genuine local bug (missing python3, etc.).
. "$AUTOMATION_ROOT/lib/common.sh"

# telemetry db: userspace home (layout contract 2026-09-13);
# HNGH_TELEMETRY_DB overrides for hermetic tests.
HNGH_TELEMETRY_DB="${HNGH_TELEMETRY_DB:-${HNGH_HOME_DIR:-$HOME/.hngh}/db/telemetry.db}"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"
. "$AUTOMATION_ROOT/lib/params.sh"

MODEL_USED=""
MODEL_USED_FILE="$AUTOMATION_ROOT/tmp-modelused.txt"
POST_CODE_FILE="$AUTOMATION_ROOT/tmp-postcode.txt"
# same subshell-escape reason as POST_CODE_FILE: the chat helpers run inside
# the caller's command substitution, so the measured wall time (curl
# %{time_total}, seconds) and any usage tokens the provider returned travel
# to _model_emit through files. Empty/absent = not measured -> NULL row.
WALL_S_FILE="$AUTOMATION_ROOT/tmp-walls.txt"
TOKIN_FILE="$AUTOMATION_ROOT/tmp-tokensin.txt"
TOKOUT_FILE="$AUTOMATION_ROOT/tmp-tokensout.txt"
# finish_reason=length flag (file, not var: same subshell-escape reason).
# "1" = the returned completion was cut at the max_tokens cap; empty =
# clean stop. Callers mark the doc instead of writing a silently
# mid-syntax capture (2026-09-11 research-beat corpus loss).
MODEL_TRUNC_FILE="$AUTOMATION_ROOT/tmp-modeltrunc.txt"

last_model_used() {
 cat "$MODEL_USED_FILE" 2>/dev/null || true
}

last_model_truncated() {
 cat "$MODEL_TRUNC_FILE" 2>/dev/null || true
}

# _mark_trunc tmp -- record whether a raw response file ended in
# finish_reason=length (overwrites any stale flag on every attempt).
_mark_trunc() { # tmp
 if jq -r '.choices[0].finish_reason // ""' "$1" 2>/dev/null | grep -qx length; then
  printf '1' >"$MODEL_TRUNC_FILE"
 else
  printf '' >"$MODEL_TRUNC_FILE"
 fi
}

# _post_chat URL JQ_EXPR [BEARER_KEY] — the shared POST+parse scaffold for
# the chat legs (ollama, remote, deck, kimi, ocgo): JSON body on stdin,
# curl POST with content-type + optional bearer header, %{http_code}
# capture, jq parse of the completion, tmp cleanup. Prints the completion
# and returns 0 on HTTP 200 + nonempty content; else returns 1. The http
# code (000 on transport failure) goes to $POST_CODE_FILE — a file, not a
# variable, because the helper runs inside the caller's command-substitution
# subshell (same reason MODEL_USED goes through tmp-modelused.txt).
_post_chat() { # url jq_expr [bearer] [session_hdr] [noproxy_host] [cacert] -> content on stdout; code in $POST_CODE_FILE,
 # wall seconds in $WALL_S_FILE, usage tokens (chat-completions
 # .usage.prompt_tokens/completion_tokens or Responses
 # .usage.input_tokens/output_tokens) in $TOKIN/$TOKOUT files
 local url="$1" expr="$2" auth="${3:-}" session="${4:-}" noproxy="${5:-}" cacert="${6:-}" tmp code content
 local raw t tin tout
 tmp="$(mktemp)"
 raw="$(curl -s --max-time "$MODEL_TIMEOUT" ${noproxy:+--noproxy "$noproxy"} \
  ${cacert:+--cacert "$cacert"} -X POST \
  -H "Content-Type: application/json" \
  ${auth:+-H "Authorization: Bearer $auth"} \
  ${session:+-H "x-opencode-session: $session"} \
  -d @- -w '%{http_code} %{time_total}' -o "$tmp" "$url" 2>/dev/null)" || raw="000 0"
 case "$raw" in
 *' '*)
  code="${raw%% *}"
  t="${raw#* }"
  ;;
 *)
  code="$raw"
  t=0
  ;;
 esac
 printf '%s' "$t" >"$WALL_S_FILE" 2>/dev/null
 tin="$(jq -r '.usage.prompt_tokens // .usage.input_tokens // empty' "$tmp" 2>/dev/null)"
 printf '%s' "${tin:-}" >"$TOKIN_FILE" 2>/dev/null
 tout="$(jq -r '.usage.completion_tokens // .usage.output_tokens // empty' "$tmp" 2>/dev/null)"
 printf '%s' "${tout:-}" >"$TOKOUT_FILE" 2>/dev/null
 printf '%s' "$code" >"$POST_CODE_FILE"
 content=""
 [ "$code" = "200" ] && content="$(jq -r "$expr" "$tmp" 2>/dev/null || true)"
 _mark_trunc "$tmp"
 rm -f "$tmp"
 [ -n "$content" ] || return 1
 printf '%s\n' "$content"
}

# build a chat-completions JSON body safely (python3, no shell quoting games).
# thinking=1 leaves Qwen thinking enabled; thinking=0 sends enable_thinking:false
# (harmless if the server ignores it — gets Qwen models to skip the reasoning
# stage that otherwise eats the token budget).
_json_body() { # model prompt max_tokens ollama(0|1) thinking(0|1) -> stdout
 python3 - "$1" "$2" "$3" "$4" "$5" <<'PY'
import json, sys
model, prompt, maxtok, ollama, thinking = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4] == "1", sys.argv[5] == "1"
msg = {"role": "user", "content": prompt}
if ollama:
    body = {"model": model, "messages": [msg], "stream": False, "options": {"num_predict": maxtok}}
    if not thinking:
        body["think"] = False
else:
    body = {"model": model, "messages": [msg], "max_tokens": maxtok, "temperature": 0.3}
    if not thinking:
        body["chat_template_kwargs"] = {"enable_thinking": False}
print(json.dumps(body))
PY
}

# refresh single-use token pair from Unsloth; writes new pair (mode 600).
# Serialized by flock: the refresh token is SINGLE-USE server-side (rotated on
# each successful refresh), so concurrent refreshes from sibling jobs must not
# race — the loser would POST the already-consumed token and get a false 401.
# The token is re-read INSIDE the lock so the winner's new pair is observed.
refresh_unsloth_token() {
 local rtok tmp code lock
 lock="$(dirname "$REFRESH_FILE")/refresh.lock"
 mkdir -p "$(dirname "$REFRESH_FILE")"
 exec 9>"$lock"
 flock -w 30 9 || {
  breadcrumb model "token-refresh" "could not acquire $lock within 30s"
  return 1
 }
 # read INSIDE the lock: a concurrent winner may have rotated the pair already
 rtok="$(cat "$REFRESH_FILE" 2>/dev/null)" || {
  breadcrumb model "refresh" "no refresh token file ($REFRESH_FILE)"
  return 1
 }
 tmp="$(mktemp)"
 code="$(curl -s --max-time 30 -X POST -H "Content-Type: application/json" \
  -d "{\"refresh_token\":\"$rtok\"}" -w '%{http_code}' -o "$tmp" \
  "$UNSLOTH_URL/api/auth/refresh" 2>/dev/null)" || code=000
 if [ "$code" = "200" ] && jq -e '.access_token and .refresh_token' "$tmp" >/dev/null 2>&1; then
  jq -r '.access_token' "$tmp" >"$TOKEN_FILE"
  jq -r '.refresh_token' "$tmp" >"$REFRESH_FILE"
  chmod 600 "$TOKEN_FILE" "$REFRESH_FILE"
  rm -f "$tmp"
  breadcrumb model "token-refresh" "ok (new single-use pair written)"
  return 0
 fi
 breadcrumb model "token-refresh" "FAILED http=$code — refresh tokens are single-use; operator may need a fresh pair"
 rm -f "$tmp"
 return 1
}

# one raw Unsloth attempt writing the response into $tmp; echoes the http code.
unsloth_attempt() { # tmp model prompt max_tokens thinking token -> http code
 local tmp="$1" model="$2" prompt="$3" maxtok="$4" thinking="$5" tok="$6" code raw t tin tout
 raw="$(printf '%s' "$(_json_body "$model" "$prompt" "$maxtok" 0 "$thinking")" |
  curl -s --max-time "$MODEL_TIMEOUT" \
   -H "Authorization: Bearer $tok" -H "Content-Type: application/json" \
   -d @- -w '%{http_code} %{time_total}' -o "$tmp" "$UNSLOTH_URL/v1/chat/completions" \
   2>/dev/null)" || raw="000 0"
 case "$raw" in
 *' '*)
  code="${raw%% *}"
  t="${raw#* }"
  ;;
 *)
  code="$raw"
  t=0
  ;;
 esac
 printf '%s' "$t" >"$WALL_S_FILE" 2>/dev/null
 tin="$(jq -r '.usage.prompt_tokens // .usage.input_tokens // empty' "$tmp" 2>/dev/null)"
 printf '%s' "${tin:-}" >"$TOKIN_FILE" 2>/dev/null
 tout="$(jq -r '.usage.completion_tokens // .usage.output_tokens // empty' "$tmp" 2>/dev/null)"
 printf '%s' "${tout:-}" >"$TOKOUT_FILE" 2>/dev/null
 printf '%s' "$code"
}

# the llama-server auto-sizes its context window from free VRAM; ask the
# webapp for the ACTIVE window (cached ~10 min so we don't probe every call).
# Unreachable/unknown -> empty (guard disabled; the call itself fails as today).
_unsloth_ctx_limit() { # token -> context_length or empty
 local cache="$AUTOMATION_ROOT/tmp-unsloth-ctx.txt" v
 if [ -f "$cache" ] && [ -n "$(find "$cache" -mmin -10 2>/dev/null)" ]; then
  cat "$cache"
  return 0
 fi
 v="$(curl -s --max-time 5 -H "Authorization: Bearer $1" \
  "$UNSLOTH_URL/api/inference/status" 2>/dev/null |
  jq -r '.context_length // empty' 2>/dev/null)"
 case "$v" in '' | *[!0-9]*) return 0 ;; esac
 printf '%s' "$v" >"$cache"
 printf '%s' "$v"
}

# chat via Unsloth. Handles: 401 -> refresh once & retry; 200+empty content ->
# retry once with budget*8 and thinking disabled, then reasoning_content as last resort.
unsloth_chat() {
 local prompt="$1" max_tokens="$2" model="$3"
 local refreshed="${4:-0}" tok code content reasoning big tmp
 tok="$(cat "$TOKEN_FILE" 2>/dev/null)" || {
  breadcrumb model "unsloth" "no token file -> next backend"
  return 1
 }

 # context guard: skip this leg when the prompt cannot fit the server's
 # ACTIVE window (est = word count * 1.3, capped at 90% of the window).
 local ctx est
 ctx="$(_unsloth_ctx_limit "$tok")"
 if [ -n "$ctx" ]; then
  est=$(($(printf '%s' "$prompt" | wc -w) * 13 / 10))
  if [ "$est" -gt $((ctx * 9 / 10)) ]; then
   breadcrumb model "unsloth" "prompt ~$est tokens exceeds server window $ctx -> next backend"
   return 1
  fi
 fi

 # --- phase A: default budget, thinking enabled ---
 tmp="$(mktemp)"
 code="$(unsloth_attempt "$tmp" "$model" "$prompt" "$max_tokens" 1 "$tok")"
 if [ "$code" = "401" ] && [ "$refreshed" = "0" ]; then
  rm -f "$tmp"
  if refresh_unsloth_token; then
   tok="$(cat "$TOKEN_FILE")"
   tmp="$(mktemp)"
   breadcrumb model "unsloth" "token refreshed; retrying once"
   code="$(unsloth_attempt "$tmp" "$model" "$prompt" "$max_tokens" 1 "$tok")"
  fi
 fi

 if [ "$code" = "200" ]; then
  if jq -e '.choices[0].message.content // ""' "$tmp" >/dev/null 2>&1; then
   content="$(jq -r '.choices[0].message.content // ""' "$tmp")"
   if [ -n "$content" ]; then
    _mark_trunc "$tmp"
    rm -f "$tmp"
    printf '%s\n' "$content"
    return 0
   fi
   # empty content: reasoning ate the budget -> retry once, big budget, thinking off
   big=$((max_tokens * 8))
   [ "$big" -lt 512 ] && big=512
   rm -f "$tmp"
   tmp="$(mktemp)"
   breadcrumb model "unsloth" "empty content; retrying budget=$big thinking=off"
   code="$(unsloth_attempt "$tmp" "$model" "$prompt" "$big" 0 "$tok")"
   if [ "$code" = "200" ] && jq -e '.choices[0].message.content // ""' "$tmp" >/dev/null 2>&1; then
    content="$(jq -r '.choices[0].message.content // ""' "$tmp")"
    if [ -n "$content" ]; then
     _mark_trunc "$tmp"
     rm -f "$tmp"
     printf '%s\n' "$content"
     return 0
    fi
   fi
   # last resort: extract the reasoning the model did produce
   if jq -e '.choices[0].message.reasoning_content // ""' "$tmp" >/dev/null 2>&1; then
    reasoning="$(jq -r '.choices[0].message.reasoning_content // ""' "$tmp")"
    if [ -n "$reasoning" ]; then
     rm -f "$tmp"
     breadcrumb model "unsloth" "only reasoning_content available; using it as answer"
     printf '%s\n' "$reasoning"
     return 0
    fi
   fi
  fi
  rm -f "$tmp"
  breadcrumb model "unsloth" "no usable content after retry -> next backend"
  return 1
 fi

 rm -f "$tmp"
 breadcrumb model "unsloth" "HTTP $code -> next backend"
 return 1
}

# chat via ollama (gemma fallback); stream:false; long timeout for cold 12B load.
ollama_chat() {
 local prompt="$1" max_tokens="$2" content
 content="$(printf '%s' "$(_json_body "$OLLAMA_MODEL" "$prompt" "$max_tokens" 1 0)" |
  _post_chat "$OLLAMA_URL/api/chat" '.message.content // empty')" || {
  breadcrumb model "ollama" "HTTP $(cat "$POST_CODE_FILE" 2>/dev/null) -> archive-only"
  return 1
 }
 printf '%s\n' "$content"
 return 0
}

# chat via the remote OpenAI-compatible endpoint (OpenRouter by default;
# REMOTE_URL/REMOTE_MODEL are the reconfig point). The key file gates the
# leg: absent -> dormant. Spend guard: remote calls are counted per UTC
# day in telemetry (kind=model, source=remote) against REMOTE_DAILY_CAP_CALLS.
remote_chat() {
 local prompt="$1" max_tokens="$2" key content count
 key="$(cat "$REMOTE_TOKEN_FILE" 2>/dev/null)" || {
  breadcrumb model "remote" "no key file -> next backend"
  return 1
 }
 count="$(sqlite3 "$HNGH_TELEMETRY_DB" \
  "select count(*) from events where kind='model' and source='remote' and ts like '$(date -u +%Y-%m-%d)%'" 2>/dev/null)"
 case "$count" in '' | *[!0-9]*) count=0 ;; esac
 [ "$count" -ge "${REMOTE_DAILY_CAP_CALLS:-200}" ] && {
  breadcrumb model "remote" "daily cap reached -> next backend"
  return 1
 }
 content="$(printf '%s' "$(_json_body "$REMOTE_MODEL" "$prompt" "$max_tokens" 0 0)" |
  _post_chat "$REMOTE_URL/chat/completions" '.choices[0].message.content // ""' "$key")" || {
  breadcrumb model "remote" "HTTP $(cat "$POST_CODE_FILE" 2>/dev/null) -> next backend"
  return 1
 }
 printf '%s\n' "$content"
}

# archive-only mode: store the raw prompt so nothing is lost; success = empty.
archive_only() {
 local prompt="$1"
 local f="$AUTOMATION_ROOT/archive/skipped-$(date -u +%Y%m%d-%H%M%S).txt"
 printf '%s\n' "$prompt" >"$f"
 breadcrumb model "archive-only" "no model reachable; raw prompt saved to archive/$(basename "$f")"
 return 0
}

# chat via the deck's llama.cpp/vulkan endpoint over tailscale (OpenAI-
# compatible /v1/chat/completions). The cadence-params row
# `deck-model-endpoint` gates the leg: empty or absent -> the leg is
# skipped silently (fail-closed-skip; DECK_URL env overrides the row).
# DECK_MODEL names the --alias the deck server was started with.
deck_chat() { # prompt max_tokens -> completion on stdout; 1 = skip/fail
 local prompt="$1" max_tokens="$2" url model content
 url="${DECK_URL:-$(get_param deck-model-endpoint '')}"
 [ -n "$url" ] || return 1
 model="${DECK_MODEL:-deck}"
 content="$(printf '%s' "$(_json_body "$model" "$prompt" "$max_tokens" 0 0)" |
  _post_chat "$url/v1/chat/completions" '.choices[0].message.content // ""')" || {
  breadcrumb model "deck" "HTTP $(cat "$POST_CODE_FILE" 2>/dev/null) -> next backend"
  return 1
 }
 printf '%s\n' "$content"
}

# Quota-window pacing for the paid legs (kimi). Counts today's
# telemetry events (kind=model source=<source>, the same query remote_chat
# uses) and blocks when the day is being spent faster than an even pace:
# used >= cap (hard cap) OR used > cap*elapsed/86400 + 1 (soft pace, one
# call of grace). This spreads the daily cap across the UTC window instead
# of front-loading it at midnight. Prints "<used> <cap>" when blocked (for
# the caller's breadcrumb); exit 0 = blocked, 1 = go.
quota_pace_blocked() { # source cap -> 0 blocked (prints "used cap"), 1 go
 local src="$1" cap="$2" used elapsed allowed
 case "$cap" in '' | *[!0-9]*) return 1 ;; esac # bad cap: fail open
 used="$(sqlite3 "$HNGH_TELEMETRY_DB" \
  "select count(*) from events where kind='model' and source='$src' and ts like '$(date -u +%Y-%m-%d)%'" 2>/dev/null)"
 case "$used" in '' | *[!0-9]*) used=0 ;; esac
 [ "$used" -ge "$cap" ] && {
  printf '%s %s\n' "$used" "$cap"
  return 0
 }
 elapsed=$((10#$(date -u +%H) * 3600 + 10#$(date -u +%M) * 60 + 10#$(date -u +%S)))
 allowed="$(awk -v c="$cap" -v e="$elapsed" 'BEGIN{printf "%.4f", c*e/86400}')"
 if awk -v u="$used" -v a="$allowed" 'BEGIN{exit !(u > a + 1)}'; then
  printf '%s %s\n' "$used" "$cap"
  return 0
 fi
 return 1
}

# 5h rolling-window pacer for the OpenCode Go leg (R3 tightest-window rule:
# pace the 5h/$12 bucket, never dump it). Same shape as quota_pace_blocked
# but the window is the trailing 5 hours, not the UTC day: used = ocgo model
# events with ts >= now-5h; blocked when used >= cap (hard) OR used >
# cap*elapsed/18000 + 1 (soft pace, one call of grace), elapsed = seconds
# into the current UTC-aligned 5h grid window (epoch floored to 18000s --
# the subscription's true reset origin is operator-side and unknowable
# here; grid alignment just spreads spend, which is the point).
# Prints "<used> <cap>" when blocked; exit 0 = blocked, 1 = go.
quota_pace_blocked_5h() { # source[,source...] cap -> 0 blocked (prints "used cap"), 1 go
 local src="$1" cap="$2" used elapsed allowed
 case "$cap" in '' | *[!0-9]*) return 1 ;; esac # bad cap: fail open
 used="$(sqlite3 "$HNGH_TELEMETRY_DB" \
  "select count(*) from events where kind='model' and source in ('${src//,/\',\'}') \
     and ts >= strftime('%Y-%m-%dT%H:%M:%SZ','now','-5 hours')" 2>/dev/null)"
 case "$used" in '' | *[!0-9]*) used=0 ;; esac
 [ "$used" -ge "$cap" ] && {
  printf '%s %s\n' "$used" "$cap"
  return 0
 }
 elapsed=$(($(date -u +%s) % 18000))
 allowed="$(awk -v c="$cap" -v e="$elapsed" 'BEGIN{printf "%.4f", c*e/18000}')"
 if awk -v u="$used" -v a="$allowed" 'BEGIN{exit !(u > a + 1)}'; then
  printf '%s %s\n' "$used" "$cap"
  return 0
 fi
 return 1
}

# Multi-window pacing (quota-tightest-window-pacing, tightened
# 2026-09-13): a product with several reset windows must gate EVERY
# window BEFORE a call lands; the tightest window decides. The generic
# window pacer is quota_pace_blocked_5h's arithmetic over an arbitrary
# sqlite strftime window; ocgo_pace_blocked gates the OpenCode Go
# product's three windows (5h/$12, 7d/$30, monthly/$60 per model ->
# 60/150/300 calls at the row-26 per-call basis) and is the ONE entry
# every opencode-go consumer must route through.
quota_pace_blocked_window() { # source cap win-modifier soft-seconds -> 0 blocked (prints "used cap"), 1 go
 local src="$1" cap="$2" win="$3" soft="$4" used elapsed allowed
 case "$cap" in '' | *[!0-9]*) return 1 ;; esac # bad cap: fail open
 used="$(sqlite3 "$HNGH_TELEMETRY_DB" \
  "select count(*) from events where kind='model' and source in ('${src//,/\',\'}') \
     and ts >= strftime('%Y-%m-%dT%H:%M:%SZ','now','$win')" 2>/dev/null)"
 case "$used" in '' | *[!0-9]*) used=0 ;; esac
 [ "$used" -ge "$cap" ] && {
  printf '%s %s\n' "$used" "$cap"
  return 0
 }
 elapsed=$(($(date -u +%s) % soft))
 allowed="$(awk -v c="$cap" -v e="$elapsed" -v s="$soft" 'BEGIN{printf "%.4f", c*e/s}')"
 if awk -v u="$used" -v a="$allowed" 'BEGIN{exit !(u > a + 1)}'; then
  printf '%s %s\n' "$used" "$cap"
  return 0
 fi
 return 1
}

ocgo_pace_blocked() { # -> 0 blocked (prints "<window> used cap"), 1 go
 local pace
 pace="$(quota_pace_blocked_window ocgo,ocgo-agent \
  "${OCGO_CAP_5H_CALLS:-$(get_param opencode-cap-5h-calls 60)}" '-5 hours' 18000)" &&
  {
   printf '5h %s\n' "$pace"
   return 0
  }
 pace="$(quota_pace_blocked_window ocgo,ocgo-agent \
  "${OCGO_CAP_7D_CALLS:-$(get_param opencode-cap-7d-calls 150)}" '-7 days' 604800)" &&
  {
   printf '7d %s\n' "$pace"
   return 0
  }
 pace="$(quota_pace_blocked_window ocgo,ocgo-agent \
  "${OCGO_CAP_MONTH_CALLS:-$(get_param opencode-cap-month-calls 300)}" '-30 days' 2592000)" &&
  {
   printf 'month %s\n' "$pace"
   return 0
  }
 return 1
}

# Weekly fixed-window pacer (NOT a rolling -7 days: the window resets at
# Monday 00:00 UTC, so spend alignment matches the product's weekly
# reset; quota-tightest-window-pacing, 2026-09-13). Same soft-pace
# arithmetic across the elapsed part of the running week.
quota_pace_blocked_week() { # source cap [weekday 1=Mon..7=Sun] -> 0 blocked (prints "used cap"), 1 go
 local src="$1" cap="$2" wk="${3:-1}" used days_back week_start elapsed allowed
 case "$cap" in '' | *[!0-9]*) return 1 ;; esac
 days_back=$(((10#$(date -u +%u) - 10#$wk + 7) % 7))
 week_start=$(($(date -u +%s) - days_back * 86400 - 10#$(date -u +%H) * 3600 - \
 10#$(date -u +%M) * 60 - 10#$(date -u +%S)))
 used="$(sqlite3 "$HNGH_TELEMETRY_DB" \
  "select count(*) from events where kind='model' and source in ('${src//,/\',\'}') \
     and ts >= strftime('%Y-%m-%dT%H:%M:%SZ',$week_start,'unixepoch')" 2>/dev/null)"
 case "$used" in '' | *[!0-9]*) used=0 ;; esac
 [ "$used" -ge "$cap" ] && {
  printf '%s %s\n' "$used" "$cap"
  return 0
 }
 elapsed=$(($(date -u +%s) - week_start))
 allowed="$(awk -v c="$cap" -v e="$elapsed" 'BEGIN{printf "%.4f", c*e/604800}')"
 if awk -v u="$used" -v a="$allowed" 'BEGIN{exit !(u > a + 1)}'; then
  printf '%s %s\n' "$used" "$cap"
  return 0
 fi
 return 1
}

# chat via the Kimi quota leg (Kimi Code endpoint api.kimi.com/coding,
# OpenAI-compatible /v1/chat/completions). Key resolution order (first hit
# wins): env KIMI_AI_KEY (the operator-named K3 quota key; validated live
# 2026-09-07 on api.kimi.com/coding/v1/models + a real completion) ->
# KIMI_FOR_CODING_KEY (same endpoint, also validated) -> MOONSHOTAI_API_KEY
# (valid only on api.moonshot.ai, where chat 429s exceeded_current_quota_error
# = no platform balance; 401 on api.moonshot.cn and api.kimi.com) -> key file
# ~/.config/hngh/kimi-key (mode 600 required; the key VALUE is never
# logged or echoed). Models on the coding endpoint: kimi-for-coding /
# kimi-for-coding-highspeed / k3 / k3-256k (thinking-only: reasoning tokens
# count against max_tokens, so a small budget can return empty content).
# Model gate: KIMI_MODEL env -> cadence-params row
# `kimi-model` (empty/absent -> skipped fail-closed). Endpoint:
# KIMI_URL env -> `kimi-endpoint` row (default the Kimi Code
# chat-completions URL). Spend guard: hard cap `kimi-daily-cap` (default
# 40; env KIMI_DAILY_CAP_CALLS) plus quota-window pacing, see
# quota_pace_blocked. Reserved for bounded, high-value completions.
_kimi_body() { # model prompt max_tokens -> stdout; lean body (the Kimi Code gateway 400s on temperature; leave it out)
 python3 - "$1" "$2" "$3" <<'PY'
import json, sys
print(json.dumps({"model": sys.argv[1], "messages": [{"role": "user", "content": sys.argv[2]}], "max_tokens": int(sys.argv[3])}))
PY
}
kimi_chat() { # prompt max_tokens -> completion on stdout; 1 = skip/fail
 local prompt="$1" max_tokens="$2" url model key kfile content pace cap
 url="${KIMI_URL:-$(get_param kimi-endpoint 'https://api.kimi.com/coding/v1/chat/completions')}"
 key="${KIMI_AI_KEY:-${KIMI_FOR_CODING_KEY:-${MOONSHOTAI_API_KEY:-}}}"
 if [ -z "$key" ]; then
  kfile="${KIMI_KEY_FILE:-$HOME/.config/hngh/kimi-key}"
  if [ -f "$kfile" ]; then
   if [ "$(stat -c %a "$kfile" 2>/dev/null)" != "600" ]; then
    breadcrumb model "kimi" "key file too open (chmod 600 required) -> next backend"
    return 1
   fi
   key="$(cat "$kfile" 2>/dev/null)"
  fi
 fi
 [ -n "$key" ] || return 1 # no env key, no key file: silent fail-closed-skip
 model="${KIMI_MODEL:-$(get_param kimi-model '')}"
 [ -n "$model" ] || return 1 # operator has not named the quota model yet
 cap="${KIMI_DAILY_CAP_CALLS:-$(get_param kimi-daily-cap 40)}"
 pace="$(quota_pace_blocked kimi "$cap")"
 if [ -n "$pace" ]; then
  breadcrumb model "kimi" "quota pace: kimi used ${pace% *}/cap ${pace#* } -- deferring to next leg"
  return 1
 fi
 content="$(
  printf '%s' "$(_kimi_body "$model" "$prompt" "$max_tokens")" |
   _post_chat "$url" '.choices[0].message.content // ""' "$key"
 )" || {
  breadcrumb model "kimi" "HTTP $(cat "$POST_CODE_FILE" 2>/dev/null) -> next backend"
  return 1
 }
 printf '%s\n' "$content"
}

# chat via the OpenCode Go quota leg (opencode.ai/zen/go/v1/chat/completions,
# OpenAI-compatible; T2 GLM subscription, operator-armed 2026-09-10). Key
# resolution order: env OPENCODE_API_KEY (the same key Pi's opencode-go
# provider entry uses) -> key file ~/.config/hngh/opencode-key (mode 600
# required; the key VALUE is never logged or echoed). Model gate:
# OCGO_MODEL env -> cadence-params row `opencode-model` (empty/absent ->
# skipped fail-closed). Endpoint: OCGO_URL env -> `opencode-url` row
# (default the Go chat-completions URL). The Go gateway requires a stable
# `x-opencode-session` id per conversation (enforced 2026-09-06; a
# headerless POST reads 400 MissingSessionID -- live-verified 2026-09-10):
# hngh calls are one-shot, so each call gets a fresh random session id
# (honest: each completion IS its own conversation). Timeout: the shared
# _post_chat MODEL_TIMEOUT, same semantics as remote_chat/kimi (remote GLM
# route, same latency class). Spend guard (R3 tightest-window pacing): the
# 5h/$12 bucket is paced, not dumped -- hard cap `opencode-cap-5h-calls`
# (default 60; env OCGO_CAP_5H_CALLS) against the trailing-5h window via
# quota_pace_blocked_5h. Pacing arithmetic (glm-5.3-flash, Go pricing
# $0.15/$0.50 per 1M in/out): a bounded call (~10k tokens mixed) costs
# ~$0.005, so 60 calls/5h ~= $0.30 -- 40x inside the $12/5h bucket
# (provider's own estimate for the model: ~6,320 requests/5h).
ocgo_chat() { # prompt max_tokens -> completion on stdout; 1 = skip/fail
 local prompt="$1" max_tokens="$2" url model key kfile content pace cap
 url="${OCGO_URL:-$(get_param opencode-url 'https://opencode.ai/zen/go/v1/chat/completions')}"
 key="${OPENCODE_API_KEY:-}"
 if [ -z "$key" ]; then
  kfile="${OPENCODE_KEY_FILE:-$HOME/.config/hngh/opencode-key}"
  if [ -f "$kfile" ]; then
   if [ "$(stat -c %a "$kfile" 2>/dev/null)" != "600" ]; then
    breadcrumb model "ocgo" "key file too open (chmod 600 required) -> next backend"
    return 1
   fi
   key="$(cat "$kfile" 2>/dev/null)"
  fi
 fi
 [ -n "$key" ] || return 1 # no env key, no key file: silent fail-closed-skip
 model="${OCGO_MODEL:-$(get_param opencode-model '')}"
 [ -n "$model" ] || return 1 # operator has not named the quota model yet
 # every-window gate (tightest wins): 5h + 7d + monthly, see
 # quota-tightest-window-pacing (tightened 2026-09-13)
 # ocgo-agent = the opencode executor's agent-internal spend, attributed
 # by jobs/ocgo-attribution.py onto this same $12/5h bucket (R2: no
 # double-spend; design 2026-09-10 s6).
 pace="$(ocgo_pace_blocked)"
 if [ -n "$pace" ]; then
  local _o_label="${pace%% *}" _o_used="${pace#* }"
  breadcrumb model "ocgo" \
   "quota pace: ocgo+ocgo-agent ${_o_label}-window used ${_o_used%% *} of cap ${_o_used##* } -- deferring to next leg"
  return 1
 fi
 content="$(printf '%s' "$(_kimi_body "$model" "$prompt" "$max_tokens")" |
  _post_chat "$url" '.choices[0].message.content // ""' "$key" \
   "hngh-$(head -c8 /dev/urandom | od -An -tx1 | tr -d ' \n')")" || {
  breadcrumb model "ocgo" "HTTP $(cat "$POST_CODE_FILE" 2>/dev/null) -> next backend"
  return 1
 }
 printf '%s\n' "$content"
}

_model_emit() { # source model -- one kind=model row per successful call,
 # with wall_s and any usage tokens the leg measured (the
 # tmp files _post_chat/unsloth_attempt wrote; consumed and
 # cleared here so a later leg never inherits stale values)
 local wall tin tout data
 wall="$(cat "$WALL_S_FILE" 2>/dev/null)"
 tin="$(cat "$TOKIN_FILE" 2>/dev/null)"
 tout="$(cat "$TOKOUT_FILE" 2>/dev/null)"
 rm -f "$WALL_S_FILE" "$TOKIN_FILE" "$TOKOUT_FILE"
 data=""
 case "$tin$tout" in *[0-9]*) : ;; *)
  tin=""
  tout=""
  ;;
 esac
 [ -n "$tin" ] || [ -n "$tout" ] &&
  data="$(python3 -c 'import json,sys;print(json.dumps({k:int(v) for k,v in [("tokens_in",sys.argv[1]),("tokens_out",sys.argv[2])] if v}))' "${tin:-}" "${tout:-}")"
 python3 "$AUTOMATION_ROOT/jobs/telemetry.py" emit --kind model \
  --source "$1" --model "$2" --subject "${0##*/}" \
  ${wall:+--wall-s "$wall"} ${data:+--data "$data"} \
  >/dev/null 2>&1 || true
}

# kimi quota leg: call, tag MODEL_USED, persist tmp-modelused.txt, emit one
# telemetry row. Shared by the unpinned chain and MODEL_PIN=kimi/deck.
_kimi_leg() { # prompt max_tokens -> 0 = answered (MODEL_USED set)
 local km
 kimi_chat "$1" "$2" || return 1
 km="${KIMI_MODEL:-$(get_param kimi-model '')}"
 MODEL_USED="kimi:$km"
 printf '%s' "$MODEL_USED" >"$MODEL_USED_FILE"
 _model_emit kimi "$km"
 return 0
}

# opencode-go quota leg: call, tag MODEL_USED, persist tmp-modelused.txt,
# emit one telemetry row. Shared by the unpinned chain and MODEL_PIN=ocgo.
_ocgo_leg() { # prompt max_tokens -> 0 = answered (MODEL_USED set)
 local om
 ocgo_chat "$1" "$2" || return 1
 om="${OCGO_MODEL:-$(get_param opencode-model '')}"
 MODEL_USED="ocgo:$om"
 printf '%s' "$MODEL_USED" >"$MODEL_USED_FILE"
 _model_emit ocgo "$om"
 return 0
}

# Z.AI subscription quota leg (api.z.ai/api/coding/paas/v4, GLM Coding
# Plan, operator-armed 2026-09-13; model list verified live:
# glm-4.5..glm-5.3-flash). Key resolution order (first hit wins): env
# Z_AI_API_KEY (the only Z.AI credential present on this host) -> key
# file ~/.config/hngh/zai-key (mode 600 required; the value is never
# logged or echoed). Spend guard: TWO product windows, tightest wins
# (quota-tightest-window-pacing): zai-cap-5h-calls (rolling 5h) +
# zai-cap-week-calls (fixed window resetting Monday 00:00 UTC), source
# zai counted together -- opencode sessions on this provider attribute
# source=zai onto the SAME pair via jobs/ocgo-attribution.py --source.
# Model gate: ZAI_MODEL env -> `zai-model` row (empty/absent -> skipped
# fail-closed). Endpoint: ZAI_URL env -> `zai-endpoint` row (default
# the coding-plan chat-completions URL). Lean body, no temperature (the
# coding gateway 400s on it, same as Kimi).
zai_pace_blocked() { # -> 0 blocked (prints "<window> used cap"), 1 go
 local pace
 pace="$(quota_pace_blocked_window zai \
  "${ZAI_CAP_5H_CALLS:-$(get_param zai-cap-5h-calls 300)}" '-5 hours' 18000)" &&
  {
   printf '5h %s\n' "$pace"
   return 0
  }
 pace="$(quota_pace_blocked_week zai \
  "${ZAI_CAP_WEEK_CALLS:-$(get_param zai-cap-week-calls 1500)}")" &&
  {
   printf 'week %s\n' "$pace"
   return 0
  }
 return 1
}
zai_chat() { # prompt max_tokens -> completion on stdout; 1 = skip/fail
 local prompt="$1" max_tokens="$2" url model key content pace
 url="${ZAI_URL:-$(get_param zai-endpoint 'https://api.z.ai/api/coding/paas/v4/chat/completions')}"
 key="${Z_AI_API_KEY:-}"
 if [ -z "$key" ]; then
  local kfile="${ZAI_KEY_FILE:-$HOME/.config/hngh/zai-key}"
  if [ -f "$kfile" ]; then
   if [ "$(stat -c %a "$kfile" 2>/dev/null)" != "600" ]; then
    breadcrumb model "zai" "key file too open (chmod 600 required) -> next backend"
    return 1
   fi
   key="$(cat "$kfile" 2>/dev/null)"
  fi
 fi
 [ -n "$key" ] || return 1 # no env key, no key file: silent fail-closed-skip
 model="${ZAI_MODEL:-$(get_param zai-model '')}"
 [ -n "$model" ] || return 1 # operator has not named the quota model yet
 pace="$(zai_pace_blocked)"
 if [ -n "$pace" ]; then
  local _z_label="${pace%% *}" _z_used="${pace#* }"
  breadcrumb model "zai" \
   "quota pace: zai ${_z_label}-window used ${_z_used%% *} of cap ${_z_used##* } -- deferring to next leg"
  return 1
 fi
 local noproxy_host
 noproxy_host="$(printf '%s' "${url#*://}" | cut -d/ -f1)"
 # Primary: ride the operator's bili compression proxy, trusting its CA
 # (combined file: MITM domains get the bili CA, non-MITM blind-tunnel and
 # still need the system roots). Fail-soft: no CA file (bili not installed)
 # -> straight to the old direct bypass; proxied attempt failing at the
 # transport layer (bili down, code 000) -> one direct fallback.
 local ca="${BILI_CA_FILE:-$HOME/.local/share/billion-context/ca/combined-ca.pem}"
 local content pcode
 if [ -f "$ca" ]; then
  content="$(printf '%s' "$(_kimi_body "$model" "$prompt" "$max_tokens")" |
   _post_chat "$url" '.choices[0].message.content // ""' "$key" '' '' "$ca")" && {
   breadcrumb model "zai" "served via bili proxy"
   printf '%s\n' "$content"
   return 0
  }
  pcode="$(cat "$POST_CODE_FILE" 2>/dev/null)"
  if [ "$pcode" != "000" ]; then
   breadcrumb model "zai" "HTTP $pcode -> next backend"
   return 1
  fi
  breadcrumb model "zai" "proxied attempt failed at transport (bili down?) -> direct fallback"
 fi
 content="$(printf '%s' "$(_kimi_body "$model" "$prompt" "$max_tokens")" |
  _post_chat "$url" '.choices[0].message.content // ""' "$key" '' "$noproxy_host")" || {
  breadcrumb model "zai" "HTTP $(cat "$POST_CODE_FILE" 2>/dev/null) -> next backend"
  return 1
 }
 breadcrumb model "zai" "served direct (--noproxy $noproxy_host)"
 printf '%s\n' "$content"
}

# zai quota leg: call, tag MODEL_USED, persist tmp-modelused.txt, emit
# one telemetry row (source=zai -- the shared Z.AI bucket pair). Shared
# by the unpinned chain and MODEL_PIN=zai.
_zai_leg() { # prompt max_tokens -> 0 = answered (MODEL_USED set)
 local zm
 zai_chat "$1" "$2" || return 1
 zm="${ZAI_MODEL:-$(get_param zai-model '')}"
 MODEL_USED="zai:$zm"
 printf '%s' "$MODEL_USED" >"$MODEL_USED_FILE"
 _model_emit zai "$zm"
 return 0
}

# deck leg (second-server overflow), same contract as _kimi_leg. No
# telemetry emit: the saturation instrument measures the desktop
# unsloth, and the deck is overflow-only, so deck rows would skew it.
_deck_leg() { # prompt max_tokens -> 0 = answered (MODEL_USED set)
 deck_chat "$1" "$2" || return 1
 MODEL_USED="deck:${DECK_MODEL:-deck}"
 printf '%s' "$MODEL_USED" >"$MODEL_USED_FILE"
 return 0
}

model_call() {
 local max_tokens="${1:-$MODEL_MAX_TOKENS}"
 local prompt pin_local=0 pin_kimi=0 pin_deck=0 pin_ocgo=0 pin_zai=0 pin_remote=0 \
  pin_feedback=0 pin_review=0
 case "${MODEL_PIN:-}" in
 local) pin_local=1 ;;
 kimi) pin_kimi=1 ;;
 deck) pin_deck=1 ;;
 ocgo) pin_ocgo=1 ;;
 zai) pin_zai=1 ;;
 remote) pin_remote=1 ;;
 feedback) pin_feedback=1 ;;
 review) pin_review=1 ;;
 esac # unknown values: ignore (full chain)
 prompt="$(cat)"
 MODEL_USED=""
 printf '' >"$MODEL_TRUNC_FILE" 2>/dev/null
 # review lane: the current quota ladder deck -> kimi -> zai -> ocgo with
 # the local bench LAST; unarmed or pace-blocked legs skip fail-closed
 # inside their _*_leg gates, and remote (paid openrouter) is never in
 # this lane.
 if [ "$pin_review" = 1 ]; then
  _deck_leg "$prompt" "$max_tokens" && return 0
  _kimi_leg "$prompt" "$max_tokens" && return 0
  _zai_leg "$prompt" "$max_tokens" && return 0
  _ocgo_leg "$prompt" "$max_tokens" && return 0
 fi
 # pinned quota legs run first; a miss (pace-block, 429, down) falls
 # through to the local chain -- the caller never blocks on quota state.
 if [ "$pin_remote" = 1 ]; then
  local rmodel="${REMOTE_MODEL_CODING:-$(get_param remote-model-coding '')}"
  [ -n "$rmodel" ] || rmodel="${REMOTE_MODEL:-}"
  if (
   REMOTE_MODEL="$rmodel"
   remote_chat "$prompt" "$max_tokens"
  ); then
   MODEL_USED="openrouter:$rmodel"
   printf '%s' "$MODEL_USED" >"$MODEL_USED_FILE"
   _model_emit remote "$rmodel"
   return 0
  fi
 fi
 if [ "$pin_feedback" = 1 ]; then
  local fmodel="${REMOTE_MODEL_FEEDBACK:-$(get_param remote-model-feedback '')}"
  [ -n "$fmodel" ] || fmodel="${REMOTE_MODEL:-}"
  if (
   REMOTE_MODEL="$fmodel"
   remote_chat "$prompt" "$max_tokens"
  ); then
   MODEL_USED="openrouter:$fmodel"
   printf '%s' "$MODEL_USED" >"$MODEL_USED_FILE"
   _model_emit remote "$fmodel"
   return 0
  fi
 fi
 if [ "$pin_kimi" = 1 ] && _kimi_leg "$prompt" "$max_tokens"; then
  return 0
 fi
 if [ "$pin_zai" = 1 ] && _zai_leg "$prompt" "$max_tokens"; then
  return 0
 fi
 if [ "$pin_ocgo" = 1 ] && _ocgo_leg "$prompt" "$max_tokens"; then
  return 0
 fi
 if [ "$pin_deck" = 1 ] && _deck_leg "$prompt" "$max_tokens"; then
  return 0
 fi
 if unsloth_chat "$prompt" "$max_tokens" "$MODEL"; then
  MODEL_USED="unsloth:$MODEL"
  printf '%s' "$MODEL_USED" >"$MODEL_USED_FILE"
  _model_emit unsloth "$MODEL"
  return 0
 fi
 local m
 # ranked unsloth chain: primary first, then the bench-ranked fallbacks
 # (the server auto-activates the named model per request)
 for m in $MODEL $UNSLOTH_FALLBACK_MODELS; do
  [ -z "$m" ] && continue
  if unsloth_chat "$prompt" "$max_tokens" "$m"; then
   MODEL_USED="unsloth:$m"
   printf '%s' "$MODEL_USED" >"$MODEL_USED_FILE"
   _model_emit unsloth "$m"
   return 0
  fi
 done
 if [ "$pin_review" = 0 ] && [ "$pin_local" = 0 ] && [ "$pin_kimi" = 0 ] && [ "$pin_deck" = 0 ] &&
  [ "$pin_ocgo" = 0 ] &&
  [ "$pin_zai" = 0 ] &&
  _zai_leg "$prompt" "$max_tokens"; then
  # the Z.AI subscription replaces openrouter for z-ai-model calls:
  # direct leg first (bucket-gated), openrouter stays the fallback
  return 0
 fi
 if [ "$pin_review" = 0 ] && [ "$pin_local" = 0 ] && [ "$pin_kimi" = 0 ] && [ "$pin_deck" = 0 ] &&
  [ "$pin_ocgo" = 0 ] && [ "$pin_zai" = 0 ] &&
  remote_chat "$prompt" "$max_tokens"; then
  MODEL_USED="openrouter:$REMOTE_MODEL"
  printf '%s' "$MODEL_USED" >"$MODEL_USED_FILE"
  _model_emit remote "$REMOTE_MODEL"
  return 0
 fi
 if ollama_chat "$prompt" "$max_tokens"; then
  MODEL_USED="ollama:$OLLAMA_MODEL"
  printf '%s' "$MODEL_USED" >"$MODEL_USED_FILE"
  _model_emit ollama "$OLLAMA_MODEL"
  return 0
 fi
 if [ "$pin_review" = 0 ] && [ "$pin_local" = 0 ] && [ "$pin_deck" = 0 ] &&
  _deck_leg "$prompt" "$max_tokens"; then
  return 0
 fi
 if [ "$pin_review" = 0 ] && [ "$pin_local" = 0 ] && [ "$pin_kimi" = 0 ] &&
  [ "$pin_ocgo" = 0 ] && [ "$pin_zai" = 0 ] &&
  _kimi_leg "$prompt" "$max_tokens"; then
  return 0
 fi
 if [ "$pin_review" = 0 ] && [ "$pin_local" = 0 ] && [ "$pin_kimi" = 0 ] &&
  [ "$pin_ocgo" = 0 ] && [ "$pin_deck" = 0 ] && [ "$pin_zai" = 0 ] &&
  _ocgo_leg "$prompt" "$max_tokens"; then
  return 0
 fi
 archive_only "$prompt"
 MODEL_USED="none:archive-only"
 printf '%s' "$MODEL_USED" >"$MODEL_USED_FILE"
 return 0
}
