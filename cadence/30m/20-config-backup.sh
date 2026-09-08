#!/usr/bin/env bash
# cadence/30m — hngh-governed config backup (agent-configs lane): all-sources
# parity scan fail-closed, secret-scan, commit, then push to the lane's
# declared remote. The job self-reports failures as alert report rows, so the
# drop-in exits with the job's rc (cadence-tick tolerates nonzero drop-ins
# via its dropin-fail breadcrumb).
job="${AUTOMATION_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}/jobs/config-backup.sh"
if [ ! -x "$job" ]; then
  echo "config-backup drop-in: $job missing or not executable" >&2
  exit 1
fi
exec "$job" agent-configs --mode push
