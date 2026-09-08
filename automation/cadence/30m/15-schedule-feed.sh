#!/usr/bin/env bash
# cadence/30m — schedule feed refresh (systemd timers + cadence tiers + gantt
# lanes -> dashboard/schedule.json for the Schedule tab). Read-only probe,
# fail-closed; 30m cadence matches timer drift timescales.
root="$(cd "$(dirname "$0")/../.." && pwd)"
exec "$root/jobs/schedule-feed.py"
