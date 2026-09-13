<!-- plan: status=parked risk=normal accepted=2026-09-12T21:03:16Z routed-from=patrol:services  cause=obsolete disposed=2026-09-13T00:00:13Z reason=identity re-occurred 3 times without landing; operator escalation stands -->
# 2026-09-12 — routed candidate

Routed by scripts/router-tick.py from alert identity `patrol:services`
at 2026-09-12T21:00:23Z. Alert text: patrol services: service-down on comfyui -- http://127.0.0.1:8188/ unreachable: URLError ×4

## Steps

- [ ] Delve: open research subject fail-20260912-patrol-services for patrol:services; record disposition; then fix or park
      Verification: research subject fail-20260912-patrol-services present in research-subjects.txt with a recorded disposition; alert fixed or parked

## Occurrences

- 2026-09-12T22:00:49Z re-occurred (dedup window expired)
- 2026-09-12T23:00:49Z re-occurred (dedup window expired)
- 2026-09-13T00:00:13Z re-occurred (dedup window expired)
