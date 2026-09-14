#!/usr/bin/env bash
# 59-unsloth-observe -- opportunistic server_observed refresh (2026-09-13,
# per-model context registry): if the unsloth-studio loaded model changed
# since the registry row last recorded it, capture its true context window.
# Signal order: webapp /api/inference/status > journal n_ctx line > one
# oversized-prompt 400 probe. Fail-closed: exits 0 in every expected path.
# usage: cadence/30m/59-unsloth-observe.sh   (via cadence-tick.sh TIER=30m)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"

python3 "$AUTOMATION_ROOT/jobs/unsloth-contexts.py" --observe 2>&1 |
  while IFS= read -r line; do echo "unsloth-observe: $line"; done
exit 0
