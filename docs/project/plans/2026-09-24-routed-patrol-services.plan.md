<!-- plan: status=parked risk=normal accepted=2026-09-24T13:04:02Z routed-from=patrol:services  cause=obsolete disposed=2026-09-24T14:00:13Z reason=identity re-occurred 3 times without landing; operator escalation stands -->
# 2026-09-24 — routed candidate

Routed by scripts/router-tick.py from alert identity `patrol:services`
at 2026-09-24T10:00:13Z. Alert text: patrol services: service-down on comfyui -- http://127.0.0.1:8188/ unreachable: URLError

## Steps

- [ ] Delve: open research subject fail-20260924-patrol-services for patrol:services; record disposition; then fix or park
      Verification: research subject fail-20260924-patrol-services present in research-subjects.txt with a recorded disposition; alert fixed or parked

## Occurrences

- 2026-09-24T11:00:13Z re-occurred (dedup window expired)
- 2026-09-24T12:00:37Z re-occurred (dedup window expired)
- 2026-09-24T14:00:13Z re-occurred (dedup window expired)
