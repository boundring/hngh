#!/usr/bin/env bash
# cadence/30m — research feed refresh (hngh research queue -> dashboard
# research.json for the Research tab). Read-only probe, fail-closed; 30m
# cadence keeps the tab fresh without hammering the kernel repo.
exec /home/bricker/Projects/etc/hngh-automation/jobs/research-feed.py
