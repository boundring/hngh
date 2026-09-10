#!/usr/bin/env bash
# Deck-side, operator-run only: trigger the desktop's `tailscale serve
# --bg 8890` over ssh (the dashboard binds on the desktop, so serve must
# run there -- the deck's tailscale is userspace/SOCKS5 and serves
# nothing). Never invoked by automation (no-daemon rule) -- a human
# double-clicks or runs this on the deck.
set -u

PORT=8890
TS_SOCK="$HOME/.local/share/tailscaled/tailscaled.sock"

TS="$(command -v tailscale || true)"
if [ -z "$TS" ]; then
    echo "tailscale not found. On SteamOS install it first (flatpak or" >&2
    echo "the userspace tarball per ~/hngh-deck setup)." >&2
    exit 1
fi

if ! "$TS" --socket "$TS_SOCK" status >/dev/null 2>&1; then
    echo "tailscale is not running/logged in ON THIS DECK. Start the" >&2
    echo "tailscaled user service and run 'tailscale login' first." >&2
    exit 1
fi

if ssh hngh-desktop tailscale serve status 2>/dev/null | grep -q ":$PORT"; then
    echo "Port $PORT is already served on the desktop. Nothing to do."
    ssh hngh-desktop tailscale serve status
    exit 0
fi

if ! ssh -t hngh-desktop sudo tailscale serve --bg "$PORT"; then
    echo "desktop unreachable -- check tailscale login on both ends." >&2
    exit 1
fi

echo "Serving. HTTPS URL:"
ssh hngh-desktop tailscale serve status
