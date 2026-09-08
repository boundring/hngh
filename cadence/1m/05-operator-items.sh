#!/usr/bin/env bash
# cadence/1m — operator-items feed tick: keeps the handled/dismissed
# lifecycle fresh (dashboard-self-review flags operator-items.json stale
# beyond 3x the 1m tier otherwise). Fail-closed: exit 0 always.
exec /home/bricker/Projects/etc/hngh-automation/jobs/operator-items-feed.py
