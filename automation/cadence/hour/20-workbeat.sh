#!/usr/bin/env bash
# cadence/hour — hourly adversarial workbeat. Checks accepted plans, the
# queue, and research lines; kick-starts bounded delegated sessions;
# parks critical items with operator-facing alerts; never blocks on a
# human. All guardrails live inside the cycle: flock serialization,
# daily session cap, budget counting, critical-path audit, research
# filler when nothing else is due.
root="$(cd "$(dirname "$0")/../.." && pwd)"
exec "$root/scripts/overnight-cycle.sh"
