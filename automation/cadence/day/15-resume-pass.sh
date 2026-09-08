#!/usr/bin/env bash
# cadence/day — cold-resume sweep: the cadence tier only fires while the
# machine is up, so downtime never runs its beats. jobs/resume-pass.sh
# --sweep decides for itself (last STATE crumb older than resume-gap-hours
# means the box was down) and writes logs/resume-<date>.md once.
root="$(cd "$(dirname "$0")/../.." && pwd)"
bash "$root/jobs/resume-pass.sh" --sweep
exit 0
