<!-- plan: status=executed risk=normal accepted=2026-09-11T07:02:25Z routed-from=overnight:plan-accept-gate:kernel -->
# 2026-09-11 — routed candidate

Routed by scripts/router-tick.py from alert identity `overnight:plan-accept-gate:kernel`
at 2026-09-11T07:00:49Z. Alert text: plan acceptance blocked: kernel make test FAILED (rc=2) ×5

## Steps

- [x] Delve: open research subject fail-20260911-overnight-plan-accept-gate-kernel for overnight:plan-accept-gate:kernel; record disposition; then fix or park
      Verification: research subject fail-20260911-overnight-plan-accept-gate-kernel present in research-subjects.txt with a recorded disposition; alert fixed or parked
      Resolved 2026-09-14 (overnight-lead, fixed not parked): subject present with adopted dispositions recorded 2026-09-11 (research-dispositions.tsv rows 44-45; doc docs/research/2026-09-11-fail-20260911-overnight-plan-accept-gate-kernel.md) -- root cause: unlabeled omp-bridge commits a2f4d0e/31768d2 tripped the loop-history guard; fixed via KNOWN_EXEMPTIONS (2026-09-06 decisions.md precedent) with the final omp-bridge re-bound through the certificate ceremony (candidate f2f04e3, no history rewrite). Alert fixed: make test re-verified green this session 2026-09-14 (2894 checks, 28s); identity silent since 2026-09-11T09:00:49Z -- the 09-12/09-13 re-routes were the transient stale-red-crumb flap, closed by the slow-units envelope dropin (2362f89, adopted row 102). Sibling fail-20260910-overnight-plan-accept-gate-kernel killed 2026-09-14 (d825aa0).

## Occurrences

- 2026-09-11T08:00:49Z re-occurred (dedup window expired)
- 2026-09-11T09:00:49Z re-occurred (dedup window expired)
