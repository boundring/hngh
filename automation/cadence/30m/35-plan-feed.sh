#!/usr/bin/env bash
# cadence/30m — plan feed refresh (hngh docs/project/plans ledger ->
# dashboard/plans.json for the dashboard). Read-only probe, fail-closed.
root="$(cd "$(dirname "$0")/../.." && pwd)"
exec "$root/jobs/plan-feed.py"
