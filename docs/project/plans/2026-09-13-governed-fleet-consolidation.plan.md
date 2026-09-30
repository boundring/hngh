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
- [x] Slice C1: witnessed clean delegation cycle (spawn one session,
      observe completion, record ledger evidence)
      Verification: the ledger record shows one clean completion.
      Executed 2026-09-28: one delegated session spawned through the
      fleet's own path (automation/lib/launch-session.sh, slug
      slicec1-witness, opencode executor on the opencode-go quota leg,
      TIMEOUT_S=600) completed rc=0 disposition=complete in about 100s
      wall clock: bridge receipts creation 2026-09-28T03:16:26Z ->
      admission (transport worker, scope repository, route model) ->
      close state cancelled (the spine-complete mapping, no unclosed
      run residue this time); budget row 2026-09-28T03:17:55Z in
      automation/logs/budget.md; spawn log
      automation/logs/overnight-slicec1-witness-20260927T231627.log
      shows the bounded assignment executed verbatim
      (tests/test-agent-supervision.py: Ran 9 tests in 1.092s, OK,
      exit 0; no edits, no commits, no further spawns); handoff rows
      appended to automation/agent-handoffs.md. The prior 2026-09-27
      slicec-witness run had run two suites instead of spawning, so
      the cycle itself stayed unwitnessed until now.
      Witness finding (recorded, not fixed): the cause classifier
      stamped cause=bad-execution on this rc=0 log because
      lib/causes.sh keyword-matches the log body and the spawned
      session correctly recited the lessons bestiary (steer away from
      bad-execution runs) - a compliant session gets stamped with the
      class it avoided; some of yesterday's bad-execution lessons may
      share this mechanism. Ordinary backlog lane, out of this slice.
- [x] Slice C2: seeded stall auto-replace observation, single 5m
      subhour tick scope
      Verification: the ledger record shows the stall detected and
      the session auto-replaced.
      Executed 2026-09-29 (hermetic single tick): invoked
      jobs/agent-supervision.py directly (never the cadence wrapper,
      never the 300s self-gate stamp) against all-temporary fixture
      surfaces reachable only through the documented env seams:
      SUPERVISION_STATE pre-seeded with run-1 misses:1 (the steer
      stamp from the pre-observation missed tick), stub-binary
      hngh/omp-bridge/report-queue logging argv, record.lisp fixture
      stale by 1h. One invocation: stall detected (misses -> 2),
      die_session fired on the bridge source, replace_stalled_bridge_run
      executed close-run run-1 dead + record rotation into
      20260929T163436Z-run-1 + exactly one omp-bridge --run-start
      auto-replace re-provision. Assertion evidence: tick rc=0;
      fixture handoffs die row 'session-drop | ... | supervision|run-1 |
      dead: stalled past 2 ticks cause=unclassified'; argv log line
      '--run-start auto-replace seeded stall observation slice c2'
      (count 1); store root carries no record.lisp, one rotated
      subdir; the permanent evidence row is appended to
      automation/agent-handoffs.md (overnight-lead | governed-fleet|
      slice-c2 row, the C1 pattern). Advisory: cause=unclassified is
      the absent SUPERVISION_CAUSES_SH stub, matching the blk-20260928
      live observation. No real bridge store, dashboard state, real
      agent-handoffs death rows, beat-blockers.tsv, or cadence state
      touched; no production edits, no spawned session, no restarts.
      C3 owns the residue check.
- [x] Slice C3: supervision residue check + kernel `make test` green
      (separate session)
      Verification: no supervision residue; kernel `make test` green.
      Executed 2026-09-29: the fixed-pass residue sweep is clean - the
      only slice-c2 rows in agent-handoffs.md are the intended evidence
      pair (:1690 witness row, :1693 respawn-refused), the rotation
      marker 20260929T163436Z appears exactly once (inside the :1690
      row), dashboard/agent-supervision-state.json, state/
      beat-blockers.tsv, and kernel scripts carry zero fixture-marker
      hits, and the real store has no slice-c-shaped subdir beyond the
      2026-09-27 positive controls and no rotated marker; nothing was
      cleaned or rewritten. Kernel `make test` green rc=0 with 2954
      checks passed and the asdf load-system leg clean (second pass
      authoritative; the first pass's output was lost to a capture
      slip and left no failure signal, so the gate was re-verified once
      rather than assumed). Evidence row appended to
      automation/agent-handoffs.md (overnight-lead | governed-fleet|
      slice-c3, the C1/C2 pattern); no spawned session, no respawn, no
      kernel surface touched.
- [x] Slice D: governed package upgrade through the certificate loop
      (evidence: certificate + commit in git log)
      Verification: the certificate + commit appear in git log; kernel
      `make test` green.
      Executed 2026-09-30: one governed package upgrade exercised
      end-to-end through the certificate loop on this host - bili
      (npm billion-context) 0.1.173 -> 0.1.174, already installed
      through the maintained updater (hngh-omp-update.sh) with the
      registry stale at the 0.1.141 pin from 2026-09-23; the slice's
      governed act is the certificate-bound reconciliation: registry
      rows (hngh-packages.tsv bili + acp-kernel embodiment), the
      decision record docs/records/2026-09-30-governed-package-
      upgrade-bili.md, and the CHANGELOG entry landed as the
      candidate commit `hngh: candidate <hash>` (the certificate
      content hash; see git log and the fresh ceremony receipts in
      the automation home's cert-receipts.tsv), with the fast-test
      gate = full kernel `make test` green (2954 checks, ~42s warm).
      Pre-flight: the loop rehearsed via ceremony-drive --dry-run on
      a disposable /tmp fixture built from the real kernel sources
      (dream stop after propose, ten principles passed; both refusal
      classes hit and corrected pre-mutation: a candidate with no .md
      conclusion file refuses source-grounding, a run without
      HNGH_LOADOUT facts refuses cost-and-route-discipline). Real
      drive: ONE ceremony-drive call (fresh /tmp store, plain-words
      objective, 3 advisory findings) -> create-run -> admit-transport
      model/repository -> propose -> prepare-candidate -> commit ->
      certificate-gated push (push proposes under class=push-request
      into its own verdict; never a git hook). Upstream 0.1.174
      retires the BILI_STREAM_STALL_MS stall guard (upstream PR 1714);
      hngh carries no such export and no idle-budget override, so the
      change is behavior-neutral here. Incident recorded during
      pre-flight: a compound fixture-setup command briefly overwrote
      the kernel Makefile with the fixture stub and staged the real
      repo's unrelated dirty paths; caught and fully reverted in the
      same session (git restore from HEAD, zero commits landed) - the
      fixture lane now uses absolute paths only. The System-view
      upgrade trigger (governed-fleet.md section 6 slice D prose)
      stays open as free-commit automation follow-through, filed in
      the queue ledger, not a slice-D gate; the running bili instance
      keeps its loaded binary until its own exit (per-launch
      semantics, no service restart).
- [x] Slice E: credential-seam sweep + model-tier refresh cadence
      Verification: see plans/README verification contract; kernel
      `make test` green.
      Executed 2026-09-30: the sweep surface landed in the automation
      tree as a free commit (afe632e7): credential-health.sh sections
      9-10 (stat-mode-only token-only per-seam sweep across the
      model-chain legs; configured PEER_TOKEN_FILE alerts stale/unseen,
      unconfigured stays silent by design), the monthly drop-in
      cadence/calendar/monthly/02-model-tier-refresh.sh emitting the
      route row quarterly per the OLA read from cadence-params.tsv
      (model-tier-refresh-ola=7776000; absent/unknown OLA is a
      fail-open alert), Makefile:221 wiring, and
      tests/test-slice-e-seam-surface.sh (27 hermetic checks, all
      pass, stub-binary, no token values). Gates green: automation
      `make test` rc=0, kernel `make test` rc=0. queue.md:75 flipped
      done citing docs/records/2026-09-30-credential-seam-sweep-
      model-tier-refresh-ola.md and backlog.md:670-684. The obsolete-
      class death of this lane (blk-20260930) was closed by re-deriving
      live state first and adopting the in-flight tree surface.
- [x] Slice F: node-lattice admission -- one peer admitted through the
      same gates (federation exit)
      Verification: see plans/README verification contract; kernel
      `make test` green.
      Executed 2026-09-30: the deck peer (pinned 2026-09-07 in
      ~/.hngh-automation/pins/pins.tsv as an ed25519 host
      key, tailnet 100.79.162.3, tailscale state active; direct) was
      admitted through the kernel's own gates with zero new kernel
      code (the deck-node study phase-1 shape): admission run created
      -> admit-transport federation (loadout network label
      remote-evidence, tool labels carrier-bundle+worker-task) ->
      admit-peer with fresh attestation evidence (ssh-keygen
      fingerprint of the pinned host key, fixed-width UTC last-seen,
      staleness bound 86400s) -> record.lisp rows: creation +
      transport:federation admission + peer admission
      (peer: steamdeck, fingerprint SHA256:Hj31...1TAg, last-seen) in
      /tmp/opencode/slicef/store. list-pins renders the pin. Wake
      cycle: one real bounded ssh probe transport injected into
      hngh.adapters.federation wake-peer-request -> wake status=issued
      peer=steamdeck; the plain CLI correctly refuses
      no-wake-transport (wake stays injection-only by design; the
      wake-mutation certificate lane exists but a pinned wake file
      transport would be a future boundary amendment). Read-only
      worker across hosts: run-worker run-1 task=steamdeck-deck-facts
      worker=FILE real subprocess transport (bounded ssh to the deck)
      -> status=complete (deck facts: 6.18.50-valve kernel, up 3d4h,
      261G free; deck-side unchanged). Run-sequence constraint found
      live: the admit-peer and arm-run ledger rows share the same
      store record key (admission run-id) so arm must precede
      admit-peer in one store (three-order probe verified); kernel
      finding recorded as an ordinary backlog lane:
      dispatch-admit-peer discards store-record-run's :conflict and
      prints status=admitted even when no row landed (silent-drop
      class, src/main.lisp:1782-1803) - kernel src is FORBIDDEN this
      session, out of this slice's surface. Gates: kernel `make test`
      green rc=0 (2954 checks; no kernel tree change so the baseline
      stands), automation `make test` green rc=0; witness rows in
      automation/agent-handoffs.md (overnight-lead | governed-fleet |
      slice-f) and automation/STATE.md; worker-transport fixture
      removed, /tmp stores left as throwaway evidence.
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
