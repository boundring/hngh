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
- [x] Slice A: bili S1 telemetry (telemetry.py FIRST, then model.sh),
      S2 registry row + patrol breadcrumb, S3 record
      Verification: see plans/README verification contract; kernel
      `make test` green.
      Executed 2026-09-27: S1 tokens_cached capture landed with the
      designed ordering (telemetry.py column + DATA_FIELDS + idempotent
      ALTER + INSERT first; then model.sh TOKCACHED_FILE extraction in
      _post_chat + unsloth_attempt and the _model_emit --data forward
      with the lone-cached case and tmp clearing); S2 the bili row in
      hngh-services.tsv (operator-run, url-less, service-mgmt-inert)
      plus the security-check bili=$b_ok breadcrumb; new hermetic test
      tests/test-slice-a-bili-surface.sh (9 checks) wired into the
      automation Makefile, affected model-chain leg suites re-run green
      (xiaomi, kimi, ocgo, pin-routing, deck, zai-proxy,
      remote-token-mode) and test-hngh-services.py green; S3 the
      decision record docs/records/2026-09-13-bili-hngh-integration.md.
      Automation commit 6764d00b (pushed); the docs record rides this
      ceremony commit.
- [x] Slice B: spawn-path matrix promoted + tokens_cached backfill
      Verification: see plans/README verification contract; kernel
      `make test` green.
      Executed 2026-09-27: the spawn-path matrix is promoted into
      governed-fleet.md section 2 (five verified rows: interactive
      omp/pi cert-MITM, machine-launch omp bctx-wrapped fail-open,
      opencode executor env-only MITM never writing the config layer,
      jcode stdio direct-with-envs-dropped, chain beats + local legs
      direct curl) plus the two invariants (fail-open everywhere; one
      telemetry schema). tokens_cached backfill landed across the
      remaining legs: jobs/session-cost.py sums usage.cacheRead
      (read side only) into the emitted row, jobs/jcode-session-cost.py
      captures cache_read= in the API-call line, and
      jobs/ocgo-attribution.py lands the opencode stream's cache
      shapes (tokens.cache.read/cacheRead/cache_read) on the same
      ocgo-agent row. Hermetic proof: new
      tests/test-session-cost-cache.py (2 checks, wired into the
      automation Makefile) plus the new cache-shape emitter test in
      tests/test-ocgo-launch.py; both suites green (37 ocgo, 4 jcode,
      2 session-cost-cache). Free-commit automation change; the
      gcode-session-cost live-log format drift (today's logs lack the
      "API call complete" lines entirely) is a separate backlog lane,
      out of this slice.
<!-- plan-note: 2026-09-27 slice C split for 1800s executor budget (blocker blk-20260927) -->
- [ ] Slice C1: witnessed clean delegation cycle (spawn one session,
      observe completion, record ledger evidence)
      Verification: the ledger record shows one clean completion.
- [ ] Slice C2: seeded stall auto-replace observation, single 5m
      subhour tick scope
      Verification: the ledger record shows the stall detected and
      the session auto-replaced.
- [ ] Slice C3: supervision residue check + kernel `make test` green
      (separate session)
      Verification: no supervision residue; kernel `make test` green.
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
