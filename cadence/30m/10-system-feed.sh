#!/usr/bin/env bash
# cadence/30m — system-ops feed refresh (CachyOS package/unit/disk/journal
# observability -> dashboard/system-ops.json for the System tab). Read-only
# probe, fail-closed per source; 30m cadence is ample for update/unit drift.
exec /home/bricker/Projects/etc/hngh-automation/jobs/system-feed.py
