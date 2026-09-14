#!/usr/bin/env bash
# test-system-awareness.sh -- contract proofs for the network-down
# headroom flag (2026-09-11 fix): the flag must mean "this machine
# cannot reach the WAN" (measured by the curl probe), NOT "local model
# endpoint hiccuped while peer devices sleep" — the old (model fail
# && peers 0) predicate fired network-down nightly 2026-09-08..09-11
# while push/ping/GitHub all worked. Cases:
#   A) model endpoint fail + WAN ok   -> network-down false (regression)
#   B) WAN fail (connection refused)  -> network-down true
#   C) capitalized `Peer` map (current tailscale versions) -> peers 2,
#      self excluded (Self is a separate key); reproduces the live bug
#      where fleet-manager read only lowercase `peer` and the dashboard
#      showed tailscale_peers "0" while tailscale_state had 3 nodes
#   D) lowercase `peer` map -> peers 2 (older tailscale back-compat)
#   E) uptime seconds (number) + human + last_boot present in the feed
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

# hermetic tailscale stub: `status --json` -> fixture, plain `status` ->
# text lines. Fixture key (Peer|peer) varies by tailscale version; Self is
# a separate key, so counting the Peer map excludes self by construction.
peer_case() { # $1 = fixture key, $2 = label
 cat > "$sb/ts.json" <<EOF
{"BackendState": "Running",
 "Self": {"HostName": "selfhost", "TailscaleIPs": ["100.64.0.1"]},
 "$1": {"nodekey:a": {"HostName": "peerA", "online": true},
        "nodekey:b": {"HostName": "peerB", "online": false}}}
EOF
 cat > "$sb/bin/tailscale" <<EOF
#!/bin/sh
[ "\$1" = "status" ] || exit 1
if [ "\$2" = "--json" ]; then cat "$sb/ts.json"
else printf '100.64.0.1 selfhost t@ linux -\n100.64.0.2 peerA t@ linux -\n100.64.0.3 peerB t@ linux offline\n'
fi
EOF
 chmod +x "$sb/bin/tailscale"
 PATH="$sb/bin:$PATH" STATE_FILE="$sb/STATE.md" AWARENESS_OUT="$sb/system.json" \
  PROBE_ROUTE_CONF="$sb/closed.conf" timeout 60 bash "$root/jobs/system-awareness.sh" \
  >/dev/null 2>&1
 need [ "$(jq -r '.net.tailscale_peers' "$sb/system.json")" = "2" ]
 need [ "$(jq -r '.net.tailscale_state' "$sb/system.json")" != "unknown" ]
 ok "$2"
}

peer_case Peer "C: capitalized Peer map -> peers 2, self excluded"
peer_case peer "D: lowercase peer map -> peers 2"

# E) uptime + last_boot: numeric seconds, non-empty human + boot stamp.
#    (the case-D tailscale stub is still on PATH -> run stays hermetic)
PATH="$sb/bin:$PATH" STATE_FILE="$sb/STATE.md" AWARENESS_OUT="$sb/system.json" \
 PROBE_ROUTE_CONF="$sb/closed.conf" timeout 60 bash "$root/jobs/system-awareness.sh" \
 >/dev/null 2>&1
need [ "$(jq -r '.uptime.seconds | type' "$sb/system.json")" = "number" ]
need [ "$(jq -r '.uptime.human | length > 0' "$sb/system.json")" = "true" ]
need [ "$(jq -r '.uptime.last_boot | length > 0' "$sb/system.json")" = "true" ]
ok "E: uptime seconds/human + last_boot present"

echo "PASS"
