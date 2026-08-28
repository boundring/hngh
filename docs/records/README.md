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
- `2026-08-18-task-r7-presentation-and-composition.md` records the
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
- Future records name their scope, evidence command, observed result, and
  remaining unknowns.
