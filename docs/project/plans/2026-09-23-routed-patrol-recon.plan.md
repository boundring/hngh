<!-- plan: status=parked risk=normal accepted=2026-09-23T10:03:29Z routed-from=patrol:recon  cause=obsolete disposed=2026-09-23T13:00:13Z reason=identity re-occurred 3 times without landing; operator escalation stands -->
# 2026-09-23 — routed candidate

Routed by scripts/router-tick.py from alert identity `patrol:recon`
at 2026-09-23T10:00:13Z. Alert text: patrol recon: label-content-divergence on kernel -- 5a3ebf26a1b7 label 8095524e0815 != recomputed 7827231496b1 over the commit's own paths+bytes ×2

## Steps

- [ ] Delve: open research subject fail-20260923-patrol-recon for patrol:recon; record disposition; then fix or park
      Verification: research subject fail-20260923-patrol-recon present in research-subjects.txt with a recorded disposition; alert fixed or parked

## Occurrences

- 2026-09-23T11:00:13Z re-occurred (dedup window expired)
- 2026-09-23T12:00:13Z re-occurred (dedup window expired)
- 2026-09-23T13:00:13Z re-occurred (dedup window expired)
- 2026-09-23T14:00:13Z re-occurred (dedup window expired)
