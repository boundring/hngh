#!/usr/bin/env bash
# lobehub-verify.sh -- post-login verifier for the dormant lobehub leg.
# Locates the Cloud token, bearer-probes the candidate surfaces (read-only),
# and prints a verdict: either the inference endpoint + model row to set, or
# "leg stays dormant". The token VALUE is never printed -- presence and HTTP
# codes only. Every path exits 0; key-absent prints the runbook steps.
set -u
KEY_FILE="${LOBEHUB_KEY_FILE:-$HOME/.config/hngh/lobehub-key}"
MODEL="${LOBEHUB_MODEL:-default}"
BODY_FILE="$(mktemp)"
trap 'rm -f "$BODY_FILE"' EXIT

runbook() {
 cat <<'EOF'
Key not found. Activation runbook (docs/LOBEHUB.md):
  1. Log into lobehub.com in the browser, or install the CLI
     (npm -g @lobehub/cli) and run `lh login`.
  2. Create a Lobehub Cloud token per the OAuth discovery flow
     (/.well-known/oauth-authorization-server; S256 PKCE).
  3. Save it: install -m 600 /dev/null ~/.config/hngh/lobehub-key
     then paste the token into that file (or: export LOBEHUB_KEY=...).
  4. Re-run: scripts/lobehub-verify.sh
  5. Follow the verdict: if the inference endpoint is FOUND, fill the
     lobehub-model Inventory row (cadence-params.tsv, by hand or request);
     the leg goes live on the next model_call. Pacing/cap rows already exist.
EOF
}

probe() { # method url [json-body] -> prints "HTTP <code>" then body head if JSON
 local method="$1" url="$2" body="${3:-}" code out
 if [ -n "$body" ]; then
  code="$(printf '%s' "$body" | curl -s --max-time 20 -X "$method" \
   -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' \
   -d @- -o "$BODY_FILE" -w '%{http_code}' "$url" 2>/dev/null)" || code=000
 else
  code="$(curl -s --max-time 20 -X "$method" \
   -H "Authorization: Bearer $KEY" \
   -o "$BODY_FILE" -w '%{http_code}' "$url" 2>/dev/null)" || code=000
 fi
 out="HTTP $code"
 if [ -s "$BODY_FILE" ]; then
  case "$(head -c 1 "$BODY_FILE")" in
  '{' | '[') out="$out  $(head -c 200 "$BODY_FILE" | tr -d '\n')" ;;
  esac
 fi
 printf '%s\n' "$out"
}

KEY="${LOBEHUB_KEY:-}"
if [ -z "$KEY" ]; then
 if [ ! -s "$KEY_FILE" ]; then
  runbook
  exit 0
 fi
 if [ "$(stat -c %a "$KEY_FILE" 2>/dev/null)" != "600" ]; then
  echo "key file exists but mode is not 600 -- refusing (chmod 600 $KEY_FILE)"
  runbook
  exit 0
 fi
 KEY="$(cat "$KEY_FILE")"
fi
echo "key: present (value never printed)"

echo "== account surface =="
probe GET "https://lobehub.com/api/mcp"
echo "(openapi.json is keyless -- no re-fetch; see docs/LOBEHUB.md)"

echo "== inference candidates (POST chat/completions) =="
chat_body="{\"model\":\"$MODEL\",\"max_tokens\":16,\"messages\":[{\"role\":\"user\",\"content\":\"Reply with the single word: acknowledged\"}]}"
infer_found=""
for url in \
 "https://lobehub.com/api/v1/chat/completions" \
 "https://app.lobehub.com/api/v1/chat/completions" \
 "https://open.lobehub.com/v1/chat/completions"; do
 line="$(probe POST "$url" "$chat_body")"
 echo "POST $url -> $line"
 case "$line" in "HTTP 200"*) infer_found="$url" ;; esac
done

echo "== model list candidates (GET /v1/models) =="
model_row=""
for base in "https://lobehub.com/api" "https://app.lobehub.com/api" "https://open.lobehub.com"; do
 line="$(probe GET "$base/v1/models")"
 echo "GET $base/v1/models -> $line"
 if [ "$line" = "HTTP 200" ] || [ "${line%% *}" = "HTTP" ] && [ "${line#HTTP }" != "401" ] && [ "${line#HTTP }" != "403" ]; then
  case "$line" in "HTTP 200"*) [ -z "$model_row" ] && model_row="(see body above for model ids)" ;; esac
 fi
done

echo "== verdict =="
if [ -n "$infer_found" ]; then
 echo "inference endpoint: FOUND $infer_found -- set lobehub-model row to <model from the model list above> and arm"
else
 echo "not exposed to this token -- leg stays dormant; the integration path is WebMCP/OAuth surfaces (docs/LOBEHUB.md)"
fi
exit 0
