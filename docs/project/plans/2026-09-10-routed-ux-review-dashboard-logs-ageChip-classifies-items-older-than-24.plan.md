<!-- plan: status=parked risk=normal accepted=2026-09-10T10:01:05Z routed-from=ux-review:dashboard-logs:ageChip-classifies-items-older-than-24  cause=obsolete disposed=2026-09-10T13:00:18Z reason=identity re-occurred 3 times without landing; operator escalation stands -->
# 2026-09-10 — routed candidate

Routed by scripts/router-tick.py from alert identity `ux-review:dashboard-logs:ageChip-classifies-items-older-than-24`
at 2026-09-10T10:00:18Z. Alert text: `ageChip` classifies items older than 24 hours as `stale`, but `STALE_MS` is defined as 5 minutes — inconsistent time thresholds confuse operator urgency — hngh-automation.js fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green

## Occurrences

- 2026-09-10T11:00:18Z re-occurred (dedup window expired)
- 2026-09-10T12:00:18Z re-occurred (dedup window expired)
- 2026-09-10T13:00:18Z re-occurred (dedup window expired)
- 2026-09-10T14:00:18Z re-occurred (dedup window expired)
- 2026-09-10T15:00:18Z re-occurred (dedup window expired)
