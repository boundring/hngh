#!/usr/bin/env bash
# shellcheck disable=SC1090
set -euo pipefail

WATCHER=${WATCHER:-$HOME/.local/bin/hngh-live-watch}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

source "$WATCHER"
CLAIMS_PATH="$TMP/claims.lisp"

cat > "$CLAIMS_PATH" <<'EOF'
CLAIMS REGISTER
1. CLAIM: script:hngh-live-watch cibo watcher-code-build 15:20
2. CLAIM: doc:durable-records seu design-home 15:20
3. CLAIM: card:104 seu RELEASED 17:05
CLAIM-RELEASE: card:104 seu ride-along-design 17:05
EOF

claims=$(live_claims)
[[ "$claims" == *"script:hngh-live-watch cibo watcher-code-build 15:20"* ]]
[[ "$claims" == *"doc:durable-records seu design-home 15:20"* ]]
[[ "$claims" != *"card:104"* ]]

: > "$CLAIMS_PATH"
[[ "$(live_claims)" == "none" ]]

echo 'live-claims fixture: PASS'
