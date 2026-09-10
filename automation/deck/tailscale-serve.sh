#!/usr/bin/env bash
# Deck-side, operator-run only: enable HTTPS serve of the dashboard :8890.
# Never invoked by automation (no-daemon rule) -- a human double-clicks or
# runs this on the deck.
set -u

PORT=8890

TS="$(command -v tailscale || true)"
if [ -z "$TS" ]; then
    echo "tailscale not found. On SteamOS install it first (flatpak or" >&2
    echo "the userspace tarball per ~/hngh-deck setup)." >&2
    exit 1
fi

if ! "$TS" status >/dev/null 2>&1; then
    echo "tailscale is not running/logged in. Start the tailscaled user" >&2
    echo "service and run 'tailscale login' first." >&2
    exit 1
fi

if "$TS" serve status 2>/dev/null | grep -q ":$PORT"; then
    echo "Port $PORT is already served. Nothing to do."
    "$TS" serve status
    exit 0
fi

if ! sudo "$TS" serve --bg "$PORT"; then
    echo "tailscale serve failed (sudo cancelled or error)." >&2
    exit 1
fi

echo "Serving. HTTPS URL:"
"$TS" serve status
