#!/usr/bin/env bash
# cadence/30m — schedule feed refresh (systemd timers + cadence tiers + gantt
# lanes -> dashboard/schedule.json for the Schedule tab). Read-only probe,
# fail-closed; 30m cadence matches timer drift timescales.
exec /home/bricker/Projects/etc/hngh-automation/jobs/schedule-feed.py
