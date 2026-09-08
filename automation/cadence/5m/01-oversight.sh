#!/usr/bin/env bash
# cadence/5m — oversight tick (procedural every fire; agentic gated inside).
root="$(cd "$(dirname "$0")/../.." && pwd)"
exec "$root/jobs/oversight-tick.sh"
