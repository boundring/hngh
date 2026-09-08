#!/usr/bin/env bash
# cadence/hour — dashboard self-review tick. Read-only probe of the served
# dashboard (hngh-dashboard.service, http://127.0.0.1:8890) + its feeds;
# findings land via the hngh report-queue with dedup identities, all-clear
# ticks are silent. Mounted per operator directive 2026-08-27.
exec /home/bricker/Projects/etc/hngh-automation/jobs/dashboard-self-review.py
