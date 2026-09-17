<!-- plan: status=parked risk=normal accepted=- routed-from=research-beat:review-unparseable  cause=obsolete disposed=2026-09-16T04:00:39Z reason=identity re-occurred 3 times without landing; operator escalation stands  cause=obsolete disposed=2026-09-17T08:00:39Z reason=identity re-occurred 4 times without landing; operator escalation stands -->
# 2026-09-13 — routed candidate

Routed by scripts/router-tick.py from alert identity `research-beat:review-unparseable`
at 2026-09-13T22:00:39Z. Alert text: research review verdict unparseable for fail-20260913-Are-there-multiple-CLI-invocation-sites- (model deck:deck-7b)

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green

## Occurrences

- 2026-09-13T23:00:39Z re-occurred (dedup window expired)
- 2026-09-16T03:00:39Z re-occurred (dedup window expired)
- 2026-09-16T04:00:39Z re-occurred (dedup window expired)
- 2026-09-17T08:00:39Z re-occurred (dedup window expired)
