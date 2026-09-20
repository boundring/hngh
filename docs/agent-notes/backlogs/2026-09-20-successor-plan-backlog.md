# Backlog ledger - successor plan endgame collapse (2026-09-20)

Collapsed queued nodes by family; file one bead per family referencing this file.

## gap-shared-store-replay (42 nodes)

- gap-shared-store-replay::seed-524046b0: cert-atomic-swap documented but never settled the one real concurrency exposure it found: the check-then-append TOCTOU in src/adapter/filesystem.lisp:111-124 (l
- gap-shared-store-replay::kernel-t5-race: gap-shared-store-replay T5 kernel-store concurrency: two create-run (and double admit-transport same transport) against ONE filesystem store concurrently, expec
- gap-shared-store-replay::reader-audit: gap-shared-store-replay reader audit beyond filesystem.lisp: (a) automation/lib/hngh_home.py catalog reader and any shell readers under automation/ -- do they e
- gap-shared-store-replay::replay-validation: gap-shared-store-replay replay-path validation: (a) read path never applies valid-line-p: hand-craft record.lisp lines that READ successfully but are malformed 
- gap-shared-store-replay::kernel-t5-race-create-barrier-nway: Barrier-synced N-way create-run same-key race: repeat kernel-t5-race-create with barrier sync (not just concurrent spawn) and 3+ writers (M=3,4,8) on scratch st
- gap-shared-store-replay::kernel-t5-race-dup-nway-cli: Dup-rate vs size + CLI-level race: (a) M>2 barrier-synced same-key racers (M=3,4) measuring dup-row rate; (b) small-file (empty/10-line) vs 4000-line rate compa
- gap-shared-store-replay::reader-audit-m: Complete catalog.tsv consumer + wild-row audit left open by nodes e/k: enumerate every downstream reader of catalog.tsv, test CR (\r) and NUL fields through bot
- gap-shared-store-replay::reader-audit-o: Fuzz %status-json structural paths excluded by node-g: string escapes/unicode, object/array nesting, nesting-depth behavior, and delimiter-tail handling in %sta
- gap-shared-store-replay::reader-audit-p: Close producer-trust gaps from nodes c/g/i: inventory every writer of HNGH_STATUS_* files and dashboard data.json/system.json net fields, determine attacker-inf
- gap-shared-store-replay::replay-verbs-beyond-present: Dispatch verbs beyond present under malformed store: replay admit/arm/checkpoint/close/check/status (not just present) against malformed stores (atoms, odd/dott
- gap-shared-store-replay::replay-perms-worker-audit: Chmod-unwritable and vanished-root append probes plus worker/wake reporter audit: (a) live chmod 555 / file-as-root / vanished-root append probes to verify tran
- gap-shared-store-replay::reader-audit-o8: Probe deep-input residuals: mixed array/object nesting depth-to-exhaustion vs pure arrays/objects, malformed deep inputs (truncated deep nesting, missing close-
- gap-shared-store-replay::reader-audit-o9: Probe oversized/wide-input performance: huge flat strings (1MB, 10MB), wide flat arrays/objects (10k/100k elements, wide object key count), deep-but-shallow dup
- gap-shared-store-replay::reader-audit-o8-subthreshold-cost: Sub-threshold cost probe: just-below-threshold depths (e.g. 20k/25k/30k pure-array, mixed pairs at 10k/14k) that still parse — measure wall time, max heap (SBCL
- gap-shared-store-replay::verb-admit-transport: Replay admit-transport against malformed stores (atoms, odd/dotted plists, bad identifiers, newline payloads); record raw SIMPLE-TYPE-ERROR/SIMPLE-ERROR vs sile
- gap-shared-store-replay::verb-arm-run: Replay arm-run against malformed stores (atoms, odd/dotted plists, bad identifiers, newline payloads); record raw error escape vs silent NIL admission and exit 
- gap-shared-store-replay::verb-close-run: Replay close-run against malformed stores (atoms, odd/dotted plists, bad identifiers, newline payloads); record raw error escape vs silent NIL and exit code
- gap-shared-store-replay::reader-audit-o9h: Probe nested/composite width: huge strings nested in objects/arrays, wide arrays of strings/objects (non-numeric), and deeply-nested adversarial JSON (depth 100
- gap-shared-store-replay::reader-audit-o9i: Probe malformed-input fail-closed path at scale: truncated, unbalanced, bad-escape, bad-number, and trailing-garbage variants at 100KB/1MB/10MB sizes plus wide-
- gap-shared-store-replay::reader-audit-o9j: Probe ultra-wide + downstream lookup cost: >100k-key objects, MB-size spine payloads, 10MB+ realistic spine; measure parse time/consing/RSS scaling plus %status
- gap-shared-store-replay::reader-audit-o9i-badnumber: Probe bad-number variants at 100KB/1MB/10MB: fresh SBCL per case via :hngh load, leading zeros, bare +/-, 01e+, NaN/Inf literals, double dots. Verdict must be n
- gap-shared-store-replay::reader-audit-o9j-verdict: Synthesize verdict for reader-audit-o9j: given parse-wide, parse-spine, and lookup-assoc measurements, rule whether superlinear blowup exists at realistic width
- gap-shared-store-replay::close-run-poisoning-recovery: Determine the poisoning blast radius of one malformed store line and the recovery/fix policy for close-run. Gate-verified seeds (live CLI, temp stores): one ato
- gap-shared-store-replay::close-run-newline-write-hole: Settle the write-path newline hole and its close-run-facing consequences; correct the close-run exit-code rows. Gate-verified seeds (live CLI, temp stores): (1)
- gap-shared-store-replay::close-run-poisoning-recovery::recovery-drill: End-to-end LEGAL recovery drill from a poisoned hngh store ledger, plus a drill-verified runbook. Context: sibling poison-matrix (1386 live CLI runs, data at /h
- gap-shared-store-replay::close-run-poisoning-recovery::stale-close-probe: Close-run under stale (truncated) replay: wrong-close hazard + post-close behavior. Context: poison-matrix data (~/.jcode/scratch/hngh-matrix/result
- gap-shared-store-replay::close-run-poisoning-recovery::post-validation-shapes: Replay-semantics probe: poison shapes that PASS the recommended canonical validation (valid-line-p write/read symmetry) but still corrupt or silently lose repla
- gap-shared-store-replay::close-run-poisoning-recovery::concurrent-writers: Concurrent-writer poison probe on the shared store ledger. Context: poison-matrix explicitly listed 'Concurrent-writer behavior across transport-fault mid-appen
- gap-shared-store-replay::close-run-newline-write-hole::keyword-intern-channel: SCOPE: characterize the SECOND newline-into-record.lisp bypass channel end-to-end: operator text interned to a KEYWORD whose printed name carries a raw LF (and 
- gap-shared-store-replay::close-run-newline-write-hole::keyword-intern-channel::control-byte-and-robustness-probes: Expand the keyword-intern channel census beyond LF/CR. parse-keyword-option (src/main.lisp:536-538, intern (string-upcase value) :keyword) accepts ANY string; n
- gap-shared-store-replay::close-run-newline-write-hole::keyword-intern-channel::cli-option-boundary-census: CLI option-boundary census on the route-label keyword channel. Node: gap-shared-store-replay::close-run-newline-write-hole::keyword-intern-channel::cli-option-b
- gap-shared-store-replay::close-run-newline-write-hole::keyword-intern-channel::concurrent-append-robustness: Concurrent append robustness of the record store. Node: gap-shared-store-replay::close-run-newline-write-hole::keyword-intern-channel::concurrent-append-robustn
- gap-shared-store-replay::reader-audit-o9l::seed-9e8ebd4e: Probe environment parity + retention: (1) full hngh image vs standalone ASDF-loaded parser on 1MB/10MB flat-string + 50k-key controls; (2) CLISP behavior on con
- gap-shared-store-replay::close-run-newline-write-hole::line-tooling-damage::seed-9e8ebd4e: SCOPE: enumerate every PHYSICAL-LINE-oriented consumer/parser of record.lisp and every physical-line mutation hazard, and live-verify the actual damage of multi
- gap-shared-store-replay::reader-audit-o9i-badnumber::gate::seed-9e8ebd4e: Critique the work of 'gap-shared-store-replay::reader-audit-o9i-badnumber' adversarially. Read every child's 'what_i_did_not_check' and find unexplored gaps giv
- gap-shared-store-replay::reader-audit-o9i-badnumber::gate::seed-9e8ebd4e::c1-store-surface-parity: Store-surface parity probe in ~/Projects/etc/hngh (READ-ONLY: no repo edits, no commits, scratch under ~/.jcode/scratch/badnum-c1/). Gap: the status
- gap-shared-store-replay::reader-audit-o9i-badnumber::gate::seed-9e8ebd4e::c2-status-surface-parity: Status-JSON surface parity probe in ~/Projects/etc/hngh (READ-ONLY: no repo edits, scratch under ~/.jcode/scratch/badnum-c2/). Gap: store-surface ba
- gap-shared-store-replay::reader-audit-o9i-badnumber::gate::seed-9e8ebd4e::c3-poison-position-shape: Poison-position and shape probe on both reader surfaces in ~/Projects/etc/hngh (READ-ONLY: no repo edits, scratch under ~/.jcode/scratch/badnum-c3/)
- gap-shared-store-replay::reader-audit-o9i-badnumber::gate::seed-9e8ebd4e::c4-nan-scale-writer-fidelity: NaN-at-scale + writer #. fidelity probe in ~/Projects/etc/hngh (READ-ONLY: no repo edits, scratch under ~/.jcode/scratch/badnum-c4/). Gaps: (1) the 
- gap-shared-store-replay::reader-audit-o9l::clisp-o9c: o9l probe B: CLISP behavior on the reader controls (bead o9c CLISP gap), or a documented evidence-based out-of-scope verdict.  Repo: ~/Projects/etc/
- gap-shared-store-replay::close-run-poisoning-recovery::stale-close-probe::read-eval-probe: # READ-EVAL + reader-breaker probe (close-run path)  Gate context: the stale-close-probe children (matrix-mine, forward-poison-probe, inverse-illegal-probe) ful
- gap-shared-store-replay::close-run-poisoning-recovery::stale-close-probe::concurrency-probe: # Concurrency probe: racing close-runs on one store  Gate context: no child probed concurrent writers (forward + inverse both flag it). Two concrete unprobed ha
## reader-audit-m (6 nodes)

- reader-audit-m::path-encoding-dedupe: CONFIRMED LIVE DEFECT all five siblings missed: catalog idempotency keys on the RAW path string, but wild ~/.hngh/catalog.tsv stores TWO spellings of the same p
- reader-audit-m::wild-catalog-drift: Closes wild-rows' excluded blind spots on the live ~/.hngh/catalog.tsv (READ-ONLY; HNGH_HOME_DIR unset). Gate already established (do not redo): 152 rows, 0 raw
- reader-audit-m::outside-repo-writers-readers: Closes the shared out-of-repo blind spot of enumerate-readers, callsite-audit, and writer-cr-nul. Gate evidence: (a) a pii-redaction-record row stamped 2026-09-
- reader-audit-m::research-tsv-reader-inventory: strict-reader-spec's declared blind spot is CONFIRMED REAL by gate probe: its spec covers ONLY automation/mcp/hngh_mcp_server.py::read_tsv, but many more reader
- reader-audit-m::catalog-strict-reader-reconciliation: strict-reader-spec (commit f7dc9b08) could not read its sibling artifacts; gate grep confirms docs/design/strict-reader-spec.md has ZERO mentions of catalog/hng
- reader-audit-m::hngh-catalog-disposition: Two siblings flagged the dead shell twin hngh_catalog (automation/lib/common.sh:17-30) but left its fate undecided — no record states retirement vs pending wiri
## line-tooling-damage (6 nodes)

- line-tooling-damage::c1-state-claim: SHARED CONSTRAINTS (hard): read ~/.jcode/scratch/nl-tooling/SETUP.md FIRST for layout, confirmed store facts, fixtures, env seams, damage scale, evidence rules.
- line-tooling-damage::c2-agent-supervision: SHARED CONSTRAINTS (hard): read ~/.jcode/scratch/nl-tooling/SETUP.md first for layout, fixtures, env seams, damage scale, evidence rules. Repo ~/Pro
- line-tooling-damage::c3-sessions-feed-digest: SHARED CONSTRAINTS (hard): read ~/.jcode/scratch/nl-tooling/SETUP.md first; repo READ-ONLY; never write ~/.hngh-automation; no end-to-end job runs; writes only 
- line-tooling-damage::c4-shell-consumers: SHARED CONSTRAINTS (hard): read ~/.jcode/scratch/nl-tooling/SETUP.md first; repo READ-ONLY; never write ~/.hngh-automation; no end-to-end job runs; writes only 
- line-tooling-damage::c5-dashboard-render: SHARED CONSTRAINTS (hard): read ~/.jcode/scratch/nl-tooling/SETUP.md first; repo READ-ONLY; never write ~/.hngh-automation; writes only under ~/.jcode/scratch/n
- line-tooling-damage::c6-mutation-hazards: SHARED CONSTRAINTS (hard): read ~/.jcode/scratch/nl-tooling/SETUP.md first; repo READ-ONLY; never write ~/.hngh-automation; kernel binary only with --store= und
## recovery-drill (6 nodes)

- recovery-drill::read-eval-forging-probe: Poison class read-eval (#.) — the gate probe CONFIRMED the hazard is real; prior matrix left it flagged-open and unprobed (also flagged by kernel-verb-recovery-
- recovery-drill::t-poison-append-accumulation: Accepted-on-t-poison write verbs: duplicate accumulation and steady state. Gate probe CONFIRMED on real ./scripts/hngh: admit-transport run-1 filesystem on a t-
- recovery-drill::poison-matrix-doc-corrections: Apply and verify the corrections to ~/.jcode/scratch/hngh-matrix/POISON-MATRIX.md identified by recovery-drill::second-close-run-mutated and re-conf
- recovery-drill::supervision-recovery-leg-endtoend: Close supervision-rotation-guard's unexercised recovery leg end-to-end with real binaries, under $JCODE_SCRATCH_DIR/recovery-drill/supervision-e2e/: (1) FULL TI
- recovery-drill::realistic-ledger-shapes: External validity of the drill's synthetic stores: every audited node used 2-3-line ledgers with run-1 in :created. Close the >3-line / mid-position / advanced-
- recovery-drill::manual-archive-open-items: Verify manual-archive-path's unverified claims, under $JCODE_SCRATCH_DIR/recovery-drill/archive-open-items/: (1) CERTIFICATE VS ARCHIVED STORE: stand up minimal
## reader-audit-p6.c4-backends (3 nodes)

- reader-audit-p6.c4-backends: READ-ONLY security/robustness audit (no edits, no commits) of the remaining MCP backends in ~/Projects/etc/hngh: (a) scripts/report-queue (source of
- reader-audit-p6.c4-backends::gap-reports-md-consumers: Gap from gate reader-audit-p6.c4-backends::gate (c4a deferral, gate-confirmed live). Audit every non-report-queue consumer of docs/project/reports.md's pipe tab
- reader-audit-p6.c4-backends::gap-present-run-argv-injection: Gap from gate reader-audit-p6.c4-backends::gate (c4c false-negative found by gate). scripts/hngh:13 passes the ENTIRE argv (including the MCP-appended run value
## spend-verify (1 nodes)

- spend-verify: Verify spend guards: confirm no default path can reach expensive model without explicit cap, ambient budget respected, run_plan workers on cheap route. Report v
## sysstore-node (1 nodes)

- sysstore-node: Verify Node.js TLS trust behavior: does Node honor system store by default? Check NODE_EXTRA_CA_CERTS, --use-openssl-ca / --use-bundled-ca flags, version differ
## revoke-rotation (1 nodes)

- revoke-rotation: Audit cert rotation procedure: rotation triggers, reissue flow, atomic swap, old cert invalidation. Evidence file:line refs.
## gap-rotate-queue-driver (1 nodes)

- gap-rotate-queue-driver: scripts/rotate-queue is a SECOND live certificate-driven mutation lane that no prior audit covered: cert-reissue-flow traced only ceremony-drive, and rotation-t
## spend-verify-lane-reconciliation (1 nodes)

- spend-verify-lane-reconciliation: GOAL: Close spend-verify-default-path's unchecked item 'Live spend telemetry to confirm caps bind at runtime' and spend-verify-runplan-cheap's open question 'cr
## spend-verify-ambient-measure (1 nodes)

- spend-verify-ambient-measure: GOAL: Close spend-verify-ambient-budget unchecked items: provider-side quota counters never probed, exact per-cycle token totals are self-reports, Gmail queue t
## spend-verify-build-upstream (1 nodes)

- spend-verify-build-upstream: GOAL: Close version-identity and upstream-delta gaps left by spend-verify-ambient-budget and spend-verify-runplan-cheap. Gate probe already confirmed live proce
## spend-verify-gemini-burst-remediation (1 nodes)

- spend-verify-gemini-burst-remediation: GOAL: Close the DRIFT spend-verify-default-path flagged loudly: gemini-burst-max-calls=20 / gemini-burst-window-s=3600 (automation/cadence-params.tsv:29-30, ann
## spend-verify-enforcement-semantics (1 nodes)

- spend-verify-enforcement-semantics: Close the rename/semantic enforcement gap left open by spend-verify-upstream-delta. Exact-key greps are done (gate probe confirmed repo-wide: api_daily_budget a
## spend-verify-pacer-edge-cases (1 nodes)

- spend-verify-pacer-edge-cases: spend-verify-cadence-counters traced the quota_pace_blocked family (model.sh:474-493 UTC-day, :530-551 rolling window, :577-601 fixed week) but never exercised 
## sv-gap-e-ambient-budget-semantics (1 nodes)

- sv-gap-e-ambient-budget-semantics: GAP (from sv-sem-c open question + sv-sem-a claim needing refinement): whether ambient budget values gate or abort provider calls was never verified, and the ap
## sv-gap-f-alias-env-docs-claims (1 nodes)

- sv-gap-f-alias-env-docs-claims: GAP (from sv-sem-a not-checked list + gate probes): aliases and env-var caps were outside the swept lexicon. Gate probe already found cap-like mechanisms sv-sem
## pacer-g-soft-precision-5h-daily (1 nodes)

- pacer-g-soft-precision-5h-daily: CASE (g) soft-pace precision edges left open by pacer-a/b/d. Grounded in code: quota_pace_blocked soft limb model.sh:484-489, 5h soft limb 513-515 (NEVER trigge
## sv-gap-f4-docs-claims (1 nodes)

- sv-gap-f4-docs-claims: Repo: ~/src/jcode (jcode source). READ-ONLY: do not edit, write, commit, or stash anything. Audit docs at head ref be248c641 and cross-check code at
## pacer-g-probe6-src-multisource (1 nodes)

- pacer-g-probe6-src-multisource: TASK: Multi-source src list and source-string handling in the pacer used-count SQL. automation/lib/model.sh interpolates src raw: daily `source='$src'` (:478); 
## sysstore-gap-3-official-default-and-roadmap (1 nodes)

- sysstore-gap-3-official-default-and-roadmap: Close the two named gaps in sysstore-versions: (1) 'nodejs/build release-infrastructure configs not checked' and (2) 'Node 27/main in-flight PRs that might flip
## gap-rq-record-recon (1 nodes)

- gap-rq-record-recon::seed-524046b0: Covers task concern (d). Repo: ~/Projects/etc/hngh. READ-ONLY audit: no edits, no commits, never execute rotate-queue; static reading + grep only. E
## global-home-beads-census (1 nodes)

- global-home-beads-census::seed-524046b0: Census the home-level beads DB footgun found by drift-links: bd invocations from outside the repo cwd resolve against ~/.beads. Check whether ~/.bea
## spend-verify-gemini-burst-and-db-history (1 nodes)

- spend-verify-gemini-burst-and-db-history::seed-524046b0: Two history questions left open by spend-verify-model-sh-remote-cap. (1) GEMINI_BURST_MAX_CALLS=20/GEMINI_BURST_WINDOW_S=3600 (automation/config.env:41-42, cade
## spend-verify-release-bytes (1 nodes)

- spend-verify-release-bytes::seed-d7772156: Make provenance byte-exact by closing spend-verify-build-prov's two open items. (1) Download https://github.com/1jehuang/jcode/releases/download/v0.85.0/jcode-l
## spend-verify-respawn-session-cap-intent (1 nodes)

- spend-verify-respawn-session-cap-intent::seed-d7772156: Resolve the sessions-day-max split found by spend-verify-cadence-counters. automation/jobs/agent-respawn.sh:55 sets MAX_SESSIONS_DAY='${OVERNIGHT_MAX_SESSIONS_D
## spend-verify-runtime-probe (1 nodes)

- spend-verify-runtime-probe::seed-d7772156: Behaviorally confirm on the LIVE binary (~/.jcode/builds/versions/0.85.0/jcode, sha256 04b06a14...) that the static findings hold at runtime: api_daily_budget a
## sv-gap-f4-e-misc (1 nodes)

- sv-gap-f4-e-misc::seed-d7772156: AUDIT SCOPE: ALL remaining Markdown NOT owned by sibling nodes, at rev be248c641 in repo ~/src/jcode. Owned elsewhere (do NOT audit): docs/AMBIENT_M
## sv-quota-instrument-ssl (1 nodes)

- sv-quota-instrument-ssl::seed-d7772156: GOAL: Root-cause the quota-check.py breakage found by sv-quota-probe, because that script is the DESIGNATED authoritative budget instrument (docs/records/2026-0
## sv-tui-visible-caps (1 nodes)

- sv-tui-visible-caps::seed-d7772156: GOAL: Close sv-cap-audit's explicitly unexamined surface: the DEFAULT ambient path is visible=true, which runs 'jcode ambient run-visible' as a full TUI (src/cl
## sysstore-gap-1-extra-ca-failures (1 nodes)

- sysstore-gap-1-extra-ca-failures::seed-d7772156: Complete the unexplored NODE_EXTRA_CA_CERTS failure modes (explicitly flagged by sysstore-empirical as unchecked, and by sysstore-docs as undocumented for the p
## sysstore-gap-2-runtime-flag-interplay (1 nodes)

- sysstore-gap-2-runtime-flag-interplay::seed-d7772156: Verify documented-but-never-tested runtime semantics on v26.9.0 (sysstore-docs quotes cli.md claims that sysstore-empirical never exercised; the gate additional
## kernel-t5-race-size-sweep (1 nodes)

- kernel-t5-race-size-sweep: Small-file vs large-file dup-rate comparison: run same-key race harness against empty file, 10-line file, and 4000-line file backends (or equivalent store sizes
## reader-audit-p6 (1 nodes)

- reader-audit-p6: Audit readers/consumers of status+dashboard files: dashboard server handlers, scripts/dashboard-readout, MCP tools; check validation, TOCTOU, symlink/traversal 
## arch-review-kernel-layers (1 nodes)

- arch-review-kernel-layers: [T2] Clean-architecture review (kernel, read-only): map ~/Projects/etc/hngh/src/ layering against clean-architecture dependency direction (inward on
## arch-review-automation-libs (1 nodes)

- arch-review-automation-libs: [T2] Clean-architecture review (automation libs, read-only): audit automation/lib/ (model.sh, common.sh, scrub.py, redact.sh, hngh_home.py, breadcrumbs.sh) for 
## arch-review-scripts-jobs (1 nodes)

- arch-review-scripts-jobs: [T2] Clean-architecture review (scripts/ + jobs): audit repo-root scripts/ and automation/jobs/ for duplicated logic across rotate-queue, report-queue, patrol.p
## arch-debt-census-from-artifacts (1 nodes)

- arch-debt-census-from-artifacts: [T2] Cross-cutting debt census from completed artifacts: read node_meta artifact_json of the successor plan's completed nodes (state file ~/.jcode/state/swarm/s
## arch-debt-beads-file (1 nodes)

- arch-debt-beads-file: [T1] File tech-debt beads from the arch-debt-census: for each automation free-commit candidate (b) and ceremony candidate (a) above medium value, file a bd issu
## race-verify-parity-small-sizes (1 nodes)

- race-verify-parity-small-sizes: Verification-parity gap at the small sizes, found by gate audit. race-4000line verified per-row exactness, tail contiguity via grep -n, and ran 1-worker control
## o8-gap-rss-cost-attribution (1 nodes)

- o8-gap-rss-cost-attribution: Node o8-gap-rss-cost-attribution (child of gate gap-shared-store-replay::reader-audit-o8-subthreshold-cost::gate).  GAP FOUND BY GATE: the corrected RSS story (
## reader-audit-o9h-model-reader (1 nodes)

- reader-audit-o9h-model-reader: Fourth-kernel-JSON-reader gap. The entire reader-audit-o9h family premised on 'the three hngh JSON readers' (federation, review, status spine), but a FOURTH ker
## reader-audit-o9h-huge-keys (1 nodes)

- reader-audit-o9h-huge-keys: Huge-keys x dup-key-scan amplification gap. Huge strings were probed only as VALUES (probe-o9h-str, probe-o9h-str-nest); wide objects only with SHORT keys (k<=8
## o8-rss-attribution-over-bare (1 nodes)

- o8-rss-attribution-over-bare: Correct the RSS cost-attribution synthesis in logs/o8-rss-phase-attribution.md (node o8-rss-phase-attribution) so the ~11-15MB delta is attributed over ONE expl
## o8-rss-cliff-pinning (1 nodes)

- o8-rss-cliff-pinning: Pin the true cliff thresholds that node o8-rss-boundary-rows implicitly assumed. Gate-verified: plain array-8000, list-13000, and list-14000 have NO rows anywhe
## o8-rss-void-scan-remainder (1 nodes)

- o8-rss-void-scan-remainder: Close the void-annotation scan gap left by node o8-rss-void-annotations, whose 'not checked' list says: 'Did not scan for wrapper-RSS quotes outside the six nam
## replay-worker-tests-g3-trace (1 nodes)

- replay-worker-tests-g3-trace: Worker validation replay (follow-up to replay-worker-audit). Work read-only in ~/Projects/etc/hngh; no repo edits; keep fixtures under $JCODE_SCRATC
## rq-kernel-contract (1 nodes)

- rq-kernel-contract: READ-ONLY STATIC AUDIT (reading/grep/git only; never execute rotate-queue, the kernel, or tests; never modify files; never print endpoint/token/secret values). 
## rq-push-surfaces (1 nodes)

- rq-push-surfaces: READ-ONLY STATIC AUDIT (no execution, no file modification, no secrets printed). Gap from rq-push: ':push certificate issuance paths not fully enumerated' and t
## rq-sched-contract (1 nodes)

- rq-sched-contract: READ-ONLY STATIC AUDIT (no execution, no modification; unit files may be read — report names/paths only, never secret values from Environment= lines). Gap from 
## rq-ledger-prov (1 nodes)

- rq-ledger-prov: READ-ONLY STATIC AUDIT (git history + source reads only, no execution, no modification). Gap from rq-ledger ('when/how the 5 legacy 5-field rows were introduced
## rq-routes-resid (1 nodes)

- rq-routes-resid: READ-ONLY STATIC AUDIT (no execution of scripts OR test suites; no modification; no secrets printed). Gap from rq-routes ('worker-driver full route path and tes
## rq-artifacts (1 nodes)

- rq-artifacts: READ-ONLY STATIC AUDIT (no execution, no modification; NEVER print endpoint/token/secret values — names/paths only; sqlite at most schema/table-name inspection)
## replay-worker-automation-edges (1 nodes)

- replay-worker-automation-edges: [GATE GAP from shared-store-replay::replay-perms-worker-audit::gate (piglet)] replay-worker-automation-edges: audit automation/lib/launch-session.sh sibling exe
## replay-wake-runtime-probe (1 nodes)

- replay-wake-runtime-probe: [GATE GAP from shared-store-replay::replay-perms-worker-audit::gate (piglet)] replay-wake-runtime-probe: runtime-probe the wake surface that replay-wake-reporte
## rq-a-row-prov (1 nodes)

- rq-a-row-prov: READ-ONLY STATIC AUDIT child (subtask a of rq-ledger-prov). Repo: ~/Projects/etc/hngh. Constraints: static reads only — read-only git (log, show, di
## rq-b-live-violations (1 nodes)

- rq-b-live-violations: READ-ONLY STATIC AUDIT child (subtask b of rq-ledger-prov). Repo: ~/Projects/etc/hngh. Constraints: static reads/greps and read-only git (diff, show
## rq-c-aborted-rotation (1 nodes)

- rq-c-aborted-rotation: READ-ONLY STATIC AUDIT child (subtask c of rq-ledger-prov). Repo: ~/Projects/etc/hngh. Constraints: read-only git (log, log -p, show, log -L) + file
## rq-d-guard-census (1 nodes)

- rq-d-guard-census: READ-ONLY STATIC AUDIT child (subtask d of rq-ledger-prov). Repo: ~/Projects/etc/hngh. Constraints: static reads/greps only; NEVER run the test suit
## rq-e-timeline-fence (1 nodes)

- rq-e-timeline-fence: READ-ONLY STATIC AUDIT child (subtask e of rq-ledger-prov). Repo: ~/Projects/etc/hngh. Constraints: read-only git (log -S/-L, show) + file reads/gre
## rq-f-beat-skip (1 nodes)

- rq-f-beat-skip: READ-ONLY STATIC AUDIT child (subtask f of rq-ledger-prov). Repo: ~/Projects/etc/hngh. Constraints: static inference + file reads/greps ONLY. NEVER 
## replay-kernel-worker-tests (1 nodes)

- replay-kernel-worker-tests: Read-only slice of node replay-worker-tests-g3-trace (audit replay: kernel worker tests + G1 mapping). Repo ~/Projects/etc/hngh. HARD CONSTRAINTS: n
## replay-automation-render-g5 (1 nodes)

- replay-automation-render-g5: Read-only slice of node replay-worker-tests-g3-trace (audit replay: automation worker-render test + G5). Repo ~/Projects/etc/hngh. HARD CONSTRAINTS:
## replay-g3-persistence-trace (1 nodes)

- replay-g3-persistence-trace: Read-only slice of node replay-worker-tests-g3-trace: trace G3 root cause (run-worker completion persistence). Repo ~/Projects/etc/hngh. HARD CONSTR
## replay-g2-fd-leak-empirical (1 nodes)

- replay-g2-fd-leak-empirical: Read-only slice of node replay-worker-tests-g3-trace: empirically confirm or refute G2 (suspected fd leak on the timeout path of read-worker-file, src/main.lisp
## replay-g4-rc75-mapping (1 nodes)

- replay-g4-rc75-mapping: Read-only slice of node replay-worker-tests-g3-trace: map executed-test coverage of G4. Repo ~/Projects/etc/hngh. HARD CONSTRAINTS: never modify any
## census-records-scan (1 nodes)

- census-records-scan: [T3a] Census scan: repo records. READ-ONLY (no edits, no commits, no bd writes) in ~/Projects/etc/hngh. Read docs/records/2026-09-*.md and docs/reco
## census-node-artifacts (1 nodes)

- census-node-artifacts: [T3b] Census scan: successor-plan node artifacts. READ-ONLY. Input file ~/.jcode/scratch/arch-debt-census/debt-signals.jsonl (~700KB; 445 rows, each
## census-rec-0901-0907 (1 nodes)

- census-rec-0901-0907: You are census child for hngh records slice 2026-09-01..09-07. Working dir: ~/Projects/etc/hngh (branch main). READ-ONLY: no file edits, no git comm
## census-rec-0909-0910 (1 nodes)

- census-rec-0909-0910: You are census child for hngh records slice 2026-09-09..09-10. Working dir: ~/Projects/etc/hngh (branch main). READ-ONLY: no file edits, no git comm
## rvp-readme-mirrors-wording (1 nodes)

- rvp-readme-mirrors-wording: Land the documentation correction prescribed by parity-mechanics/findings.md:149-153 but never applied: race-verify-parity/README.md:31,33 still carry the unqua
## gap-caller-census-runautonomous (1 nodes)

- gap-caller-census-runautonomous: Unexplored caller census, one suspected sweep misclassification, and one never-examined surface. (1) push-repo-wide-sweep lists scripts/run-autonomous under NEG
## gap-wiring-loose-ends (1 nodes)

- gap-wiring-loose-ends: Small flagged loose ends that no child dispositioned. (1) automation/cadence-params.tsv:54 lists 16-remote-push.sh as an operator-away-windows consumer, but the
## census-gap-evidence-resolve (1 nodes)

- census-gap-evidence-resolve: All five census chunk artifacts left evidence unverified (each what_i_did_not_check admits it). t3b-chunk1..5.jsonl in ~/.jcode/scratch/arch-debt-ce
## census-gap-decision-ledgers (1 nodes)

- census-gap-decision-ledgers: Per-entry keep/dup/drop dispositions are only machine-readable for chunk 1 (t3b-chunk1-process.py DECISIONS: K with class/value, D with dup ref target, X drop).
## rq-k-route-consumer-census (1 nodes)

- rq-k-route-consumer-census: Close the census residual: rq-f-heartbeat-route claimed 'all three probe-model-route callers are now read' but a repo-wide grep shows consumers beyond the three
## census-gap-evres-g4 (1 nodes)

- census-gap-evres-g4: billion-context (bili) build trace (gap from c1/c2 what_i_did_not_check). Facts from the children: installed npm billion-context is 0.1.129, dist/index.js is 76
## census-gap-evres-g6 (1 nodes)

- census-gap-evres-g6: Upstream reference alignment (gap flagged by c1, c2, c3 and c4, unowned: each chunk verified jcode tokens against a DIFFERENT reference and nobody established w
## census-gap-evres-g7 (1 nodes)

- census-gap-evres-g7: Retired-system archive resolution (gap from c1 what_i_did_not_check: 'Exhaustive retired-archive search for deck-setup.sh (searched Projects/back, ~/.hngh-autom
## census-gap-evres-g8 (1 nodes)

- census-gap-evres-g8: repo-inventory.txt staleness check (gap from c4 what_i_did_not_check: 'Did not re-verify the 12,148-entry repo-inventory.txt itself; relied on it for basename u
## rq-k2-consumer-audit (1 nodes)

- rq-k2-consumer-audit: STATIC audit, ~/Projects/etc/hngh. No execution, no edits, never print token/secret values (redact everything credential-like). This content is your
## rq-k2g-inventory (1 nodes)

- rq-k2g-inventory: Repo-wide exhaustive inventory of probe-model-route references. Prior child audits (rq-k2a..k2f) covered 5 runtime consumers (rotate-queue, schedule-heartbeat, 
## rq-k2h-sysjson-consumers (1 nodes)

- rq-k2h-sysjson-consumers: system.json downstream consumer audit. automation/jobs/system-awareness.sh writes dashboard/system.json (atomic tmp+rename; net.model_endpoint = ok|fail|unavail
## rq-k2i-alert-pipeline (1 nodes)

- rq-k2i-alert-pipeline: Credential-health alert/evidence pipeline audit. rq-k2b-credhealth found credential-health.sh:124-125 rc=2 'malformed transport config' is dead for malformed co
## rq-k2j-modelsh-readers (1 nodes)

- rq-k2j-modelsh-readers: Complete the 0600 reader-class audit of automation/lib/model.sh. rq-k2e-token-tests read only lines 1-480 and grounded the kimi/ocgo/zai gate sites (:678/:731/:
## rq-k2k-backstop (1 nodes)

- rq-k2k-backstop: Kernel dispatch backstop for worker-driver's silent fallback. rq-k2f-kernel-consumers established worker-driver:45-52: probes only on --route=auto; multiple-val
## rq-k2l-doc-provenance (1 nodes)

- rq-k2l-doc-provenance: Drift and provenance sweep for the probe audit. Tasks: (1) probe-model-route docstring drift, verified by gate re-read: :17 says 'The one-file form prints local
## rq-k2m-test-coverage (1 nodes)

- rq-k2m-test-coverage: Test-coverage inventory for the probe + 0600 gate class (static only, do NOT run tests). Tasks: (1) full read of automation/tests/test-manga-vision-token-mode.p
## rq-k2n-runtime-verify (1 nodes)

- rq-k2n-runtime-verify: Runtime verification of the probe contract with FIXTURES ONLY (prior nodes were static-constrained; this closes the repeated 'no runtime verification' hedge). (
## census-gap-ledger-c3-crossnode-nonwarn-sweep (1 nodes)

- census-gap-ledger-c3-crossnode-nonwarn-sweep: Sweep the chunk-3 dup rows that no re-audit ever individually reviewed. census-gap-ledger-chunk3-warn-reaudit covered its 58 WARN rows, 32 cross-chunk dups, 16 
## census-runautonomous-invocation (1 nodes)

- census-runautonomous-invocation: READ-ONLY deep dive in repo ~/Projects/etc/hngh (branch main; respond in English/ASCII). Goal: settle whether scripts/run-autonomous actually execut
## runautonomous-timeout-paths (1 nodes)

- runautonomous-timeout-paths: Static audit of failure/exception paths in scripts/run-autonomous (read the full file, read-only). Gate-verified premises: drive_ceremony :304-308 runs subproce
## stub-fidelity-vs-real-siblings (1 nodes)

- stub-fidelity-vs-real-siblings: Stub-fidelity audit: tests/scripts/test-run-autonomous.py vs the REAL sibling CLIs. Read the test fully, then read scripts/backlog-lanes (does real --json outpu
## runautonomous-systemd-chain (1 nodes)

- runautonomous-systemd-chain: Characterize the production invocation chain of scripts/run-autonomous. Gate-verified lead: automation/systemd/hngh-autonomy.service:8 ExecStart=/usr/bin/python
## domain-governance-certificate (1 nodes)

- domain-governance-certificate: Trace the domain layer behind the push leg's fail-closed claims: hngh.domain:issue-candidate-certificate and adjacent functions in src/domain/governance.lisp (r
## push-leg-test-coverage (1 nodes)

- push-leg-test-coverage: Push-leg test-coverage audit. Read tests/scripts/test-ceremony-drive-dry-run.py and tests/scripts/test-ceremony-drive-commit-identity.py in full (Makefile:29-30
## read-eval-sharp-dot-probe (1 nodes)

- read-eval-sharp-dot-probe: POISON-PROBE CHILD 1: read-time #. evaluation on the close-run path.  CONTEXT (all paths verified by parent): - Repo (READ-ONLY, do not write anywhere under it)
## reader-breaker-variants-probe (1 nodes)

- reader-breaker-variants-probe: POISON-PROBE CHILD 2: reader-breaker variants on the close-run path (variants POISON-MATRIX.md left unverified, open question ~169-171).  CONTEXT (all paths ver
## matrix-close-run-row-reaudit (1 nodes)

- matrix-close-run-row-reaudit: AUDIT CHILD (READ-ONLY): re-audit the poison matrix's close-run rows for crash kinds a/d/f/g at p1/p2/p3 against raw artifacts.  SCOPE: ~/.jcode/scr
## conflict-window-probe (1 nodes)

- conflict-window-probe: Goal: LOSER_CONFLICT (record-conflict) was never realized in any sibling trial (0/45 clean-race, 0/60 poison-race, 0/72 mixed-race); its reachability is only mo
## syscall-flush-tear-probe (1 nodes)

- syscall-flush-tear-probe: Goal: every sibling marked the zero-tear / single-flush mechanism as inference because strace is absent (confirmed: strace, ltrace, perf all missing from PATH).
## store-mutation-third-actor (1 nodes)

- store-mutation-third-actor: Goal: no sibling probed a third actor mutating the store itself, and TRANSPORT_FAULT was observed 0 times across all 177 sibling trials - its reachability rests
## sibling-reconciliation (1 nodes)

- sibling-reconciliation: CROSS-READ + RECONCILE the four sibling concurrency probes. Pure reading/analysis: NO timing trials, NO hngh runs. ordering-analysis explicitly did not cross-va
## window-widening (1 nodes)

- window-widening: WINDOW-WIDENING measurement (task 2 of conflict-window-probe). Parent goal: realize or rule out LOSER_CONFLICT (record-conflict) with measurement. Rationale: on
## phase-instrumentation (1 nodes)

- phase-instrumentation: INSTRUMENTED PER-PHASE TIMING + CORRECTED THRESHOLD TABLE (task 3b of conflict-window-probe). You run AFTER the two measurement siblings so your sbcl work never
## sm3a-rm-writer (1 nodes)

- sm3a-rm-writer: RM RACE vs hngh WRITER (task 1 + task 4 label capture). Repo ~/Projects/etc/hngh is READ-ONLY: create scratch dir probe-sm3a-rmw/ in repo root (untr
## sm3a-mv-writer (1 nodes)

- sm3a-mv-writer: MV REPLACEMENT RACE vs hngh WRITER (task 2 + task 4). Repo ~/Projects/etc/hngh is READ-ONLY: create scratch dir probe-sm3a-mvw/ in repo root (untrac
## sm3a-reader (1 nodes)

- sm3a-reader: READER RACES: rm/mv vs bare `present` replay (task 1b + task 3 + task 4). Repo ~/Projects/etc/hngh is READ-ONLY: create scratch dir probe-sm3a-rdr/ 
## flush-threshold-bisect (1 nodes)

- flush-threshold-bisect: Task 3b: find the EXACT payload size where one write() becomes two (SBCL fd-stream output buffer boundary), two independent ways. FIRST read ~/.jcod
## reader-race-large-record (1 nodes)

- reader-race-large-record: Task 4: reader visibility at/above the flush boundary (closes mixed-reader-race gaps 'records approaching buffer size' + 'tight contention loop'). PREREQS: read
## writer-race-near-boundary (1 nodes)

- writer-race-near-boundary: Task 5: two-writer race with near-boundary records - detect fused/torn lines (ordering-analysis §2 table + §5 fused-record analysis, now at sizes that CAN multi
## gap-loose-8-truncation-class-sweep (1 nodes)

- gap-loose-8-truncation-class-sweep: CONTRACT (READ-ONLY, extends gap-loose-7-truncation-coverage which explicitly excluded these sinks): map the truncation-embed behavior class for the sinks gap-l
## gap-loose-9-gitpush-orphan (1 nodes)

- gap-loose-9-gitpush-orphan: CONTRACT (READ-ONLY, closes gap-loose-7-truncation-coverage's blocking open question before its C sketch can be built): adjudicate the orphan status of automati
## gap-loose-10-away-scheduling-sweep (1 nodes)

- gap-loose-10-away-scheduling-sweep: CONTRACT (READ-ONLY, closes gap-loose-1-away-row's not-checked scheduling/authorization residuals): reconcile the stale-row disposition against all newer repo t
## gap-loose-12-verify-candidate-trace (1 nodes)

- gap-loose-12-verify-candidate-trace: CONTRACT (READ-ONLY, closes gap-loose-4-executor-push-leg's open residuals on the executor surface): (a) read scripts/verify-candidate.py IN FULL (gate probe co