#!/usr/bin/env bash
# cadence/30m — plan feed refresh (hngh docs/project/plans ledger ->
# dashboard/plans.json for the dashboard). Read-only probe, fail-closed.
exec ~/Projects/etc/hngh-automation/jobs/plan-feed.py
