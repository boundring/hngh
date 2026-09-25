<!-- plan: status=parked risk=normal accepted=- routed-from=dash-selfreview:summary  cause=obsolete disposed=2026-09-25T02:00:13Z reason=identity re-occurred 3 times without landing; operator escalation stands -->
# 2026-09-18 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:summary`
at 2026-09-18T12:31:28Z. Alert text: [dash-selfreview] summary: 4 findings (4 unacceptable-now, 0 acceptable-for-now)

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green

## Occurrences

- 2026-09-25T00:00:37Z re-occurred (dedup window expired)
- 2026-09-25T01:00:13Z re-occurred (dedup window expired)
- 2026-09-25T02:00:13Z re-occurred (dedup window expired)
