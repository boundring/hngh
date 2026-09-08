#!/usr/bin/env bash
# cadence/30m — plan feed refresh (hngh docs/project/plans ledger ->
# dashboard/plans.json for the dashboard). Read-only probe, fail-closed.
exec /home/bricker/Projects/etc/hngh-automation/jobs/plan-feed.py
