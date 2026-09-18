<!-- plan: status=parked risk=normal accepted=- routed-from=patrol:journal-error  cause=obsolete disposed=2026-09-18T20:00:13Z reason=identity re-occurred 3 times without landing; operator escalation stands -->
# 2026-09-16 — routed candidate

Routed by scripts/router-tick.py from alert identity `patrol:journal-error`
at 2026-09-16T14:00:39Z. Alert text: patrol journal-error: unclaimed-err on unknown-journal-error -- 9 err+ line(s) no signature claims; latest: Bluetooth: hci0: ACL packet for unknown connection handle 3837 ×3

## Steps

- [ ] Delve: open research subject fail-20260916-patrol-journal-error for patrol:journal-error; record disposition; then fix or park
      Verification: research subject fail-20260916-patrol-journal-error present in research-subjects.txt with a recorded disposition; alert fixed or parked

## Occurrences

- 2026-09-18T18:00:13Z re-occurred (dedup window expired)
- 2026-09-18T19:00:27Z re-occurred (dedup window expired)
- 2026-09-18T20:00:13Z re-occurred (dedup window expired)
