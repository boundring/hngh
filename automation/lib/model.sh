# model.sh — model-call with fail-closed fallback chain.
#   model_call [MAX_TOKENS]   <- stdin prompt
#   echoes the completion text (EMPTY output only in archive-only mode);
#   writes $MODEL_USED to $AUTOMATION_ROOT/tmp-modelused.txt so callers can
#   read it from OUTSIDE the command-substitution subshell.
# Chain: unsloth (401 auto-refresh + empty-content retry) -> remote
# (budget-gated, see remote_chat) -> ollama -> deck (param-gated, see
# deck_chat) -> kimi (quota leg, see kimi_chat) -> ocgo (quota leg,
# OpenCode Go, 5h-window pacing, see ocgo_chat) -> lobehub (quota leg,
# see lobehub_chat) -> archive-only.
# MODEL_PIN routes a call:
#   local  unsloth -> ollama only (remote, deck, and the quota legs kimi/
#          lobehub are skipped): news/ux-review/bench pin local
#          (low-stakes or probing local models).
#   ocgo   ocgo first (OpenCode Go GLM quota, 5h-window paced), then
#          unsloth -> ollama -> deck -> archive; remote + kimi + lobehub
#          skipped. Research volume rotates onto it
#          (opencode-research-share).
#   kimi   kimi first (K3 quota primary), then unsloth -> ollama ->
#          deck -> archive; remote + lobehub skipped. Intelligence-shaped
#          bounded work (research transitions, fresh-eyes review) rotates
#          onto the quota here, spread across the window by
#          quota_pace_blocked + kimi-daily-cap.
#   lobehub lobehub first (Responses-API quota leg), then unsloth ->
#          ollama -> deck -> archive; remote + kimi skipped. Research
#          volume rotates onto it (lobehub-research-share).
#   deck   deck first (second-server overflow), then unsloth -> ollama ->
#          kimi -> archive; remote + lobehub skipped.
#   other  ignored: the full chain runs.
# A pinned quota leg that misses (pace-block, 429, endpoint down) falls
# through to the local chain inside model_call -- research/reviews never
# block on quota state. Delegated-session spend is governed separately by
# the session caps; remote/openrouter stays budget-gated last-resort for
# sessions only.
# Every step exits 0 unless a genuine local bug (missing python3, etc.).
. "$AUTOMATION_ROOT/lib/common.sh"
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

last_model_used() {
 cat "$MODEL_USED_FILE" 2>/dev/null || true
}

# _post_chat URL JQ_EXPR [BEARER_KEY] — the shared POST+parse scaffold for
# the chat legs (ollama, remote, deck, kimi, lobehub): JSON body on stdin,
# curl POST with content-type + optional bearer header, %{http_code}
# capture, jq parse of the completion, tmp cleanup. Prints the completion
# and returns 0 on HTTP 200 + nonempty content; else returns 1. The http
# code (000 on transport failure) goes to $POST_CODE_FILE — a file, not a
# variable, because the helper runs inside the caller's command-substitution
# subshell (same reason MODEL_USED goes through tmp-modelused.txt).
_post_chat() { # url jq_expr [bearer] [session_hdr] -> content on stdout; code in $POST_CODE_FILE,
 # wall seconds in $WALL_S_FILE, usage tokens (chat-completions
 # .usage.prompt_tokens/completion_tokens or Responses
 # .usage.input_tokens/output_tokens) in $TOKIN/$TOKOUT files
 local url="$1" expr="$2" auth="${3:-}" session="${4:-}" tmp code content
 local raw t tin tout
 tmp="$(mktemp)"
 raw="$(curl -s --max-time "$MODEL_TIMEOUT" -X POST \
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

# chat via Unsloth. Handles: 401 -> refresh once & retry; 200+empty content ->
# retry once with budget*8 and thinking disabled, then reasoning_content as last resort.
unsloth_chat() {
 local prompt="$1" max_tokens="$2" model="$3"
 local refreshed="${4:-0}" tok code content reasoning big tmp
 tok="$(cat "$TOKEN_FILE" 2>/dev/null)" || {
  breadcrumb model "unsloth" "no token file -> next backend"
  return 1
 }

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
 count="$(sqlite3 "$AUTOMATION_ROOT/dashboard/telemetry.db" \
  "select count(*) from events where kind='model' and source='remote' and ts like '$(date -u +%Y-%m-%d)%'" 2>/dev/null)"
 case "$count" in '' | *[!0-9]*) count=0 ;; esac
 [ "$count" -ge "$REMOTE_DAILY_CAP_CALLS" ] && {
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

# Quota-window pacing for the paid legs (kimi, lobehub). Counts today's
# telemetry events (kind=model source=<source>, the same query remote_chat
# uses) and blocks when the day is being spent faster than an even pace:
# used >= cap (hard cap) OR used > cap*elapsed/86400 + 1 (soft pace, one
# call of grace). This spreads the daily cap across the UTC window instead
# of front-loading it at midnight. Prints "<used> <cap>" when blocked (for
# the caller's breadcrumb); exit 0 = blocked, 1 = go.
quota_pace_blocked() { # source cap -> 0 blocked (prints "used cap"), 1 go
 local src="$1" cap="$2" used elapsed allowed
 case "$cap" in '' | *[!0-9]*) return 1 ;; esac # bad cap: fail open
 used="$(sqlite3 "$AUTOMATION_ROOT/dashboard/telemetry.db" \
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
 used="$(sqlite3 "$AUTOMATION_ROOT/dashboard/telemetry.db" \
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
# OpenAI-compatible; T2 GLM subscription, operator-armed 2026-09-10 --
# docs/research/2026-09-10-lobehub-api-research.md section 4). Key
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
 cap="${OCGO_CAP_5H_CALLS:-$(get_param opencode-cap-5h-calls 60)}"
 # ocgo-agent = the opencode executor's agent-internal spend, attributed
 # by jobs/ocgo-attribution.py onto this same $12/5h bucket (R2: no
 # double-spend; design 2026-09-10 s6).
 pace="$(quota_pace_blocked_5h ocgo,ocgo-agent "$cap")"
 if [ -n "$pace" ]; then
  breadcrumb model "ocgo" "quota pace 5h: ocgo used ${pace% *}/cap ${pace#* } -- deferring to next leg"
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

# chat via the Lobehub premium-quota endpoint (OpenAI Responses API
# /api/v1/responses; docs/LOBEHUB.md). Two gates, both fail-closed-skip:
# (a) key resolution order: env LOBEHUB_KEY -> key file
# ~/.config/hngh/lobehub-key (mode 600 required; absent or too open -> the
# leg is dormant and silently skipped; the key VALUE is never logged or
# echoed), (b) agent id: env LOBEHUB_AGENT_ID -> cadence-params row
# `lobehub-agent-id` (empty/absent -> no agent to address -> skipped).
# Spend guard: hard cap `lobehub-daily-cap` (default 50; env
# LOBEHUB_DAILY_CAP_CALLS) plus quota-window pacing, see quota_pace_blocked
# (telemetry kind=model, source=lobehub, the same mechanism remote_chat
# uses for openrouter).
_lobehub_body() {                # agent prompt max_tokens -> stdout (verified
 python3 - "$1" "$2" "$3" <<'PY' # live 2026-09-07: OpenAI Responses shape,
import json, sys                 # model field = LobeHub agent id; NO messages,
print(json.dumps({"model": sys.argv[1], "input": sys.argv[2], "max_output_tokens": int(sys.argv[3])}))
PY
 # live 2026-09-07: OpenAI Responses shape,
}
lobehub_chat() { # prompt max_tokens -> completion on stdout; 1 = skip/fail
 local prompt="$1" max_tokens="$2" url agent key kfile content pace cap
 key="${LOBEHUB_KEY:-}"
 kfile="${LOBEHUB_KEY_FILE:-$HOME/.config/hngh/lobehub-key}"
 if [ -z "$key" ]; then
  key="$(cat "$kfile" 2>/dev/null)" || key=""
 fi
 [ -n "$key" ] || return 1 # no env key, no key file: silent fail-closed-skip
 # trust boundary: a world/group-readable key file is a config error, not
 # a usable credential — skip with a breadcrumb, never read it into a log.
 # (env-armed keys skip the file-mode check: nothing on disk to leak.)
 if [ -z "${LOBEHUB_KEY:-}" ] &&
  [ "$(stat -c %a "$kfile" 2>/dev/null)" != "600" ]; then
  breadcrumb model "lobehub" "key file too open (chmod 600 required) -> next backend"
  return 1
 fi
 agent="${LOBEHUB_AGENT_ID:-$(get_param lobehub-agent-id '')}"
 [ -n "$agent" ] || return 1
 url="${LOBEHUB_URL:-$(get_param lobehub-endpoint 'https://app.lobehub.com/api/v1/responses')}"
 cap="${LOBEHUB_DAILY_CAP_CALLS:-$(get_param lobehub-daily-cap 50)}"
 pace="$(quota_pace_blocked lobehub "$cap")"
 if [ -n "$pace" ]; then
  breadcrumb model "lobehub" "quota pace: lobehub used ${pace% *}/cap ${pace#* } -- deferring to next leg"
  return 1
 fi
 content="$(printf '%s' "$(_lobehub_body "$agent" "$prompt" "$max_tokens")" |
  _post_chat "$url" '.output_text // .output[0].content[0].text' "$key")" || {
  breadcrumb model "lobehub" "HTTP $(cat "$POST_CODE_FILE" 2>/dev/null) -> next backend"
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

# deck leg (second-server overflow), same contract as _kimi_leg. No
# telemetry emit: the saturation instrument measures the desktop
# unsloth, and the deck is overflow-only, so deck rows would skew it.
_deck_leg() { # prompt max_tokens -> 0 = answered (MODEL_USED set)
 deck_chat "$1" "$2" || return 1
 MODEL_USED="deck:${DECK_MODEL:-deck}"
 printf '%s' "$MODEL_USED" >"$MODEL_USED_FILE"
 return 0
}

# lobehub quota leg: call, tag MODEL_USED, persist tmp-modelused.txt, emit
# one telemetry row. Shared by the unpinned chain and MODEL_PIN=lobehub.
_lobehub_leg() { # prompt max_tokens -> 0 = answered (MODEL_USED set)
 lobehub_chat "$1" "$2" || return 1
 MODEL_USED="lobehub:${LOBEHUB_AGENT_ID:-$(get_param lobehub-agent-id '')}"
 printf '%s' "$MODEL_USED" >"$MODEL_USED_FILE"
 _model_emit lobehub "$MODEL_USED"
 return 0
}

model_call() {
 local max_tokens="${1:-$MODEL_MAX_TOKENS}"
 local prompt pin_local=0 pin_kimi=0 pin_deck=0 pin_lobehub=0 pin_ocgo=0
 case "${MODEL_PIN:-}" in
 local) pin_local=1 ;;
 kimi) pin_kimi=1 ;;
 deck) pin_deck=1 ;;
 lobehub) pin_lobehub=1 ;;
 ocgo) pin_ocgo=1 ;;
 esac # unknown values: ignore (full chain)
 prompt="$(cat)"
 MODEL_USED=""
 # pinned quota legs run first; a miss (pace-block, 429, down) falls
 # through to the local chain -- the caller never blocks on quota state.
 if [ "$pin_kimi" = 1 ] && _kimi_leg "$prompt" "$max_tokens"; then
  return 0
 fi
 if [ "$pin_ocgo" = 1 ] && _ocgo_leg "$prompt" "$max_tokens"; then
  return 0
 fi
 if [ "$pin_deck" = 1 ] && _deck_leg "$prompt" "$max_tokens"; then
  return 0
 fi
 if [ "$pin_lobehub" = 1 ] && _lobehub_leg "$prompt" "$max_tokens"; then
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
 if [ "$pin_local" = 0 ] && [ "$pin_kimi" = 0 ] && [ "$pin_deck" = 0 ] &&
  [ "$pin_lobehub" = 0 ] && [ "$pin_ocgo" = 0 ] &&
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
 if [ "$pin_local" = 0 ] && [ "$pin_deck" = 0 ] &&
  _deck_leg "$prompt" "$max_tokens"; then
  return 0
 fi
 if [ "$pin_local" = 0 ] && [ "$pin_kimi" = 0 ] &&
  [ "$pin_ocgo" = 0 ] && [ "$pin_lobehub" = 0 ] &&
  _kimi_leg "$prompt" "$max_tokens"; then
  return 0
 fi
 if [ "$pin_local" = 0 ] && [ "$pin_kimi" = 0 ] &&
  [ "$pin_ocgo" = 0 ] && [ "$pin_deck" = 0 ] &&
  _ocgo_leg "$prompt" "$max_tokens"; then
  return 0
 fi
 if [ "$pin_local" = 0 ] && [ "$pin_kimi" = 0 ] && [ "$pin_deck" = 0 ] &&
  [ "$pin_ocgo" = 0 ] &&
  _lobehub_leg "$prompt" "$max_tokens"; then
  return 0
 fi
 archive_only "$prompt"
 MODEL_USED="none:archive-only"
 printf '%s' "$MODEL_USED" >"$MODEL_USED_FILE"
 return 0
}
