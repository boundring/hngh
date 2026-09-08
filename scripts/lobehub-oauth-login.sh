#!/usr/bin/env bash
# lobehub-oauth-login.sh -- one-command machine-side login for the lobehub leg.
# Two modes:
#   (default)   Device Code Flow against https://app.lobehub.com/oidc/device/auth
#               (public client_id "lobehub-cli", same as @lobehub/cli):
#               prints + opens the verification URL, polls the token endpoint,
#               writes the access token to ~/.config/hngh/lobehub-key (mode 600).
#   --from-cli  Decrypt the token stored by an existing `lh login`
#               (~/.lobehub/credentials.json, AES-256-GCM with a deterministic
#               machine-local key) and write the same key file.
# The token VALUE is never echoed. Every path exits 0 (blockers are printed).
set -u
KEY_FILE="${LOBEHUB_KEY_FILE:-$HOME/.config/hngh/lobehub-key}"
SERVER="${LOBEHUB_SERVER:-https://app.lobehub.com}"
CLIENT_ID="lobehub-cli"
SCOPES="openid profile email offline_access"
RESOURCE="urn:lobehub:chat"

write_key() { # token -> writes key file, prints nothing about the value
 local token="$1"
 umask 077
 mkdir -p "$(dirname "$KEY_FILE")"
 printf '%s' "$token" >"$KEY_FILE"
 chmod 600 "$KEY_FILE"
 echo "key file written: $KEY_FILE (mode 600)"
 echo "next: scripts/lobehub-verify.sh"
}

from_cli() {
 command -v node >/dev/null 2>&1 || {
  echo "blocker: node not found for --from-cli"
  return 0
 }
 local src="${LOBEHUB_CRED_FILE:-$HOME/.lobehub/credentials.json}"
 [ -s "$src" ] || {
  echo "no $src -- run 'lh login' first, or use device flow (no args)"
  return 0
 }
 local token
 token="$(node -e '
    const fs=require("fs"),os=require("os"),crypto=require("crypto");
    const packed=Buffer.from(fs.readFileSync(process.argv[1],"utf8"),"base64");
    const key=crypto.pbkdf2Sync(`lobehub-cli:${os.hostname()}:${os.userInfo().username}`,"lobehub-cli-salt",1e5,32,"sha256");
    const d=crypto.createDecipheriv("aes-256-gcm",key,packed.subarray(0,12));
    d.setAuthTag(packed.subarray(12,28));
    const c=JSON.parse(d.update(packed.subarray(28)).toString("utf8")+d.final("utf8"));
    process.stdout.write(c.accessToken||"");
  ' "$src" 2>/dev/null)" || token=""
 if [ -z "$token" ]; then
  echo "blocker: could not decrypt $src on this machine (hostname/user changed?)"
  echo "fallback: device flow -- run this script with no arguments"
  return 0
 fi
 write_key "$token"
}

device_flow() {
 command -v curl >/dev/null 2>&1 || {
  echo "blocker: curl not found"
  return 0
 }
 local auth_body code
 auth_body="$(curl -s --max-time 20 -X POST "$SERVER/oidc/device/auth" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "client_id=$CLIENT_ID" -d "resource=$RESOURCE" -d "scope=$SCOPES")"
 case "$auth_body" in
 *verification_uri* | *user_code*) : ;;
 *)
  echo "blocker: device authorization not offered ($SERVER/oidc/device/auth)"
  echo "raw response head: $(printf '%s' "$auth_body" | head -c 200)"
  echo "manual fallback: log in at lobehub.com, create a Cloud token, paste it into $KEY_FILE (mode 600)"
  return 0
  ;;
 esac
 local verify_url user_code device_code interval expires
 verify_url="$(printf '%s' "$auth_body" | sed -n 's/.*"verification_uri_complete" *: *"\([^"]*\)".*/\1/p')"
 [ -n "$verify_url" ] || verify_url="$(printf '%s' "$auth_body" | sed -n 's/.*"verification_uri" *: *"\([^"]*\)".*/\1/p')"
 user_code="$(printf '%s' "$auth_body" | sed -n 's/.*"user_code" *: *"\([^"]*\)".*/\1/p')"
 device_code="$(printf '%s' "$auth_body" | sed -n 's/.*"device_code" *: *"\([^"]*\)".*/\1/p')"
 interval="$(printf '%s' "$auth_body" | sed -n 's/.*"interval" *: *\([0-9]*\).*/\1/p')"
 interval="${interval:-5}"
 expires="$(printf '%s' "$auth_body" | sed -n 's/.*"expires_in" *: *\([0-9]*\).*/\1/p')"
 expires="${expires:-600}"
 echo "Open this URL in your browser:"
 echo "  $verify_url"
 echo "Enter code: $user_code"
 xdg-open "$verify_url" >/dev/null 2>&1 || echo "(could not open browser automatically)"
 echo "Waiting for authorization..."
 local deadline=$(($(date +%s) + expires)) poll="$interval"
 while [ "$(date +%s)" -lt "$deadline" ]; do
  sleep "$poll"
  local body err token
  body="$(curl -s --max-time 20 -X POST "$SERVER/oidc/token" \
   -H 'Content-Type: application/x-www-form-urlencoded' \
   -d "client_id=$CLIENT_ID" -d "device_code=$device_code" \
   -d 'grant_type=urn:ietf:params:oauth:grant-type:device_code')"
  err="$(printf '%s' "$body" | sed -n 's/.*"error" *: *"\([^"]*\)".*/\1/p')"
  case "$err" in
  "") : ;;
  authorization_pending) continue ;;
  slow_down)
   poll=$((poll + 5))
   continue
   ;;
  *)
   echo "authorization error: $err -- run this script again"
   return 0
   ;;
  esac
  token="$(printf '%s' "$body" | sed -n 's/.*"access_token" *: *"\([^"]*\)".*/\1/p')"
  if [ -n "$token" ]; then write_key "$token"; else echo "token endpoint replied without access_token (head: $(printf '%s' "$body" | head -c 200))"; fi
  return 0
 done
 echo "device code expired before authorization -- run this script again"
}

case "${1:-}" in
--from-cli) from_cli ;;
"" | device) device_flow ;;
*)
 echo "usage: $0 [--from-cli]"
 echo "  (no args) device-code login flow; --from-cli reuse an existing 'lh login' token"
 ;;
esac
exit 0
