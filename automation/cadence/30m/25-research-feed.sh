#!/usr/bin/env bash
# cadence/30m — research feed refresh (hngh research queue -> dashboard
# research.json for the Research tab). Read-only probe, fail-closed; 30m
# cadence keeps the tab fresh without hammering the kernel repo.
root="$(cd "$(dirname "$0")/../.." && pwd)"
exec "$root/jobs/research-feed.py"
