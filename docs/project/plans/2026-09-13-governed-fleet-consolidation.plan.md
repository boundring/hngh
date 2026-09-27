<!-- plan: status=accepted risk=normal accepted=2026-09-22T13:03:06Z -->
# The Governed Fleet -- ratify and land the stages 3+4 consolidation

Proposed via `omp-bridge --propose` (omp session propose surface;
see docs/project/plans/README.md).

Ratified by the operator on 2026-09-13 (all four section-9 losses of
docs/design/governed-fleet.md accepted, plus the slice-G amendment).
Design reference: docs/design/governed-fleet.md (sections 6, 7, 8, 10).

## Steps

- [x] Ratification record
      docs/records/2026-09-13-governed-fleet-consolidation.md; edit
      roadmap.md per governed-fleet.md section 7 (kernel docs;
      ceremony commit; make test green)
      Verification: `ls docs/records/2026-09-13-governed-fleet-consolidation.md`
      succeeds with the roadmap.md stage-3 edit landed; kernel `make test`
      green.
- [x] Flip absorbed/landed backlog rows per governed-fleet.md
      section 8 (automation free commit)
      Verification: see plans/README verification contract; kernel
      `make test` green.
      Executed 2026-09-27: every §8 row was already resolved by the
      2026-09-24/25 passes (strikes + queue flips: governance-vocabulary,
      cadence-continuum, push-self-sufficiency, credential-rotation-auto,
      node-lattice-admission, key-rotation-freshness) except one leftover:
      queue row activity-cadence (DROP class, ratified "landed as stage 0/1
      scope; flip done") was still queued — flipped done 2026-09-27 with the
      B3-collapse evidence cited. The remaining un-flipped ABSORB rows are
      correctly pending their slices (C/D/E/F) — flipping them now would
      falsify evidence; the gate watch-test flake stays an ordinary SMALL
      backlog lane; the one-shot bili row has no backlog row (refused by
      design, nothing to flip).
- [ ] Slice A: bili S1 telemetry (telemetry.py FIRST, then model.sh),
      S2 registry row + patrol breadcrumb, S3 record
      Verification: see plans/README verification contract; kernel
      `make test` green.
- [ ] Slice B: spawn-path matrix promoted + tokens_cached backfill
      Verification: see plans/README verification contract; kernel
      `make test` green.
- [ ] Slice C: witnessed delegation cycle + seeded stall auto-replace
      (evidence: ledger/dashboard record)
      Verification: the ledger/dashboard record exists; kernel
      `make test` green.
- [ ] Slice D: governed package upgrade through the certificate loop
      (evidence: certificate + commit in git log)
      Verification: the certificate + commit appear in git log; kernel
      `make test` green.
- [ ] Slice E: credential-seam sweep + model-tier refresh cadence
      Verification: see plans/README verification contract; kernel
      `make test` green.
- [ ] Slice F: node-lattice admission -- one peer admitted through the
      same gates (federation exit)
      Verification: see plans/README verification contract; kernel
      `make test` green.
- [ ] Slice G: operations knowledge-graph surface in the dashboard --
      3D WebGL view of the section-2 registries, live-fed, 2D/static
      fallback (NOT exit-bearing)
      Verification: the dashboard serves the knowledge-graph view with
      the 2D/static fallback; kernel `make test` green.
- [ ] Roadmap stage 3 row flips to done when all ten invariants hold
      under standing guards and patrols
      Verification: `scripts/omp-bridge --plan-status
      governed-fleet-consolidation` reports the landed state; kernel
      `make test` green.

Verification: make test green in both repos before the ceremony
commit; roadmap.md table rows keep consistent pipe field counts;
omp-bridge --plan-status governed-fleet-consolidation reports the
landed state.
