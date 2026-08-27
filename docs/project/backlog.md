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
  the full governance loop through the bridge end to end, and the only
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
  governance loop from it — the disposable lane named in the session record
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

## Project journal + daily narrative (journal-daily)

- **Problem:** the project should be publicly observable day by day, but
  the raw record (records, check-ins, timeline) is not consumable prose.
- **Smallest useful outcome:** one automation renders each day's
  committed record/check-in/timeline into a dated narrative post
  (`docs/journal/YYYY-MM-DD.md`), the "accompanying the project"
  long-form description that a blog can publish.
- **Evidence:** `docs/records/2026-08-25-session.md`, checkin.md,
  timeline.md — the raw spine that becomes the story.
- **Risk:** narration must stay honest to the ledger — the automation
  only re-orders verified facts, never invents.
- **Dependencies:** the timeline events stream; a template over it.
- **Review trigger:** an independent read of a rendered journal entry
  matches the underlying record with no added claims.

## Long-form ebook: the megastructure memoir (ebook longform)

- **Problem:** the operator wants one long-form ebook documenting
  Hngh's development, self-bootstrapping, and the expansion into a
  megastructure, produced reproducibly.
- **Smallest useful outcome:** a `make journal` pipeline that
  assembles the day-by-day journal + the key records + the vision into
  one long-form document (Markdown → epub/mobi via pandoc or a script),
  versioned like any candidate.
- **Evidence:** the journal-daily piece; the session record; the
  intent/vision docs; `docs/records/*` as chapter seams.
- **Risk:** scope creep — the memoir must auto-assemble from existing
  prose, not demand new writing each run.
- **Dependencies:** journal-daily; a pandoc/asciidoc step.
- **Review acceptance:** `make journal-ebook` produces a deterministic
  document whose TOC maps the records.

## Self-hosted public surface (public-surface rung)

- **Problem:** the operator wants a public web on their own cloud
  (budget-scaled) — blog posting, comment collection/moderation,
  organization of practical interfaces to remote Hngh instances,
  leaderboards, and interaction between Hngh users/instances.
- **Smallest useful outcome:** one static+tiny-server site — journal
  posts (from journal-daily), a comment intake (moderated), a public
  readout of the Hngh queue (the dashboard), and a
  leaderboard-like "instances" page — self-hosted on a cheap VPS.
- **Evidence:** dashboard-readout (has the data), journal-daily, the
  self-funding scan.
- **Risk:** a public surface is a responsibility — moderation and
  rate-limits first; never expose secrets/stores.
- **Dependencies:** journal-daily, dashboard-readout, a hosting plan
  (budget-scaled).
- **Review acceptance:** the site serves the journal + readout from
  committed data, has a moderated intake, and no Hngh store is
  exposed.

## Device fleet bring-up (device-fleet)

- **Problem:** old hardware (an Android phone, a Steam Deck, a tired
  laptop with a slow NIC) can become local helper peers for Hngh's
  network and hardware-resource work.
- **Smallest useful outcome:** each device joins the local tailnet +
  an Hngh node (wake-peer ready), contributing bounded facts (uptime,
  load, network state) as evidence, with the same admission rules as
  the node lattice.
- **Evidence:** the node-lattice rung; wake-on-demand; the fleet
  vision.
- **Risk:** unattended low-power peers need the evidence-freshness /
  key-rotation story first.
- **Dependency:** node-lattice admission, key-rotation-freshness.
- **Review acceptance:** a device's facts appear in a ledger and it
  can be wake-peer'd under a certificate.

## Self-publishing / royalties pipeline (royalty-pipeline)

- **Problem:** income is a prerogative; automation should produce
  marketable fiction and nonfiction ebooks for royalties.
- **Smallest useful outcome:** a repeatable "book machine": prose
  pipelines (outline → draft → edit → cover → metadata) driving
  PDF/epub builds for Amazon KDP + direct sale, run the same way we
  run rotation slices.
- **Evidence:** the journal + the science-fiction worldbuilding for
  Hngh's megastructure; the world the operator wants to see built.
- **Risk:** royalties are speculative — the pipeline must produce
  *good* books, not just books; writer-reviewer separation applies.
- **Dependency:** the longform assembler; a build toolchain.
- **Review acceptance:** a produced book passes an independent read;
  the build reproduces from committed sources.

## Funding rails (funding-rails) — bootstrap income

- **Problem:** income is the prerogative; the scan names the cheapest
  immediate rails.
- **Smallest useful outcome:** stand up Shieldz (zero-fee crypto
  intake) + asterpay (x402→EUR/SEPA) for donations/royalty routes;
  a `pricing` page stub; the rails documented in the site.
- **Evidence:** self-funding-scan-2026-08-25.md.
- **Risk:** compliance — use the free complia screening before
  accepting counterparties; keep rails non-custodial until volume.
- **Dependency:** the public-site rung; an x402 receiving wallet.
- **Review trigger:** an independent reviewer accepts a test x402/
  crypto payment flows to the operator wallet end to end.

## Royalty catalog APIs (royalty-apis)

- **Problem:** the scan's abundance/listing pattern shows cheap
  pay-per-query AP
  easily monetized; a Hngh-derived small catalog can bring recurring
  royalties.
- **Smallest useful outcome:** 2-4 tiny, boring utility APIs (e.g.
  a policy-gate checker demo, a check-count, a timeline rendering)
  published as pay-per-query x402 on abundance / RapidAPI-style, each
  smoke-tested and priced.
- **Evidence:** self-funding-scan; the dashboard-readout / timeline
  functions are ready leaf-APIs.
- **Risk:** keep the public catalog read-only and sandboxed — the real
  ledger never leaves Hngh; the catalog is a *surface*, not an
  export.
- **Dependency:** funding-rail receipts; a stateless micro-API.
- **Review trigger:** an independent consumer calls the catalog API,
  pays, and gets a correct public result.

## Interface mocks (interface-mocks) — the mock matrix lane

- **Problem:** the operative layer is an interface *family* (panels,
  TUI, overlay, web, Emacs-style surface, voice), but only the TUI is
  real; the others are unproven concepts. We need cheap, graded mocks
  to pick which surfaces earn a build.
- **Smallest useful outcome:** one compact llm-trim-style panel mock
  (menubar/card popover), then the KDE overlay operative — each run
  through the automated interface grading loop before the next.
- **Dependencies:** the `grade-interface` loop (landed); the family
  matrix in `docs/design/assistant-interface.md`.
- **Review trigger:** an independent reviewer accepts the graded mock
  screenshots and ledger rows, not just the code.

## Operative overlay (operative-overlay) — qml6 floating operative

- **Problem:** the operative should float above the desktop — sprites,
  speech, buttons, scrolling text — not live only in a terminal. A
  plasmoid draws *under* windows; a standalone qml6 window is the
  correct X11 recipe.
- **Smallest useful outcome:** a frameless always-on-top transparent
  qml6 window showing the operative as an `AnimatedSprite` sprite
  sheet with speech, graded by the loop.
- **Dependencies:** the sprite-sheet assets (`pixel-agent-assets`);
  qt6-declarative (present); a research record exists.
- **Review trigger:** an independent reviewer accepts a captured
  overlay frame with a ledger grade and no daemon.

## Operative voice (operative-voice) — local character voices

- **Problem:** the operative is silent; speech should be a local,
  character-driven *rendering* of the textual record, never a gate.
- **Smallest useful outcome:** 3–5 distinct local neural TTS voices
  (piper / kokoro-82m) plus STT (whisper.cpp / sherpa-onnx) with
  push-to-talk, each operative persona voiced; record stays textual.
- **Dependencies:** a chosen TTS engine; the tts-research record.
- **Review trigger:** an independent reviewer accepts a rendered
  speech sample matching the persona, with the textual record
  unchanged.

## Pixel-agent assets (pixel-agent-assets) — the sprite sheet lane

- **Problem:** the operative's block-char figure is Atari-adjacent; the
  goal is a stick-figure-plus humanoid (head, neck, torso, arms, legs)
  with subtle motion — idle breathe, blink, coat sway — past that floor
  toward sprite animations.
- **Smallest useful outcome:** frame art for the operative's animation
  set, consumable by both the TUI and the overlay
  (`AnimatedSprite`); a comfyui image-gen practice lane refines the
  look.
- **Dependencies:** the family matrix; `interface-mocks` for where the
  frames render first.
- **Review trigger:** an independent reviewer accepts an animated
  frame sequence (idle/breathe/blink/sway) graded by the loop.

## CI governance gate (ci-governance-gate)

- **Problem:** CI failures surface as unstructured logs; nothing
  parses or resolves them, ceremonies do not auto-complete, and a
  pending commit can sit unevaluated. The operator wants any CI
  failure parsed and resolved through the governance loop, no pending commit
  left un-evaluated.
- **Smallest useful outcome:** a GitHub Actions adapter consumes an
  exported failure log as downstream evidence, runs the dogfood
  governance loop to complete or reject the pending commit, and refuses to
  re-run until the event is governance-resolved.
- **Evidence:** the ceremony-drive script and the promotion rung 18
  worker evidence fact; this entry.
- **Risk:** CI logs are untrusted input; parsing must refuse closed
  on malformed or oversized logs; the gate must not become an ambient
  watcher (operator-owned cron and state, no daemon).
- **Dependencies:** the governance loop (rung 9); a Gitea/Forgejo
  Actions second adapter once a pinned peer really runs Forgejo.
- **Review trigger:** an independent reviewer accepts a fixture where
  a failure log maps to one certificate-bound completion or rejection
  and a re-run refuses without a new event.

## Resource pool view (resource-pool-view)

- **Problem:** the fleet (local plus wide-area machines) is not yet a
  single pool; per-node status, duty, health, and capabilities are not
  surfaced together.
- **Smallest useful outcome:** one on-demand dashboard panel listing
  each admitted node as a row with status, duty, health, and
  capabilities; no ambient collector — the operator-owned heartbeat
  tick refreshes it.
- **Evidence:** the node-lattice groundwork (pinned peers, wake-peer,
  attestation); `dashboard-readouts`; this entry.
- **Risk:** rows must trace only pinned, evidence-backed claims; a
  node stays untrusted until pinned through the existing governance loop.
- **Dependencies:** node-lattice admission (`node-lattice-admission`),
  `pooled-hardware`, the dashboard panel machinery.
- **Review trigger:** a reviewer accepts a rendered pool page whose
  rows all trace to pinned, evidence-backed claims.

## Config manager (config-manager)

- **Problem:** system configuration is edited in place; rollouts are
  not evidence-backed or reversible.
- **Smallest useful outcome:** a per-node declared-config bundle whose
  intended state after apply is read back into evidence, a
  certificate-bound apply, and reversibility by reverting the
  declaration.
- **Evidence:** the mutation executor (`:commit` action); the worker
  substrate; this entry.
- **Risk:** configuration changes are high-band actions — the apply
  must recheck every evidence fact at the moment of mutation, and the
  revert path must exist without an untracked daemon.
- **Dependencies:** the mutation executor, the per-node worker,
  optional model patterns (NixOS, home-manager, apt-adjacent).
- **Review trigger:** an independent reviewer accepts a fixture where
  an applied and reverted config binds to evidence facts and a drift
  from the declared bundle refuses.

## Security manager (security-manager)

- **Problem:** key rotation freshness, secret hygiene, patch-state
  evidence, and incident-response evidence chains are not surfaced
  across nodes.
- **Smallest useful outcome:** per-node patch-state and key-freshness
  evidence rows (vintage of the secret scan, date of last rotate,
  patch delta) as machine-checkable facts; incident response is a
  transparent event-to-record-to-certify chain.
- **Evidence:** the `key-rotation-freshness` workload;
  `secret-scan-report`; this entry.
- **Risk:** patch and rotate metadata is perishable and must carry its
  own evidence; freshness attestations are easy to fake if the chain
  is not pinned.
- **Dependencies:** the resource pool view; the key-pin registry
  (rung 12).
- **Review trigger:** a reviewer accepts a freshness or secret finding
  that, alone or in a chain, refuses to certify a stale key.

## Notify agent (notify-agent)

- **Problem:** mail and job-search signals sit in inboxes; nothing
  reacts. The preparatory agentic work (draft a reply, first evidence,
  governance proposal) is manual.
- **Smallest useful outcome:** a KDE notification reaction agent —
  via `org.freedesktop.Notifications` and the probed notification
  daemon — receives an event and prepares a draft reply, evidence, and
  a governance proposal.
- **Evidence:** the desktop overlay and notification-daemon research;
  the tts/voice `omp say` note; this entry.
- **Risk:** notification payloads are untrusted UI content; the agent
  must treat them as hints, never as authorization, and stay
  operator-confirmed before any external side effect.
- **Dependencies:** a bounded reaction worker (Pi survey and the
  rung-18 worker); push via ntfy / Apprise as a follow-on.
- **Review trigger:** a reviewer accepts a fixture where a
  notification maps to a prepared, non-mutating artifact and never
  fires an ambient action.

## Push self-sufficiency (autonomy continuum 2026-08-26)

- **Problem:** verified commits stop at the local repo — pushing is an
  operator step, so origin lags the governance loop.
- **Smallest useful outcome:** hngh-automation's sweep pushes its own
  artifact commits once an origin remote exists; hngh's verified
  candidate commits push on governance completion (post-validation step,
  never a hook that could push a half-validated commit).
- **Evidence:** operator directive 2026-08-26; sweep governance record
  (`sweep: 2026-08-26 0946` commits in hngh-automation).
- **Risk:** pushing unpublished or credential-bearing material; the
  sweep surface already excludes code dirs, and hngh pushes only
  certificate-bound commits.
- **Dependencies:** an origin remote for hngh-automation (operator
  account action once); nothing new in hngh.
- **Review trigger:** a push receipt in the sweep breadcrumb and a
  governance record whose commit is visible on origin without operator
  action.

## Credential rotation automation (autonomy continuum 2026-08-26)

- **Problem:** single-use refresh tokens and pinned keys decay; today a
  decayed token surfaces as a 401 in STATE.md that only an operator
  resolves (2026-08-26 13:00Z token-refresh FAILED).
- **Smallest useful outcome:** a rotation/health job probes every
  credential the jobs use, refreshes or re-derives what it can
  unattended, files an `alert` report via report-queue for what it
  cannot, and never widens a trust boundary to work around a failure.
- **Evidence:** operator directive 2026-08-26; STATE.md 401 entry;
  existing `key-rotation-freshness` backlog entry (this folds into it).
- **Risk:** automated rotation failing open (new credential accepted
  without verification) — must fail closed and alert instead.
- **Dependencies:** key-rotation-freshness rung; the reviewer-transport
  file format (strict five-key parsing).
- **Review trigger:** a decayed-token fixture rotates unattended and a
  second fixture (unverifiable refresh) produces an alert report with
  no trust-boundary change.

## Cadence continuum (autonomy continuum 2026-08-26)

- **Problem:** periodicity exists only at the hourly/daily/night tiers;
  the continuum (month/week/day/hour/10m/5m/1m + ad-hoc) has no
  mounted surface.
- **Smallest useful outcome:** a tier router script + systemd units for
  each tier, each invocation exactly one tick, `make adhoc TIER=...`
  for manual firing; tiers with no mounted work exit 0 immediately.
- **Evidence:** operator directive 2026-08-26; existing unit pattern
  (hngh-automation/systemd).
- **Risk:** timer sprawl and overlapping ticks; single-tick + flock
  keeps each tier serial.
- **Dependencies:** hngh-automation job conventions; flock or
  equivalent single-instance guard.
- **Review trigger:** each tier fires its tick exactly once per period
  in a fixture, and an empty tier exits 0 with a breadcrumb only.

## Activity cadence (autonomy continuum 2026-08-26)

- **Problem:** routine project activities (roadmap review, planning,
  design, expansion, implementation, review, refactor, cleanup,
  inward/outward communication) run only when remembered, not on a
  continual schedule.
- **Smallest useful outcome:** an activity matrix mapping each activity
  to a cadence-continuum tier and an existing artifact
  (roadmap.md, queue.md, active-work.md, reports.md), with a
  single-tick runner that performs or files the next increment of each
  due activity; fleet-aware (fleet-manager peers can adopt rows).
- **Evidence:** operator directive 2026-08-26; queue.md Scheduling
  section; fleet-manager.
- **Risk:** busywork generation — each activity's smallest increment
  must be defined or the tick files a report instead of acting.
- **Dependencies:** cadence-continuum; report-queue; rotate-queue.
- **Review trigger:** one full week of the matrix running produces at
  least one real increment per activity and zero empty governance
  writes.

## Governance vocabulary (autonomy continuum 2026-08-26)

- **Problem:** "ritual"/"ceremony" are fussy and over-fixed for a
  governance vocabulary that should be flexible about governance,
  validation, and acceptance terms.
- **Smallest useful outcome:** docs use the flexible vocabulary
  (governance, validation, acceptance, admission) in prose; code
  symbols and CLI verbs stay stable until a check-in-scale candidate
  renames one surface deliberately.
- **Evidence:** operator directive 2026-08-26.
- **Risk:** symbol renames breaking scripts/tests — prose-only first.
- **Dependencies:** none.
- **Review trigger:** a terminology inventory shows no prose-only uses
  of the fixed terms without a deliberate governance meaning.

## Agent live view (autonomy continuum 2026-08-26)

- **Problem:** subagent work is visible only through the disjoint `hub`
  surface, not the dashboard, and the dashboard itself is insufficient
  for continual oversight.
- **Smallest useful outcome:** the dashboard reads a live agent/session
  roster (from the hngh store sessions plus any mounted agent
  transcripts) and renders working/idle/parked agents alongside the
  existing lanes; the roster refresh rides the existing watch/live
  loop.
- **Evidence:** operator directive 2026-08-26; dashboard-readout
  --live/--watch; `scripts/hngh present` store rendering.
- **Risk:** reading live transcripts as authoritative — display only,
  never governance input.
- **Dependencies:** ux-hardening; dashboard-readout spine.
- **Review trigger:** a running worker session appears in the live
  dashboard within one refresh period and disappears on close.

## Surface evolution loop (autonomy continuum 2026-08-26)

- **Problem:** operator-facing surfaces and megastructure parts evolve
  only by hand; there is no evolutionary design/development pressure.
- **Smallest useful outcome:** one evolution loop for one surface
  (dashboard style): candidate variants are generated, graded by the
  existing grade machinery, the fittest is promoted through a
  check-in-scale candidate; loop parameters live in a heartbeat card so
  the cadence drives generations.
- **Evidence:** operator directive 2026-08-26; dancing-ui probe,
  grade-interface, evolve-operative, ui-grades.md.
- **Risk:** runaway generation cost — bounded generations per tick via
  the card.
- **Dependencies:** cadence-continuum; grade-interface.
- **Review trigger:** N generations produce a measurably higher-graded
  variant promoted through the normal gates.

## Machine-steered backlog (autonomy continuum 2026-08-26)

- **Problem:** the next course is picked by fixed rules (queue Next +
  lane counts); Hngh does not determine its own best course on a
  continual basis.
- **Smallest useful outcome:** a course-selection step in the
  autonomous tick that reads the queue, lanes, reports, and roadmap as
  evidence, ranks next actions by a written policy, and mounts the
  chosen card — still behind the existing certificate gates for any
  mutation; its choice and reasons land in a report row.
- **Evidence:** operator directive 2026-08-26; run-autonomous tick;
  rotate-queue; backlog-lanes.
- **Risk:** self-steering circumventing policy — the selector may only
  mount work, never bypass a gate; every mutation still needs its own
  certificate.
- **Dependencies:** run-autonomous; report-queue; the activity cadence
  matrix as its input.
- **Review trigger:** a fixture where the selector's ranking differs
  from the static queue Next produces a justified choice report, and
  the mounted slice still passes the full certificate gate.

## Webapp dashboard (operator directive 2026-08-26)

- **Problem:** the current terminal dashboard is an eyesore and pops up
  automatically; the operator wants a browser-window webapp dashboard
  only when requested, handled deliberately, not a periodic popup.
- **Smallest useful outcome:** a webapp dashboard (browser window) that
  consolidates the hngh dashboard surfaces (lanes, reports, live
  agents, cadence) behind the existing hngh-automation
  dashboard service (or a successor), never auto-launching; opening it
  is an explicit operator action or an explicit timer-wired trigger.
- **Evidence:** operator directive 2026-08-26; hngh-automation
  dashboard.json + index.html; hngh scripts/dashboard-readout /
  dashboard-tui.
- **Risk:** duplicating the existing readout; reuse the --json spine as
  the only data source.
- **Dependencies:** agent-live-view roster; cadence-continuum.
- **Review trigger:** an operator opens the dashboard in a browser by
  intent; nothing auto-pops it; data matches the readout spine.

## Self-optimization continuum (operator directive 2026-08-26)

- **Problem:** the evolution/grading/steering loops target operator-facing
  surfaces and work slices, but Hngh's own operations (cadence placement,
  probe costs, timer hygiene, credential rotation, drop-in design) only get
  optimized reactively when a failure surfaces.
- **Smallest useful outcome:** a standing principle + mechanism where Hngh
  self-optimizes every part of its operations continually: the oversight
  tick's agentic leg gains a self-review mode that evaluates its own
  ticking costs/placement (which probes fit which windows, what fired
  on-change vs by-poll, what new cheap event hooks exist) and emits
  `optimize: <suggestion>` breadcrumbs; a 10m cadence drop-in collects
  them into a self-optimization ledger (`docs/project/self-optimize.md`)
  whose accepted suggestions ride the normal queue→card→ceremony path;
  nothing changes its own timer/unit definitions without a ceremony.
- **Evidence:** operator directive 2026-08-26; oversight-tick (agentic
  leg); cadence-continuum; surface-evolution-loop pattern.
- **Risk:** self-modification runaway — every change to Hngh's own
  operation still clears the same gates (proposal→verdict→certificate→
  mutation); suggestions are advisory until then.
- **Dependencies:** oversight-tick agentic leg; cadence tiers; queue/card
  ceremony path.
- **Review trigger:** a suggestion raised by the self-review mode is
  recorded, ranked with the queue, and only lands as a mutation through
  the certificate gate; the ledger shows a continual series.

## Hosted agentic interface (operator directive 2026-08-26 — "Hngh as an application")

- **Problem:** Hngh is a sidecar (kernel + timers + dashboard), not yet
  an application in its own right: a user cannot sit down with Hngh
  directly and have it fire up sessions and host its own instanced
  oh-my-pi / pi surface for interfacing with agentic Hngh.
- **Smallest useful outcome:** Hngh visibly firing up new sessions
  itself and hosting its own oh-my-pi/pi instance — an agentic
  interface where requests and steers reach the running Hngh as its
  own interactive session, not only through ceremony/timer paths.
- **Evidence:** operator directive 2026-08-26; r18 worker transport +
  worker-driver (bounded read-only worker lane exists); the omp/pi
  bridge concept; the nervous-system control-plane precept (#7).
- **Risk:** an agentic interface is an ambient process — the biggest
  departure from "no daemon." Mitigate: the interface itself stays an
  on-demand session host (fired by an explicit start / a steered
  event), never a background service; every action it takes still
  flows through the certificate gates.
- **Dependencies:** worker-driver/bridge-hosted end-to-end session
  (roadmap Next), the pi/oh-my-pi host surface, the dashboard webapp
  as the read side.
- **Review trigger:** a user opens the hosted interface, watches Hngh
  fire up a new worker session from it, and the session's actions land
  only with their certificates; nothing ambient runs without an
  explicit start.

## Hosted agentic interface — navigable + auto-tiling sessions (operator refinement 2026-08-26)

- **Problem (extends `hosted agentic interface`):** beyond firing sessions,
  the operator wants *readouts for all scheduled agent runs* (a navigable
  gantt) and *navigable, auto-tiling sessions* for the agentic interface —
  short-term and long-term views of Hngh runs, so Hngh visibly builds and
  uses itself rather than relying on oh-my-pi as the builder.
- **Smallest useful outcome:** the webapp gains the navigable gantt
  (scheduled runs readout — the ASAP slice); the hosted interface
  (backlog `hosted agentic interface`) then gains navigable sessions
  with auto-tiling (tmux-like tiles per run), gantt-adjoining the
  schedule, both driven by the same evidence/spine (never fabricate
  dates; timeline events anchor, queue items are planned ghosts).
- **Evidence:** operator directive 2026-08-26; `queue-eta` widget;
  `timeline-events`; the webapp (a2ae5fc) + spine; `hosted agentic
  interface` entry.
- **Risk:** fabricating dates/claims — the gantt renders only real
  timeline events + planned (ghost, ETA tooltip) queue rows; the
  tiling sessions are read-only views of runs, never governance input.
- **Dependencies:** gantt panel (dispatch in flight); hosted agentic
  interface (bridge/worker-driver rung); webapp panels.
- **Review trigger:** an operator-browser gantt shows today's real
  rotation events + future queued ghosts with ETA tooltips, and a
  session host tiles all open Hngh runs (navigable, live).

## OMP↔Hngh bridge plugin (operator directive 2026-08-26 — Hngh improves Hngh)

- **Problem:** Hngh is bootstrapped by OMP ad-hoc (launch an omp instance
  in the project dir, ask agents to orient); we're not taking advantage
  of Hngh itself to improve Hngh. The operator is OK using a plugin that
  directly interfaces oh-my-pi with Hngh while Hngh grows toward hosting
  its own sessions.
- **Smallest useful outcome:** an omp plugin that connects oh-my-pi
  sessions to Hngh's governance surfaces directly — so work ON Hngh
  runs through Hngh's own rules (ceremony-gated commits, roguelike
  watchdog visibility, wired-state lens, oversight alerts) rather than
  as a parallel ad-hoc lane. Reuse oh-my-pi's existing session/tool
  structure; add a thin Hngh-facing adapter, not a rewrite.
- **Evidence:** operator directive 2026-08-26; precept 11 (Hngh improves
  Hngh); worker-driver r18; `hosted agentic interface` + `bridge-operator
  -host` backlog entries; the roguelike watchdog + agent-handoffs ledger.
- **Risk:** coupling omp to hngh too early — the plugin must be a sided
  adapter (omp keeps its structure; hngh kernel stays side-effect-free),
  failures fail closed, no new daemon.
- **Dependencies:** `bridge-operator-host` rung; worker-driver; the
  watchdog/handoff surfaces.
- **Review trigger:** a session invoked through the plugin lands its
  commit through Hngh's certificate gate and its session is visible in
  the watchdog/handoff ledger; the same rules apply whether the agent
  is working in Hngh or on Hngh.

## Command center — CLI + GUI operator surfaces (operator directive 2026-08-26)

- **Problem:** there's no real "command center": no flexible ever-
  expanding agentic interface for a system harness; we use oh-my-pi
  ad-hoc. The operator needs BOTH a command-line and a GUI Hngh
  interface, each with flexible readouts and simple controls for
  summoning and scheduling agents for various purposes.
- **Smallest useful outcome (needs-first):**
  - CLI: `scripts/hngh` grows a `schedule` / `summon` surface (see
    agentic-interface rung) — operator types an ask, sees it considered
    + contrasted with existing features, sees it slotted into the
    active schedule.
  - GUI: the webapp becomes the command center (see webapp rungs +
    agentic-interface) — same surfaces, clickable.
  - **Expedite visibility:** a user can ask for an expedite and SEE the
    impact (what it accelerates, any cascading delay to other scheduled
    work/maintenance) at any degree of expedite.
  - **Subagent view+control:** subagent views accessible alongside any
    main Hngh instance / attached session; users can identify and PAUSE
    a misbehaving subagent, highlight/name the unwanted behavior for
    Hngh's correction.
- **Evidence:** operator directive 2026-08-26; webapp (live :8890);
  roguelike watchdog + agent-handoffs; `hosted agentic interface`,
  `OMP↔Hngh bridge plugin`, `machine-steered-backlog` backlog entries.
- **Risk:** scope creep — needs-first: build what the operator must SEE
  first (awareness: runs/schedule/subagents/system), then what's nice;
  no daemon until the bridge rung proves it needs one.
- **Dependencies:** machine-steered-backlog (scheduling+completing own
  development), hosted agentic interface + OMP↔Hngh bridge (summon/
  schedule controls), system awareness rung (harnessing hardware/
  software/network), watchdog pause/highlight surface.
- **Review trigger:** an operator opens either interface, types an ask
  about Hngh's development, sees it considered, expedited with visible
  ripple impact, and can pause+label a misbehaving subagent from the
  subagent view — all without leaving the interface.

## System awareness rung (operator directive 2026-08-26)

- **Problem:** Hngh should maintain steady awareness of its surrounding
  system, using hardware/software/network resources to suit its own
  development and expansion — currently it only sees its stores/timers.
- **Smallest useful outcome:** the oversight tick + dashboard surface
  live system health (CPU/mem/disk/net, tailscale/fleet peers, model
  server health, resource headroom) as read-only awareness
  (fleet-manager already probes some); the agentic leg can name
  resource-based steers (e.g. "network down — pause network-labeled
  jobs").
- **Evidence:** operator directive; fleet-manager --discover;
  probe-model-route; credentialed network probes.
- **Risk:** awareness becoming ambient control — keep it read-only
  awareness feeding steer suggestions, never implicit mutation.
- **Dependencies:** cadence-continuum + oversight tick; fleet-manager.
- **Review trigger:** the dashboard shows live system-resource state,
  and a resource change (e.g. network loss) produces a steer/alert
  without any hidden action.

## Time ledger & delay flagging (self-optimization telemetry)

- **Problem:** Hngh aims to be self-optimizing, but operation wall-times
  live in scattered places (ceremony-drive `[ceremony-timing]` lines,
  systemd journal, suite walls, agent-wave reports) and get reviewed
  only when a human notices slowness. Excessive delays — like the
  2026-08-27 autonomy-tick wedge that sat failed for hours — should be
  noticed procedurally.
- **Smallest useful outcome:** one rolling time-ledger artifact
  (per-unit last/p50/max wall seconds, per-ceremony-step milliseconds)
  plus one oversight check that flags any operation exceeding
  max(2× its trailing median, floor) as a flap-suppressed alert row
  feeding the existing steer path.
- **Evidence:** the 2026-08-27 delay-ledger review
  (`records/2026-08-27-operator-items-closeout.md`,
  `records/2026-08-27-acceleration-wave.md`); measured wins already
  banked (untracked-artifact tax 6312→25 rows; ceremonies 40s→~3s).
- **Risk:** measurement load; alert noise; thresholds tuned to hide
  real drift — flap suppression and a small fixed floor keep it honest.
- **Dependencies:** oversight-tick alert path; systemd unit metadata;
  ceremony-timing lines; the report ledger.
- **Review trigger:** a seeded synthetic delay in a fixture run is
  flagged once, flap-suppressed after, and the ledger round-trips
  real unit timings.

## Session observatory (live subagent runs page)

- **Problem:** delegated agent runs are invisible while they run: the
  watchdog sees deaths, the roster shows counts, and neither offers an
  operator a navigable view of live sessions with their output.
- **Smallest useful outcome:** a read-only webapp page listing every
  session with state filters and a per-session detail pane (fields +
  bounded, redacted transcript tail), syntax highlighting, two themes,
  auto-refresh with honest staleness stamps.
- **Evidence:** operator directive 2026-08-27 (dedicated browser window
  welcome; multiple pages/styles/purposes intended); interface-plan
  S4/M6; master plan P4 navigable sessions.
- **Risk:** transcript surfaces touch operator home directories —
  read-only, bounded tails, secret-redaction at the feed boundary; the
  page must never render, let alone feed, governance input.
- **Dependencies:** `readout.json` roster spine; omp session surfaces;
  the refresh-dashboard feed pattern; browser relay for operator view.
- **Review trigger:** the page renders fixture sessions byte-identical
  to store records, redaction provably fires, and no canonical field
  is consumed for any decision.

## Browser notification surface

- **Problem:** attention-worthy events (alert rows, verdict flips)
  reach the operator only when a dashboard pane is being watched.
- **Smallest useful outcome:** opt-in browser notifications via the
  relay page for alert-class rows and verdict flips — digest-level,
  one-shot, flap-suppressed, zero default-on.
- **Evidence:** operator directive 2026-08-27 (browser notifications
  welcome alongside other channels).
- **Risk:** nagging; notification permission creep — the buddy rule
  (summoned, never nagging) applies: one notification per flap window.
- **Dependencies:** session observatory page host; report ledger
  cursor.
- **Review trigger:** a fixture alert produces exactly one
  notification and the toggle defaults off.

## Emacs-style surface configurability

- **Problem:** surface behavior (themes, refresh intervals, panel
  toggles, thresholds) is hard-coded per script; the operator wants
  declarative, layered configuration across all Hngh interfaces.
- **Smallest useful outcome:** one user config file
  (`~/.config/hngh/ui-config.*`) read at render/feed time, layering
  operator overrides over built-in defaults for display preferences —
  theme, refresh interval, visible panels, alert thresholds.
- **Evidence:** operator directive 2026-08-27 ("emacs-style
  configurability intended").
- **Risk:** config becoming a second authority — config is
  display/ops-preference only and can never carry governance fields
  (presentation-boundary law applies to configuration too).
- **Dependencies:** the dashboard/observatory surfaces it configures.
- **Review trigger:** the first config key ships with a fixture test
  proving governance fields in the config file are refused.

## Model-tier refresh cadence

- **Problem:** route and cost assumptions drift as providers change
  pricing and capability (the GLM 5.3 Flash workhorse window ends
  2026-09-09); BENCH_MODELS rot was already observed (MiniMax-H3 0/5).
- **Smallest useful outcome:** a quarterly re-bench + route review
  that lands a `route:` report row naming the current workhorse,
  runner-ups, and any model dropped from BENCH_MODELS.
- **Evidence:** `7a4041e` (MiniMax-H3 drop); the 2026-08-27 workhorse
  directive (GLM 5.3 Flash through Sept 9).
- **Risk:** benchmark churn; over-fitting to single-run scores —
  keep 0/5-twice as the drop rule.
- **Dependencies:** model-bench job; probe-model-route.
- **Review trigger:** the next quarterly bench lands a route report
  row even when nothing changes.
