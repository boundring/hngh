<!-- plan: status=parked risk=normal accepted=- routed-from=patrol:journal-error  cause=obsolete disposed=2026-09-15T08:00:39Z reason=identity re-occurred 3 times without landing; operator escalation stands  cause=obsolete disposed=2026-09-16T15:00:40Z reason=identity re-occurred 5 times without landing; operator escalation stands  cause=obsolete disposed=2026-09-18T21:00:13Z reason=identity re-occurred 6 times without landing; operator escalation stands  cause=obsolete disposed=2026-09-24T18:00:37Z reason=identity re-occurred 7 times without landing; operator escalation stands -->
# 2026-09-15 — routed candidate

Routed by scripts/router-tick.py from alert identity `patrol:journal-error`
at 2026-09-15T05:00:25Z. Alert text: patrol journal-error: unit-not-practiced on unit-failed -- 1.2-org.freedesktop.Notifications@2.service failed; not in the restart allowlist, no auto-action: dbus-:1.2-org.freedesktop.Notifications@2.service: Failed with result 'exit-code'. ×2

## Steps

- [ ] Delve: open research subject fail-20260915-patrol-journal-error for patrol:journal-error; record disposition; then fix or park
      Verification: research subject fail-20260915-patrol-journal-error present in research-subjects.txt with a recorded disposition; alert fixed or parked

## Occurrences

- 2026-09-15T06:00:39Z re-occurred (dedup window expired)
- 2026-09-15T07:00:39Z re-occurred (dedup window expired)
- 2026-09-15T08:00:39Z re-occurred (dedup window expired)
- 2026-09-15T09:00:39Z re-occurred (dedup window expired)
- 2026-09-16T15:00:40Z re-occurred (dedup window expired)
- 2026-09-18T21:00:13Z re-occurred (dedup window expired)
- 2026-09-24T18:00:37Z re-occurred (dedup window expired)
