# Backlog

No runtime feature is admitted before its policy proposal and required run-domain
or application contracts are fixture-backed. A proposal must name its problem,
smallest useful outcome, source manifest, principle matrix, risk note,
dependency, and evidence trigger.

Potential future work belongs here only with a problem statement, smallest
useful outcome, source or evidence, risk note, dependency, and review trigger.

## Pi read-only delegation spike

- **Problem:** Hngh has no admitted disposable agent worker, while future
  source-grounded reconnaissance and independent review need a bounded worker
  substrate.
- **Smallest useful outcome:** a manually launched Pi RPC worker in a disposable
  directory can run one fixture-backed, read-only scout or reviewer task with
  an explicit route, no session persistence, no ambient discovery, no mutation
  tools, and a bounded receipt.
- **Evidence:** `docs/records/2026-08-13-pi-worker-and-delegation-survey.md`.
- **Risk:** third-party extensions execute in the Pi worker process and Pi tool
  policy is not OS-level isolation; provider and search credentials, session
  state, child processes, and recursive delegation must remain unavailable by
  default.
- **Dependencies:** a Pi adapter proposal; a process/environment isolation
  design; fixture fakes for the application ports; a cost/loadout policy; and
  the eight fixture gates named by the Pi survey.
- **Review trigger:** an independent reviewer accepts the fixture results,
  child-process cleanup proof, route/cost receipt, and unchanged fixture
  repository manifest. A successful worker self-report is not acceptance.

## Node lattice rung (megastructure mesh)

- **Problem:** a single Hngh node can only learn from its own wall. The
  operator's planned fleet — an old Android phone, a Steam Deck, a slow
  laptop with a tired NIC — has no admission path today, and the two
  capabilities that make a fleet useful (waking a machine on demand,
  keeping tunnels open without a watching daemon) both touch the outside
  world in ways the current boundary explicitly does not admit: ambient
  execution and network side effects.
- **Smallest useful outcome:** one operator command that admits a second
  node as a pinned federation peer, exchanges bounded learned facts in
  both directions (each fact a citable `:remote-attestation` claim), and
  issues a single wake-on-demand request through the same one-action
  certificate machinery — still no daemon, no scheduler, no ambient
  execution; every request is an explicit, recorded, human-closable step.
- **Source or evidence:** the root README `Where this is going` section
  (node-lattice vision, 2026-08-25); the federation port, pinned-key
  registry, and signature-verification transport (promotion rungs
  11–12) as the admitted substrate; this entry.
- **Risk:** the network surface grows again — federation fetch is the
  watch-item the 2026-08-25 external sanity check named for exactly this
  moment; wake-on-LAN is an external side effect that must ride the
  mutation lane with real evidence (MAC, current lease, last-seen fact);
  low-powered peers are unattended, so key rotation and evidence
  freshness need closed handling before any ambient trust; and the
  no-daemon boundary is a kernel invariant — any future "keep the tunnels
  open" mechanism must first amend that boundary through its own policy
  proposal, not smuggle a watcher in through an adapter.
- **Dependencies:** the policy-profile rung (operator-tunable requirement
  kinds), the network claim methods behind the federation port, and a
  boundary-amendment proposal that names exactly which ambient operation
  (if any) is admitted and under what evidence.
- **Review trigger:** an independent reviewer accepts the admission and
  wake flows against fixtures (pinned peer identity, stale or missing
  last-seen refuses, one-request-one-certificate, no ambient process
  after the request completes) and sees no watcher, scheduler, or
  background process in the diff.
## Governance property tests

- **Problem:** the principle matrix must be total over the closed kinds and
  monotone with respect to evidence, but neither property is explicitly
  tested today.
- **Smallest useful outcome:** property tests asserting (a) every closed
  proposal class and principle kind yields a verdict (totality over closed
  kinds) and (b) dropping evidence can never flip a verdict DENY to ALLOW
  (monotonicity: ignoring evidence never flips DENY -> ALLOW).
- **Evidence:** `docs/records/2026-08-24-prior-art-landscape.md` — the
  in-toto monotonic principle adopted as an invariant.
- **Risk:** property tests are only as good as their generators; the closed
  vocabularies must stay in sync with the domain definitions.
- **Dependencies:** the deterministic principle evaluator and its closed
  vocabularies (already in place).
- **Review trigger:** an independent reviewer accepts the property suite and
  sees it fail on a deliberately introduced totality or monotonicity break.

## DSSE envelope export serializer

- **Problem:** Hngh certificates are structurally in-toto-like today, but
  nothing exports them in an interoperable grammar, so external tooling
  cannot consume them.
- **Smallest useful outcome:** a serializer that renders certificates and
  their evidence into a DSSE (or in-toto) envelope for external consumption.
- **Evidence:** `docs/records/2026-08-24-prior-art-landscape.md` — DSSE
  named as the future export grammar.
- **Risk:** none while gated; building the wrong envelope shape before an
  interop partner exists would be speculative.
- **Dependencies:** YAGNI-gated: only admitted once an interop consumer (or
  a partner requirement) exists.
- **Review trigger:** an interop need is named; an independent reviewer
  accepts the envelope against the DSSE/in-toto spec.

## Governance-benchmark research lane

- **Problem:** no public benchmark measures governance properties, so Hngh
  cannot compare itself to anything or be compared by anyone.
- **Smallest useful outcome:** a survey of existing agent-safety evals
  (AgentDojo github.com/ethz-spylab/agentdojo, InjecAgent, R-Judge) and a
  draft metric set: tamper-evidence, approved equals executed, and
  reconstruction-from-record.
- **Evidence:** `docs/records/2026-08-24-prior-art-landscape.md` — the
  governance-benchmark gap; AgentDojo/InjecAgent/R-Judge named as prior art.
- **Risk:** this is a research lane, not a feature; it must not become a
  benchmark-building project without separate admission.
- **Dependencies:** nothing from the runtime; survey plus draft metrics
  only.
- **Review trigger:** an independent reviewer accepts the survey and the
  metric definitions as a sound basis for a later benchmark proposal.

## Dogfood loop (future rung candidate)

- **Problem:** Hngh has never governed a real change to its own repository
  end to end, so the evidence -> review -> certification -> mutation cycle
  is untested against itself.
- **Smallest useful outcome:** Hngh proposes, evaluates, and commits changes
  to itself via its own harness ("the phoenix's egg"; zero new machinery;
  exercises evidence, review, certification, and mutation against its own
  repo).
- **Evidence:** `docs/records/2026-08-24-prior-art-landscape.md` —
  strategy sequencing step two, after the operator-facing command surface.
- **Risk:** the dogfood loop must remain optional; it cannot become the
  mechanism by which Hngh approves its own roadmap.
- **Dependencies:** the operator-facing command surface (roadmap Next) and
  real transport admission come first.
- **Review trigger:** an independent reviewer accepts the self-committed
  change and its certificate chain.

## Operator policy profiles (policy-profile rung)

- **Problem:** rungs 6/11/12/13 added verified, real transports (model
  review, attestation envelopes, pinned keys, operator reviewer files)
  but no shipped policy profile *consumes* their fingerprints. The
  dogfood proposal profile is still the fixture-grade "one requirement
  per matrix principle"; review facts and `:remote-attestation` facts are
  recorded evidence with no requirement kind that can demand them.
- **Smallest useful outcome:** an operator-tunable policy profile — a
  named, parsable, fail-closed spec that maps requirement kinds
  (`:claim-proof`, `:review`, `:remote-attestation`, `:purpose`,
  `:caller`) to matrix principles, admitted via the existing `propose`
  surface (profile=FILE, mirroring the verdict/pins/reviewer file
  precedents), with the closed evaluator unchanged.
- **Evidence:** `docs/records/2026-08-25-r13-operator-reviewer-transport.md`
  (reviewer transport live); `docs/records/2026-08-24-design-distributed-attestation.md`.
- **Risk:** a profile must never *broaden* admission beyond the matrix;
  it only *narrows* which requirement kinds a proposal must satisfy.
- **Dependencies:** the deterministic principle evaluator and its closed
  vocabularies (present); rung-13 reviewer transport (present).
- **Review trigger:** an independent reviewer accepts (a) a profile
  file that demands `:review` evidence fails a proposal lacking review
  facts, and (b) the same profile admits a proposal carrying them.

## Bridge-backed continual worker (worker-rung candidate)

- **Problem:** the intent document names a worker behind a port — "likely
  one called Pi" — but the scaffolded hngh-omp bridge plugin (7/7 smoke)
  drives nothing, and the only continual workers are the shell jobs in
  hngh-automation, which cannot exercise Hngh's own run lifecycle.
- **Smallest useful outcome:** a disposable, read-only worker omp session
  (local Ornith/Qwen via the automation's own model chain) that can
  open one run, gather read-only candidate evidence, run one `review`
  through the operator reviewer transport, and close the run — driven
  through the hngh-omp bridge tools, with the run ledger as the record.
- **Evidence:** `docs/records/2026-08-13-pi-worker-and-delegation-survey.md`
  (Pi survey); hngh-omp plugin scaffold; rung-13 reviewer transport.
- **Risk:** the worker is read-only by default and never carries a
  mutation certificate; a worker self-report is not acceptance.
- **Dependencies:** the bridge plugin (present); rung-13 operator
  reviewer file (present); a loadout that admits `:model` transport.
- **Review trigger:** an independent reviewer accepts the disposable
  worker's run receipt, its review evidence, and an unchanged fixture
  manifest — the same gates the Pi survey named.
