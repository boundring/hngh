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
- **Dependencies:** the federation surface (rungs 11–15) and policy
  profiles (rung 16) are in place; the pending pieces are the
  certificate-bound wake chain and a boundary-amendment proposal that
  names exactly which ambient operation (if any) is admitted and under
  what evidence.
- **Review trigger:** an independent reviewer accepts the admission and
  wake flows against fixtures (pinned peer identity, stale or missing
  last-seen refuses, one-request-one-certificate, no ambient process
  after the request completes) and sees no watcher, scheduler, or
  background process in the diff.

## Certificate-bound wake mutation lane (boundary amendment)

- **Problem:** rung 17's `wake-peer` issues an explicit request through
  an injected transport, but the request itself is not certificate-
  bound — a wake is an external side effect and ought to ride the same
  one-action certificate machinery as a commit, with real evidence
  (MAC, current lease, last-seen fact) rechecked immediately before the
  action, exactly as the node-lattice entry's risk section demands.
- **Smallest useful outcome:** a `:wake-mutation` action in the
  mutation vocabulary: one certificate for one wake of one pinned
  peer, rechecked against fresh evidence, executed behind the mutation
  executor port, refused on stale or missing facts.
- **Source or evidence:** `docs/records/2026-08-25-r17-wake-peer.md`;
  the mutation executor (rung 5) and the candidate certificate.
- **Risk:** a wake must never be a blanket "wake anything" — the
  certificate binds peer, method, and evidence; the evidence-first and
  atomic-mutation principles apply unchanged.
- **Dependencies:** the rung-17 wake surface and the mutation vocabulary
  (the policy-profile rung is complete and available for the new
  action's requirement map).
- **Review trigger:** an independent reviewer accepts that a stale,
  missing, or extra-evidence wake certificate refuses; only the
  certificate-bound single wake executes.

## Ambient-free tunnel keepalive (boundary amendment)

- **Problem:** "keeping the tunnels open without a watching daemon"
  touches ambient execution, which the no-daemon boundary does not
  admit; the node-lattice vision needs a mechanism that keeps a
  persistent tunnel (Tailscale) alive without a watcher, scheduler, or
  background process.
- **Smallest useful outcome:** a bounded, explicit, operator-invoked
  keepalive policy file that names which tunnel endpoints may be
  refreshed, and a single `keepalive` command that checks the tunnel
  state, refreshes only if the certificate binds the exact endpoint,
  and records the receipt — no process runs after the command exits
  (the operator's own scheduler/tee runs the periodic invocation).
- **Evidence:** the intent doc's "keep the corridors open without a
  watching process"; the wake-on-demand precedent (rung 17).
- **Risk:** any ambient process would violate the boundary; the command
  stays explicit and process-local, the periodic invocation lives
  outside Hngh (the operator's scheduler), never inside it.
- **Dependencies:** the tunnel tooling (Tailscale), the mutation lane
  once it exists, the network admission surface.
- **Review trigger:** an independent reviewer accepts that no daemon,
  watcher, or scheduler is installed by Hngh; keepalive is a plain
  one-shot invocation with a receipt, and the policy names endpoints
  exactly.

## Governance property tests — COMPLETED (2026-08-24)

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

## Dogfood loop — COMPLETED (promotion rung 9, 2026-08-24; hardened by the loop-history guard 2026-08-25)

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

## Operator policy profiles — COMPLETED (promotion rung 16, 2026-08-25)

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
  one called Pi" — and the bridge now surfaces the worker lane
  (`hngh_run_worker`, `worker-driver`), but no agent thread yet drives
  the full ceremony through the bridge end to end, and the only
  continual workers are the shell jobs in hngh-automation.
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

## Node-lattice admission rung (implementation) — queued 2026-08-25

- **Problem:** a single Hngh node learns only from its own wall; the
  operator's planned fleet (an old Android phone, a Steam Deck, a
  tired-NIC laptop) has no admission path, and the two capabilities
  that make a fleet useful (waking a peer, keeping tunnels open
  without a watcher) both touch the outside world in ways the current
  boundary does not admit.
- **Smallest useful outcome:** one operator command admits a second
  node as a pinned federation peer with an offline fingerprint;
  bounded remote-attestation facts flow both ways (each a citable
  claim); the first wake-on-demand rides the certificate machinery; no
  daemon, no scheduler — every request is a single explicit, recorded,
  human-closable step.
- **Evidence:** README `Where this is going` node-lattice vision
  (2026-08-25); intent.md; the federation port, pinned-key registry,
  and signature-verification transport (rungs 11–12); http-claim
  (r15); wake-peer (r17).
- **Risk:** the network surface grows again — federation fetch is the
  watch-item the 2026-08-25 external re-review named; low-powered
  peers are unattended, so key rotation and evidence freshness need
  closed handling; the no-daemon boundary stays a kernel invariant.
- **Dependencies:** the certificate-bound wake lane (so a wake rides
  the certificate); a boundary amendment naming exactly which ambient
  operation (if any) is admitted; the policy-profile map for admission
  requirement kinds.
- **Review trigger:** an independent reviewer accepts the two-node
  admission and wake flow against fixtures (pinned identity,
  stale/missing last-seen refuses, one-request-one-certificate) and
  sees no watcher, scheduler, or background process in the diff.

## Documentation-sync loop — queued 2026-08-25

- **Problem:** the check count and command/rung lists in README and
  the roadmap drifted three separate times across 2026-08-25 and were
  hand-corrected; the loop-history guard watches commits, not the
  docs' numbers.
- **Smallest useful outcome:** a `make numbers` target that recomputes
  the live check count, rung prose, and CLI command list from the
  committed suite and surface, plus a small guard test asserting the
  README/roadmap numbers match ground truth — drift is caught by
  `make test` instead of by a human.
- **Evidence:** the 2026-08-25 consistency pass (README count and
  command surface hand-corrected across the day); the records-index
  gap fixed the same day.
- **Risk:** the guard must only verify, never auto-rewrite; docs stay
  human-folded, the guard fails loudly on divergence.
- **Dependencies:** the existing `make test` suite (whose count is an
  input) and the surface the numbers describe.
- **Review trigger:** an independent reviewer sees a deliberately
  desynced README number fail the guard, and a synced one pass.

## Bridge-as-operator-host — queued 2026-08-25

- **Problem:** the bridge has the full 10-tool surface (including
  `hngh_run_worker`) and its own repo, but no thread drives the whole
  ceremony from it — the disposable lane named in the session record
  (run → worker → review → certify) is still unlaunched on the bridge.
- **Smallest useful outcome:** an operator in the bridge drives the
  full step-set — open a run, admit the worker, run the worker, bind
  the review, certify one mutation — with the ledger as the sole
  receipt; the session stays disposable (nothing persists beyond the
  ledger).
- **Evidence:** the hngh-omp bridge README; the 2026-08-25 live
  worker lifecycle; r13 operator reviewer file.
- **Risk:** a host surface is not free flexibility — the bridge is a
  trusted operator seat; each certificate still binds one action, and
  no daemon or ambient automation sits behind the tools.
- **Dependencies:** the bridge (present); the worker-driver
  no-transport refusal (present); the r13 reviewer file (present); a
  loadout admitting `:model` for the review step.
- **Review trigger:** an independent reviewer accepts a run receipt
  that flowed run → worker → review → certify, and a repeat step
  refuses minimally when an admission is missing.

## Evidence-freshness + key-rotation rung — queued 2026-08-25

- **Problem:** the lattice peers are unattended, and the node-lattice
  risk names key rotation and evidence freshness as closed concerns —
  today the pinned registry supports changing keys but nothing rotates
  them atomically or marks a peer stale by last-seen age.
- **Smallest useful outcome:** closed key rotation on the pinned
  registry (one key per peer replaced, never reduced to zero, refused
  if the resulting set is unrecognizable) plus a stale-evidence rule
  on remote-attestation facts — a peer whose last-seen fact is older
  than an operator-set bound flips `:stale` and refuses wake,
  fail-closed.
- **Evidence:** the node-lattice and the two boundary proposals (key
  rotation, evidence freshness); `parse-pinned-keys` (r12) as the
  rotation substrate.
- **Risk:** rotation is a state-mutating operator action — ride the
  mutation lane, one certificate per rotation; a stale peer must not
  cascade into refusing healthy-peer wake.
- **Dependencies:** the mutation lane (or the existing candidate
  certificate for a pure registry rotation); the pinned registry and
  remote-attestation values.
- **Review trigger:** a test suite proves an old peer refuses wake,
  a rotation that would empty the registry refuses, and a healthy,
  fresh, rotated peer passes.

## Gantt ports (gantt-ports) — interface-expansion rung

- **Problem:** one dashboard readout is a fine start, but the operator
  wants gantts like they want weather: all kinds. Axial and circular
  clock-face rings, animated spirals, wobbling, dancing, "crazy" —
  the whole instrument panel should be portable to any gantt dialect
  the operator fancies, each reading the same committed timeline
  spine.
- **Smallest useful outcome:** the readout gains a `--style` switch
  with (at least) `linear`, `circular` (clock-face rings), and
  `spiral` (already exists) renderers, all over the same spine; each
  renderer smoke-tested like `--spiral` is today.
- **Evidence:** `scripts/dashboard-readout` (linear + spiral both
  live); the timeline spine (`docs/project/timeline.md`) + ETA
  windows as the shared data.
- **Risk:** rendering options multiply — keep each style a tiny pure
  function over the same rows; don't let styling infect data.
- **Dependencies:** the dashboard-readout spine (present); each new
  style is check-in-scale.
- **Review trigger:** an independent run of each style renders the
  same rows/ETAs, and the smoke test covers every style (fails on a
  missing/renamed renderer).

## Dancing interfaces (dancing-ui) — the music runs the room

- **Problem (deliberately weird):** interfaces are static; the
  operator wants the whole system to *dance in time to music playing
  on the machine*, intensity varying with the track — a UI that
  breathes, pulses, and glides with the beat. Pure delight; it must
  never obscure the data.
- **Smallest useful outcome:** one probe reads the system's audio
  signal (pulse audio/pipewire intensity, or when unavailable a
  constant BPM/no-op) and maps it to an intensity value; the
  dashboard applies it as a set of `--dance` amplitude classes
  (subtle pulse on the ETA bars). A human can toggle it off; it never
  changes a decision.
- **Why probe first:** feasibility (reading system music, mapping to a
  UI amplitude) before committing the full dance to all interfaces.
- **Risk:** music-driven motion must not become motion-sickness or
  performance drag; it is a display-only layer under the pass-thru
  data, no daemon.
- **Dependencies:** the dashboard-readout; the audio source probe.
- **Review trigger:** an independent reviewer accepts that the `--dance`
  mode pulses to an injected fake intensity, is disabled by default,
  and renders the data identically when off.
