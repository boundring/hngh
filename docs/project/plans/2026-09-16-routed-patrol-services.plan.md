<!-- plan: status=executed risk=normal accepted=2026-09-18T01:41:57Z routed-from=patrol:services -->
# 2026-09-16 — routed candidate

Routed by scripts/router-tick.py from alert identity `patrol:services`
at 2026-09-16T22:00:18Z. Alert text: patrol services: service-down on comfyui -- http://127.0.0.1:8188/ unreachable: URLError

## Steps

- [x] Delve: open research subject fail-20260916-patrol-services for patrol:services; record disposition; then fix or park
      Verification: research subject fail-20260916-patrol-services present in research-subjects.txt with a recorded disposition; alert fixed or parked
      — executed 2026-10-11: subject opened + disposition "fixed" recorded
      (automation research-dispositions.tsv); root cause = check_service_health
      probing the fixed health-url of an automation-managed TRANSIENT row
      (comfyui); fix = skip managed-by automation/* rows, automation commit
      b6f4f314 (pushed), failing-first test + suite 54/54, live check quiet;
      record docs/research/2026-10-11-fail-20260916-patrol-services.md.
      Identity itself had already hit router re-route bound 3 (2026-10-03,
      14 occurrences); cause closed so it cannot re-fire.
