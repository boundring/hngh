#!/usr/bin/env bash
# cadence/1m — sessions-feed tick. Rebuilds dashboard/sessions.json every
# minute so the session observatory's transcript tails grow steadily between
# the hourly refresh-dashboard runs (readout.json roster may be an hour old;
# the transcript tails are re-read fresh from the stores each tick).
# Display layer only — never governance input. Timer units untouched.
exec /home/bricker/Projects/etc/hngh-automation/jobs/sessions-feed.py
