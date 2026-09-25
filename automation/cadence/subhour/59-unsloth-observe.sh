#!/usr/bin/env bash
# 59-unsloth-observe -- opportunistic server_observed refresh (2026-09-13,
# per-model context registry): if the unsloth-studio loaded model changed
# since the registry row last recorded it, capture its true context window.
# Signal order: webapp /api/inference/status > journal n_ctx line > one
# oversized-prompt 400 probe. Fail-closed: exits 0 in every expected path.
# usage: cadence/subhour/59-unsloth-observe.sh   (via cadence-tick.sh TIER=subhour)
set -u
# self-gate (31-heartbeat stamp pattern): one real run per 1800s - the
# former 30m beat, paced by stamp since the 2026-09-24 tier collapse.
STAMP="/tmp/.hngh-cadence-59-unsloth-observe-last"; now="$(date +%s)"
last="$(cat "$STAMP" 2>/dev/null || printf '0')"; last="${last//[!0-9]/}"; last="${last:-0}"
[ $((now - last)) -ge 1800 ] || exit 0
printf '%s\n' "$now" >"$STAMP"

. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"

python3 "$AUTOMATION_ROOT/jobs/unsloth-contexts.py" --observe 2>&1 |
  while IFS= read -r line; do echo "unsloth-observe: $line"; done
exit 0
