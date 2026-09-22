# Records

Records preserve verified facts, decisions, and bounded unknowns. They do not
authorize a future action.

- `2026-08-11-crystallized-cutover.md` identifies the external retirement
  archive and its active-state boundary.
- `2026-08-19-archive-gate-retired.md` records the retirement of the
  `make check-archive` verifier; the archive remains historical evidence
  only and is no longer verified or consulted by any active gate.
- `2026-08-11-task-1-boundaries.md` records the dependency and presentation
  boundary publication.
- `2026-08-11-task-2-run-domain.md` records the pure domain lifecycle and
  evidence boundary.
- `2026-08-12-task-3.1-create-run.md` records the first application use case,
  its callback boundary, and atomic recording contract.
- `2026-08-12-task-3.2-arm-run.md` records closed admission evidence and the
  created-to-armed application transition.
- `2026-08-12-task-3.3-start-run.md` records the armed-to-running application
  transition and its one-slot recording boundary.
- `2026-08-12-task-a-autonomous-control.md` records the source-grounded policy
  contract for future review and mutation authorization.
- `2026-08-12-task-e-candidate-evidence.md` records the read-only explicit
  candidate evidence bundle and its closed admission boundary.
- `2026-08-12-task-c0-proposal-ledger.md` records the pure proposal and
  evidence-requirement ledger needed before deterministic principle evaluation.
- `2026-08-17-task-c1-principle-evaluation.md` records the deterministic
  principle evaluator over the proposal ledger and its closed refusals.
- `2026-08-17-task-c2-failure-disposition.md` records the closed
  failure-disposition policy and the list-valued-constant redefinition note.
- `2026-08-17-task-c3-candidate-certificate.md` records the non-mutating
  candidate authorization certificate and its mechanical pure issuer.
- `2026-08-17-task-d1-close-run.md` records the policy-gated `close-run`
  application use case and its closed terminal transitions.
- `2026-08-12-task-3.4-checkpoint.md` records closed verification and manifest
  evidence before the running-to-checkpointed application transition.
- `2026-08-13-pi-worker-and-delegation-survey.md` records the future Pi worker
  boundary, extension triage, and fixture gates; it admits no runtime adapter.
- `2026-08-18-docs-intent-framing.md` records the documentation-only
  reframing around intent and direction: the new vision document, plain
  root README, directional roadmap, and two-audience documentation index.
- `2026-08-18-task-r4-evidence-adapter.md` records the read-only evidence
  adapter (promotion rung 4): its fixed command set, injected process
  transport, closed refusal vocabulary, and evidence-state mapping.
- `2026-08-18-task-r5-mutation-executor.md` records the certificate-bound
  mutation executor, fixed action templates, injected process transport, and
  point-of-action refusal checks.
- `2026-08-18-task-r6-review-adapter.md` records the bounded model-review
  adapter, its fixed prompt, closed JSON output contract, deterministic
  review evidence facts, and provider-free injected transport.
- `2026-08-18-tagit-history-redacted-2026-09-20.md` records the
  operator-visible presentation layer, the `hngh.main` composition root,
  the fail-closed default port adapters, and the inward dependency-guard
  extension to presentation.
- `2026-08-19-readme-harness-framing.md` records the root README `Why` and
  `Where` revision framing Hngh as a record-first system harness against the
  throughput-first harness-mainstream, grounded in the arXiv 2604.18071
  empirical harness study and the 2026-07-28 stateless MCP update.
- `2026-08-24-prior-art-landscape.md` records the prior-art survey (in-toto,
  DSSE, Sigstore, SCITT) and the invariants Hngh adopted from it, including
  evidence monotonicity.
- `2026-08-24-governance-property-tests.md` records the totality and
  monotonicity property tests over the governance vocabularies.
- `2026-08-24-first-self-governed-commit.md` records the first commit
  produced, reviewed, and committed by Hngh under its own certificate.
- `2026-08-24-second-self-governed-commit.md` records the second
  self-governed commit and the adapter bug fixes the first governance loop
  surfaced.
- `2026-08-24-command-surface-and-transport-admission.md` records the
  operator command surface (promotion rung 8), filesystem transport
  admission, and the strict exit-code protocol.
- `2026-08-24-command-surface-dogfood.md` records the dogfood development
  loop (promotion rung 9): the propose → issue-cert → mutation-check
  validation against real repository evidence.
- `2026-08-24-task-r10-bounded-worker-transports.md` records the bounded
  `:model` and `:terminal` transports behind closed loadout admission.
- `2026-08-24-design-distributed-attestation.md` records the distributed
  attestation design (promotion rung 11): envelope bounds, pinned keys, and
  signature verification ports.
- `2026-08-24-context-budget-and-toolchain.md` records the operator's
  context-budget preference (~40% of the model window through
  billion-context) and the omp/pi toolchain wiring through `bili`.
- `2026-08-25-r12-pin-registry-and-signature-transport.md` records the
  operator pinned-key registry, the strict pins-file parser, and the live
  RSA/SHA-256 signature-verification proof (promotion rung 12).
- `2026-08-25-r13-operator-reviewer-transport.md` records the operator
  reviewer-transport file and the live review against the local model
  server, verified end to end (promotion rung 13).
- `2026-08-25-r14-ed25519-signature-transport.md` records the closed
  key-algorithm vocabulary on pins and the Ed25519 raw-signature
  verification transport (promotion rung 14), with live end-to-end proof.
- `2026-08-25-r15-http-claim-method.md` records the network claim method
  joining the closed federation method set (promotion rung 15), with
  live proof over a local HTTP server through an injected transport.
- `2026-08-25-r16-policy-profiles.md` records the operator policy
  profile value, the `:review` requirement kind, and the `profile=`
  admission on `propose` (promotion rung 16).
- `2026-08-25-r17-wake-peer.md` records the wake-on-demand slice for
  pinned lattice peers (promotion rung 17): the wake ports/result, the
  `wake-peer` command, and the closed refusal vocabulary.
- `2026-08-25-loop-history-guard.md` records the machine-checked
  self-governance guard: every code-surface commit since the
  restatement must be candidate-bound or rule-labeled, with the one
  pre-guard violation named.
- `2026-08-25-r18-worker-transport.md` records the bounded read-only
  worker task (promotion rung 18): `run-worker`, the `:worker`
  admission label, and the closed worker evidence fact.
- `2026-08-25-session.md` records the 2026-08-25 continual-progress
  session arc: the extension repair, the consistency pass, rungs
  14–18, the external re-review and the loop-history guard, the bridge
  finalization, and the live worker proof.
- `2026-08-25-worker-driver.md` records the one-shot continual-worker
  driver (`scripts/worker-driver`) and its exit-code contract.
- `2026-08-26-continual-scheduling.md` records the scheduling &
  heartbeat milestone: schedule-heartbeat, probe-model-route, driver
  `--route` fallback, dashboard live/export modes, generate-publication,
  fleet-manager, and the ceremony-drive helper — all inside the
  no-daemon boundary.
- `2026-08-26-scheduled-runs-investigation.md` records the read-only
  investigation of the hngh-automation schedule: the 7 systemd user
  timers are healthy and firing, the 42/42 `cancelled` store runs were
  beacons closed `cancelled` by design in `lib/hngh-record.sh`, only
  3 of 7 jobs wrote runs, and the applied fixes (exit-0 closes
  `evacuated`; the night-agent/morning-report/model-bench/night-research
  jobs now beacon).
- `2026-08-26-osd-and-dashboard.md` records the operator-facing visual
  surface that landed in the last 24 hours: the `dashboard-tui` full-
  screen TUI, the `grade-interface` grading loop with `ui-grades.md`,
  the `evolve-operative` animation/evolution story and
  `operative-frames.md`, and the Plasma `osd-operative` overlay — all
  candidate-bound through the governance loop, with the kernel's governance
  surface unchanged.
- `2026-08-27-task-1.5-select-course.md` records P1 #1.5: course
  selection extracted from the service tick into the pure kernel
  (domain policy, application use case, CLI dispatch, cadence wiring)
  with the full Lisp + Python gate green.
- `2026-08-27-p2-design-contracts.md` records the four ceremony-ready
  P2 DESIGN contracts (command center architecture, system awareness
  map, buddy menu spec, gamified-run model) and their indexing.
- `2026-08-27-acceleration-wave.md` records the four-slice acceleration
  wave: the roguelike delegation wrap (`omp-bridge --run-start/--run-end`),
  the S3 `status` verb, the S1 truth-telling dashboard, and the display
  register spec — with the four lessons harvested to the llm-wiki.
- `2026-08-27-operator-items-closeout.md` records the dashboard's three
  operator items closed at the source: the missing-store friendly
  refusal (kernel, exit 2), the timestamped wake store, the MiniMax-H3
  bench drop, and the failed-unit sweep (calligra reset,
  gbd-agent-configs root-caused and flagged).
- `2026-08-27-dashboard-evolution-gbd-retirement.md` records the
  dashboard evolution wave (operator-item lifecycle, server endpoints,
  session-per-column observatory, cascading gantt) and the
  git-back-dots retirement with its verified archive.
- `2026-08-28-self-improvement-cadence.md` records the cadence wave
  (30m/hour tiers wired, four day routines, telemetry store v0, feeds
  mounted), its live proof, six lessons, and the triage outcomes.
- `2026-08-28-automation-advancement.md` maps the operator session's
  working pattern (intake → plan → certificate-bound execution →
  verification → records → lessons) onto the machine's own mechanisms:
  what is automated, what stays operator-side, what is next-necessary.
- `2026-08-28-lessons-consolidation.md` folds the day's and the prior
  day's process lessons into their correct homes (governance doc,
  ledger spec, backlog, roadmap) and repairs the reports.md double-header
  flagged by the review digest.
- `2026-08-30-lessons-and-foldback.md` records what the 33h+
  unattended window produced (8-step plan executed, 12/12 research
  lines crystallized, zero kernel commits after plan exhaustion), the
  window's failure classes, and the 2026-08-30 doc-suite fold-back
  (requirement-kind count, roadmap rung/use-case drift, two backlog
  rows).
- [2026-09-09-1password-service-account-interface.md](2026-09-09-1password-service-account-interface.md)
- [2026-09-09-budget-governance-directive.md](2026-09-09-budget-governance-directive.md)
- [2026-09-09-operator-flexibility-doctrine.md](2026-09-09-operator-flexibility-doctrine.md)
- [2026-09-09-wake-mutation-lane-rotation.md](2026-09-09-wake-mutation-lane-rotation.md)
- [2026-09-17-certificate-ephemerality-of-record.md](2026-09-17-certificate-ephemerality-of-record.md)
  — kernel certificates are single-use stdout artifacts with no store
  write path; the commit-subject hash is the only durable trace and
  the loop-history guard's candidate check is format-only.
  Adjudicated a design gap, not a known limitation; mint-time
  certificate receipts are the adopted remediation direction.
- [2026-09-17-cert-disposition-surface-closure.md](2026-09-17-cert-disposition-surface-closure.md)
  — orphaned candidate certs (a3286b78, 65820f40, 9e1b74ee; labels
  declared only on unreachable commits) are moot by mechanism: no
  ledger tracks certs, commit-subject-on-main is the whole registry,
  and all four contents landed via reachable twins. Corrects the
  census wording that framed the external cert id as a git object.

## 2026-09-22 batch backfill

The index resumed 2026-09-22 with a one-pass batch backfill of the
records below (filesystem-derived: every record not yet listed above,
within the covered dates), oldest to newest.

- [2026-09-13-governed-fleet-consolidation.md](2026-09-13-governed-fleet-consolidation.md)
  — the operator ratifies the governed-fleet stages 3+4 merge; roadmap,
  backlog triage, and slices A-G become the landing contract.
- [2026-09-13-newspaper-paid-cost-conversion.md](2026-09-13-newspaper-paid-cost-conversion.md)
  — the daily newspaper pipeline stops spending paid model calls after
  the $5.55/24h metered-ledger trigger; the pipeline is reclassified.
- [2026-09-13-presentation-pass-1-adoption.md](2026-09-13-presentation-pass-1-adoption.md)
  — close-out of presentation pass 1: the classy/dry/witty public-face
  direction (docs/design/presentation-direction.md) is adopted; what
  landed and what stays on the horizon.
- [2026-09-13-wake-mutation-lane-landing.md](2026-09-13-wake-mutation-lane-landing.md)
  — the :wake-mutation src mutation lands through the ceremony; the
  operator-stall gate class is retired.
- [2026-09-20-gemini-burst-cap-enforcement.md](2026-09-20-gemini-burst-cap-enforcement.md)
  — gemini burst-cap enforcement landed (burst-remediation).
- [2026-09-20-git-history-secret-scrub.md](2026-09-20-git-history-secret-scrub.md)
  — git history secret scrub plus dashboard allowlist.
- [2026-09-20-mcp-research-feed-strict-reader-spec.md](2026-09-20-mcp-research-feed-strict-reader-spec.md)
  — strict-reader contract for the MCP research TSV feed.
- [2026-09-20-publication-review-findings-digest-scrub.md](2026-09-20-publication-review-findings-digest-scrub.md)
  — publication-review findings digest scrubbed through lib/scrub.py.
- [2026-09-20-secret-scrub-round2.md](2026-09-20-secret-scrub-round2.md)
  — secret scrub round 2: journal env leak plus OPENCODE history purge.
- [2026-09-20-state-md-writer-reader-compat.md](2026-09-20-state-md-writer-reader-compat.md)
  — STATE.md writer/reader 4-field compatibility audit
  (writers-reader-compat).
- [2026-09-20-value-add-routing-policy.md](2026-09-20-value-add-routing-policy.md)
  — value-add routing policy landed.
- [2026-09-21-filesystem-read-eval-hardening.md](2026-09-21-filesystem-read-eval-hardening.md)
  — filesystem read-eval hardening.
- [2026-09-21-filesystem-toctou-fault.md](2026-09-21-filesystem-toctou-fault.md)
  — filesystem record transport: probe/read race fails closed.
- [2026-09-21-vault-cutover-freshness.md](2026-09-21-vault-cutover-freshness.md)
  — vault cutover plus key-freshness rung.
- [2026-09-22-crumbs-db-schema-contracts.md](2026-09-22-crumbs-db-schema-contracts.md)
  — crumbs DB schema contracts (db-migration slices A + B).
- [2026-09-22-federal-branches-landing.md](2026-09-22-federal-branches-landing.md)
  — federal-branches occupancy slice 1: bailiff wire, executive guard,
  bead intake.
- [2026-09-22-oom-p3-ram-gate-alert.md](2026-09-22-oom-p3-ram-gate-alert.md)
  — RAM gate trip telemetry (OOM-prevention handoff P3).
- [2026-09-22-ram-guardrails-landing.md](2026-09-22-ram-guardrails-landing.md)
  — RAM guardrails plus dashboard automation controls landing.
- [2026-09-22-research-sweep-selfheal.md](2026-09-22-research-sweep-selfheal.md)
  — research sweep self-heal (gate-flap cure).
- [2026-09-22-router-alert-class-channel.md](2026-09-22-router-alert-class-channel.md)
  — router alert class channel.
- [2026-09-22-wiki-boundary-verdict.md](2026-09-22-wiki-boundary-verdict.md)
  — wiki boundary decided: no in-repo vault, docs/ records + research
  stay canon, prior_art word-overlap recall unchanged, embeddings
  deferred until measured degradation.

The harvest from 2026-09-01 onward was thin here on purpose: recent
work-slice facts lived closer to their surfaces (plan files, reports.md,
the changelog). That thin-index convention ended 2026-09-22, when the
index resumed with a dated batch backfill (the 2026-09-22 batch section
above); new records are indexed at birth from here on. The four
2026-09-09 rows above are the anchor records the documentation spine
ties itself to.

- Future records name their scope, evidence command, observed result, and
  remaining unknowns.

---

Back to the [documentation spine](../../README.md).
