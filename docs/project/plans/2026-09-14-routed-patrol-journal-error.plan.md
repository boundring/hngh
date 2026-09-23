<!-- plan: status=expired risk=normal accepted=- routed-from=patrol:journal-error  cause=obsolete disposed=2026-09-16T14:00:39Z reason=identity re-occurred 3 times without landing; operator escalation stands  cause=obsolete disposed=2026-09-18T17:00:13Z reason=identity re-occurred 4 times without landing; operator escalation stands  cause=obsolete disposed=2026-09-22T03:00:23Z reason=identity re-occurred 5 times without landing; operator escalation stands -->
# 2026-09-14 — routed candidate

Routed by scripts/router-tick.py from alert identity `patrol:journal-error`
at 2026-09-14T02:00:20Z. Alert text: patrol journal-error: propose on kglobalaccel-dead -- 1 hit(s); NOT auto-applied (live-session fix, operator eyes): systemctl --user restart plasma-kglobalaccel.service -- latest: Couldn't start kglobalaccel from org.kde.kglobalaccel.service: QDBusError("org.freedesktop.DBus.Error.ServiceU ×2

## Steps

- [ ] Delve: open research subject fail-20260914-patrol-journal-error for patrol:journal-error; record disposition; then fix or park
      Verification: research subject fail-20260914-patrol-journal-error present in research-subjects.txt with a recorded disposition; alert fixed or parked

## Occurrences

- 2026-09-14T03:00:39Z re-occurred (dedup window expired)
- 2026-09-16T13:00:39Z re-occurred (dedup window expired)
- 2026-09-16T14:00:39Z re-occurred (dedup window expired)
- 2026-09-18T17:00:13Z re-occurred (dedup window expired)
- 2026-09-22T03:00:23Z re-occurred (dedup window expired)
