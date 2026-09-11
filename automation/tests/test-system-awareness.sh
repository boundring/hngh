#!/usr/bin/env bash
# test-system-awareness.sh -- contract proofs for the network-down
# headroom flag (2026-09-11 fix): the flag must mean "this machine
# cannot reach the WAN" (measured by the curl probe), NOT "local model
# endpoint hiccuped while peer devices sleep" — the old (model fail
# && peers 0) predicate fired network-down nightly 2026-09-08..09-11
# while push/ping/GitHub all worked. Cases:
#   A) model endpoint fail + WAN ok   -> network-down false (regression)
#   B) WAN fail (connection refused)  -> network-down true
# Hermetic: PATH shim for curl (no real network), closed-port reviewer
# conf (no real endpoint), sandbox STATE_FILE + AWARENESS_OUT.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
trap 'rm -rf "$sb"' EXIT
mkdir -p "$sb/bin"

ok() { echo "ok: $1"; }
need() { "$@" || {
 echo "FAIL: $*"
 exit 1
}; } # every case fatal

# reviewer conf pointing at a closed local port -> model=fail every
# run, deterministic, no real endpoint contacted.
cat > "$sb/closed.conf" <<EOF
endpoint=http://127.0.0.1:1/v1
model=stub
max-tokens=1
timeout=1
token-file=$sb/no-such-token
EOF

run_awareness() { # want_flag curl_exit want_wan label
 local want_flag="$1" curl_rc="$2" want_wan="$3" label="$4"
 printf '#!/bin/sh\nexit %s\n' "$curl_rc" > "$sb/bin/curl"
 chmod +x "$sb/bin/curl"
 PATH="$sb/bin:$PATH" STATE_FILE="$sb/STATE.md" AWARENESS_OUT="$sb/system.json" \
  PROBE_ROUTE_CONF="$sb/closed.conf" timeout 60 bash "$root/jobs/system-awareness.sh" \
  >/dev/null 2>&1
 need [ "$(jq -r '.headroom["network-down"]' "$sb/system.json")" = "$want_flag" ]
 need [ "$(jq -r '.net.wan_endpoint' "$sb/system.json")" = "$want_wan" ]
 ok "$label"
}

run_awareness false 0 ok   "A: model fail + WAN ok is NOT network-down"
run_awareness true 7 fail "B: WAN fail IS network-down"

echo "PASS"
