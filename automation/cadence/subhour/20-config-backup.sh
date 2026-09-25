#!/usr/bin/env bash
# cadence/subhour — hngh-governed config backup (agent-configs lane): all-sources
# parity scan fail-closed, secret-scan, commit, then push to the lane's
# declared remote. The job self-reports failures as alert report rows, so the
# drop-in exits with the job's rc (cadence-tick tolerates nonzero drop-ins
# via its dropin-fail breadcrumb).
# self-gate (31-heartbeat stamp pattern): one real run per 1800s - the
# former 30m beat, paced by stamp since the 2026-09-24 tier collapse.
STAMP="/tmp/.hngh-cadence-20-config-backup-last"; now="$(date +%s)"
last="$(cat "$STAMP" 2>/dev/null || printf '0')"; last="${last//[!0-9]/}"; last="${last:-0}"
[ $((now - last)) -ge 1800 ] || exit 0
printf '%s\n' "$now" >"$STAMP"

job="${AUTOMATION_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}/jobs/config-backup.sh"
if [ ! -x "$job" ]; then
  echo "config-backup drop-in: $job missing or not executable" >&2
  exit 1
fi
exec "$job" agent-configs --mode push
