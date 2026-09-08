#!/usr/bin/env bash
# cadence/hour — programmatic UI audit: axe-core + display-register rules
# over the served dashboard (jobs/ui-audit.mjs; spec §7 + Winamp floor).
# Findings land in the hngh report ledger with per-rule dedup identities;
# fail-closed exit 0 — the audit never fails the tick.
root="$(cd "$(dirname "$0")/../.." && pwd)"
exec node "$root/jobs/ui-audit.mjs"
