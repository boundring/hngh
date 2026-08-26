# Roadmap

## Direction

Hngh is being rebuilt as a small, predictable core that decides what is valid, with the messy outside world — files, Git, models, terminals — plugged in later at the edges. Each step of the rebuild exists for a reason: evidence comes before claims, so nothing is believed without a record; permission is re-checked at the moment of action, so a certificate is never a free pass; and reviewers advise but never decide, so a model can suggest, but only a policy verdict can admit. The path runs from the pure kernel, to a read-only evidence adapter, to a mutation executor, to bounded model review and agent workers behind ports — all under policy verdicts and one-action certificates. For the vision in full, read [the intent document](../intent.md).

## Now

Current frontier: the clean-slate baseline, now self-governing. The retired daemon and plugin system is archived and not part of the active product. The active kernel contains pure profile and run-domain policy, six fake-backed application use cases, governance C0–C3: the proposal-evidence ledger, deterministic principle evaluation, the failure-disposition policy, and the candidate authorization certificate, plus the read-only evidence adapter (promotion rung 4), the fixture-backed mutation executor (promotion rung 5), the bounded model-review adapter (promotion rung 6), the composition root and operator-visible presentation (promotion rung 7), the operator-facing command surface with local filesystem transport admission (promotion rung 8), the self-governed dogfood loop (promotion rung 9), the bounded model and terminal worker transports behind closed loadout admission (promotion rung 10), the distributed attestation and evidence federation slice (promotion rung 11), the operator pinned-key registry and signature-verification transport (promotion rung 12), and the operator reviewer transport verified live against the local model server (promotion rung 13).
### Completed

- Sealed the retirement boundary: the archived prior system is external and
  no longer verified (`make check-archive` retired 2026-08-19); the obsolete
  Mission Control desktop launcher was retired, its bytes preserved in a
  supplemental archive receipt.
- Published the Clean Architecture charter, component map, test boundary, and presentation boundary; added fixture guards for inward dependency direction and renderer-only reference lexicons.
- Specified and tested the pure run domain: closed lifecycle, typed refusal, validated mission/role/loadout values, and non-authoritative evidence values.
- Added the read-only reader guard to the fast gate (`make test` runs 8 reader-guard checks plus the domain suite).
- Added the five fake-backed application use cases, each recording one atomic run-and-receipt pair and refusing anything outside its closed contract:
  - `create-run` with capability-specific fake ports and closed callback refusals;
  - `arm-run` with four closed admission facts, so only full confirmation can create an armed replacement run;
  - `start-run`, so only the application boundary can make an armed run running;
  - `checkpoint`, so only passed verification and complete manifest evidence can advance a running run;
  - `close-run`, policy-gated, so a run reaches a terminal state (`:cancelled`, `:evacuated`, or `:dead`) only under an `:admitted` policy verdict, with closed transition refusals and no certificate for run-state transitions.
- Added a read-only candidate evidence bundle (`make verify-candidate`): explicit manifest admission, candidate-local policy scans, fixed local evidence commands, and closed status output; it observes whole-tree state without inferring scope or mutating Git.
- Added governance C0–C3:
  - the proposal-evidence ledger;
  - deterministic principle evaluation — one `policy-verdict` per proposal with ten matrix-ordered principle results and closed refusals for missing, stale, malformed, conflicting, or unverifiable evidence;
  - the closed failure-disposition policy — one deterministic disposition per failure category, refusing unknown categories;
  - a non-mutating candidate authorization certificate binding one closed action to the admitting verdict and facts, issued by a mechanical pure issuer (action-admission policy deferred to the executor).
- Published source-grounded autonomous development policy, the closed principle and certificate vocabulary, and a human-approval deployment profile — documentation only, no execution added.
- Added the read-only evidence adapter (promotion rung 4): a fixed, enumerable set of read-only local evidence commands — repository revision, whole-tree working-tree status, and file content hashing — gathered through an injected process transport and mapped to domain evidence facts and source manifest entries with closed states. Unknown commands, malformed output, escaping or option-like paths, and duplicate evidence fail closed; the kernel stays pure and the adapter never decides policy.
- Added the mutation executor (promotion rung 5): `hngh.adapters.mutation` accepts a current certificate and fresh evidence, rechecks repository identity, base revision, candidate paths, content and evidence hashes, principle verdicts, source manifest, review findings, policy profile, and expiry, then issues only the certificate-bound fixed Git action through an injected transport. `:none`, action escalation, stale facts, malformed evidence, command failures, and transport faults refuse without a mutation.
- Added the bounded model-review adapter (promotion rung 6): `hngh.adapters.review` turns a closed review request — candidate paths, content hash, and policy-context labels — into one fixed prompt, sends it through an injected reviewer transport, and maps the structured output into immutable finding labels and citations plus one deterministic domain evidence fact. Missing, malformed, unsafe, duplicate, or oversized output refuses closed; a failed review call becomes an `:unverifiable` fact; reviewers advise and never decide, and no default provider transport exists.
- Added the composition root and operator-visible presentation (promotion rung 7): `hngh.presentation` renders application results, runs, receipts, evidence facts, policy verdicts, candidate certificates, and adapter results into plain factual strings without mutating canonical state or importing any adapter; the optional reference lexicon supplies display copy only at a named surface and can never carry canonical control. `hngh.main` composes the five use cases into one `run-harness` with injected or fail-closed default port adapters, wires the installed evidence, mutation, and review adapters through injected transports, keeps an operator-visible in-memory record root, and renders every result through presentation. No daemon, provider, watcher, or background execution.
- Added the operator-facing command surface and transport admission (promotion rung 8, 2026-08-24): `hngh.application:admit-transport` admits closed transport kinds (`:filesystem`) under mission/loadout authorization; `hngh.adapters.filesystem` records canonical run-and-receipt lines under an explicit root path; `hngh.main:dispatch-command` and `scripts/hngh` expose the 7 CLI operations (`create-run`, `admit-transport`, `arm-run`, `start-run`, `checkpoint`, `close-run`, `present`) with a strict exit code protocol (0 accepted, 1 refusal/conflict, 2 malformed, 3 fault). Persistence occurs only under an explicit `--store=PATH`.
- Completed the dogfood development loop (promotion rung 9, 2026-08-24): the operator governance surface (`propose`, `issue-cert`, `mutation-check` in `scripts/hngh`) forms closed policy proposals, binds candidate certificates under admitted verdicts, and executes the certificate-bound mutation against real repository evidence including live base revision, per-file content hashes, and the installed verify-candidate script. Two self-governed commits were produced, reviewed, and committed by Hngh under its own certificates and pushed to origin: the documentation change that completed this rung (`2a16a69`) and the two adapter bug fixes the first ceremony surfaced (`33b8d94`).
- Completed the bounded agent worker transports (promotion rung 10, 2026-08-24): `hngh.adapters.model:make-model-transports` supplies the transport `complete` callback shape so the existing bounded review adapter can drive a real provider (advisory only, no default provider, closed route admission), and `hngh.adapters.terminal` captures one bounded operator statement as a `:terminal` evidence fact (advisory only, in-process SHA-256 fingerprint, no subprocess, no default input). `hngh.application:admit-transport` reuses the run loadout for the two new kinds — `:model` needs a non-`local` route plus the `model-review` network label, `:terminal` needs the `terminal-input` tool label — with the closed `loadout-refuses-transport` refusal. `hngh.main:dispatch-command` exposes the `review` and `terminal` operations, both fail-closed without injected ports (no-review-transport / no-terminal-transport) and both served only to a run holding the matching admission receipt; `hngh.presentation` stays outward-only with the added `render-operator-result`.
- Completed the distributed attestation & evidence federation slice (promotion rung 11, 2026-08-24): `hngh.domain` adds the pure `remote-attestation` value and `verify-attestation-shape` checker in `src/domain/attestation.lisp`; `hngh.adapters.federation` gathers carrier-bundle claims into evidence facts (`fetch-remote` port; `:current`/`:unverifiable`/`:malformed`/`:missing`/`:conflicting` states) and verifies attestation envelopes through `resolve-pinned-key` + `verify-signature` ports with the closed refusal taxonomy; `:federation` joins `+admitted-transports+` under the `remote-evidence` network label or `carrier-bundle` tool label; `hngh.main` threads `fetch-evidence` / `verify-attestation` behind `:federation-ports` / `:attestation-ports` with no default transport, so plain `scripts/hngh` still never touches a wire.
- Added the operator pinned-key registry and signature-verification
  transport (promotion rung 12, 2026-08-25): `hngh.domain` adds the pure
  `key-pin` value and immutable `key-pin-registry`
  (`src/domain/attestation.lisp`); `hngh.adapters.federation` adds the
  strict `parse-pinned-keys` line parser, the pure `hex-decode` signature
  codec, and `make-pinned-attestation-ports`, which resolves keys from the
  operator's registry and verifies one envelope signature through a single
  bounded `openssl dgst -sha256 -verify` invocation on the injected
  process transport — no default transport, nothing pinned refuses
  `unknown-peer-key`. `verify-attestation RUN FILE [pins=PATH]` admits the
  operator pins file as the trust anchor and `list-pins PATH` renders the
  registry; both refuse malformed pins closed. Verified live with a real
  RSA-2048/SHA-256 keypair (`:verified` / `bad-signature` /
  `unknown-peer-key`) and through three self-governed ceremony commits.
- Added the operator reviewer transport (promotion rung 13, 2026-08-25):
  `review ... reviewer=PATH` admits an operator reviewer-transport file as
  the real model-review transport (strict five-key parsing, closed
  refusals, token confined to the one curl Authorization header);
  `hngh.adapters.model` gained the real-path fixes the first live call
  surfaced (string-stream stdin, chat envelope with `enable_thinking`
  disabled, completion-document extraction from the provider envelope via
  its own minimal JSON scanner) and the rung-6 fixed review prompt became
  self-sufficient for real reviewers. Verified live against the operator's
  local Unsloth server (Ornith-1.0-35B): `status=complete` with the closed
  findings document and a `:current` review fact.
- Completed the Ed25519 signature-transport hardening (promotion rung 14,
  2026-08-25): the pins file gains an optional closed ALGORITHM column
  (`rsa-sha256` default, `ed25519` admitted); verification routes per pin —
  digest signatures via `openssl dgst -sha256 -verify`, raw Ed25519
  signatures via `openssl pkeyutl -verify -rawin -in`; `list-pins` renders
  each pin's algorithm. Verified live end to end with a real Ed25519
  keypair (`status=verified key=ed-key` exit 0; tampered payload refuses
  `bad-signature`) and bound through the self-governed ceremony.
- Completed the network claim method (promotion rung 15, 2026-08-25):
  `:http-claim` joins `:carrier-bundle` in the closed federation method
  set; `fetch-evidence` accepts `method=carrier-bundle|http-claim`
  (default carrier-bundle) and the method reaches the injected
  transport on the request. The peer stays a plain identifier and
  endpoint resolution stays transport-owned — no default wire. Verified
  live over a real local HTTP server through an injected transport and
  bound through the self-governed ceremony.
- Completed the operator policy profiles (promotion rung 16,
  2026-08-25): the pure `evidence-profile` value narrows which
  requirement kinds a listed principle may carry, the requirement-kind
  vocabulary admits `:review`, and `propose` accepts `profile=PATH`
  (strict `PRINCIPLE<TAB>KIND` lines). A profile only narrows, never
  broadens. Committed through the self-governed ceremony.
- Completed the wake-on-demand slice (promotion rung 17, 2026-08-25):
  `wake-peer RUN PINS-FILE PEER` issues one explicit wake request for a
  pinned lattice peer behind an injected transport — admission
  evidence is the pins registry, the run needs a `:federation` receipt,
  and there is no default transport or daemon. Unpinned peers refuse
  `unknown-peer-key`. Committed through the self-governed ceremony.
- Completed the bounded read-only worker task (promotion rung 18,
  2026-08-25): the worker-rung first slice. `run-worker RUN task=LABEL
  [payload=TEXT]` runs one closed worker task through an injected
  transport; `:worker` is admitted behind the `worker-task` tool label,
  and a completed task binds a `:worker` evidence fact (a worker
  self-report is evidence, never acceptance). Committed through the
  self-governed ceremony.
- No daemon, provider, watcher, scheduler, dashboard, or unbounded mutation is admitted by this roadmap step.

## Next

1. **(Next slice).** The worker-driver surface (the hngh-omp bridge
   tools that run a disposable worker session through run-worker) —
   the one-shot `scripts/worker-driver` cycle is done; the bridge-hosted
   end-to-end session (run → worker → review → certify) is the open
   half — or the node-lattice boundary amendments (ambient tunnels,
   certificate-bound wake) that must clear their own policy proposals
   first.
2. **The autonomy continuum (operator directive 2026-08-26, folded
   into the queue ledger).** Eight queued rungs that turn the hourly
   cadence into a self-governing continuum — no slice of which admits
   a daemon; every tier stays an operator-installed timer invoking
   single-tick scripts:
   - `push-self-sufficiency` — both repos land and push their own
     verified commits (sweep + post-ceremony push).
   - `credential-rotation-auto` (folds into `key-rotation-freshness`)
     — token/key rotation, health probes, and alert reports with zero
     operator intervention; fail closed, never fail open.
   - `cadence-continuum` — the timing tiers (month/week/day/hour/
     10m/5m/1m + ad-hoc) as systemd units over single-tick jobs.
   - `activity-cadence` — the routine project activities (roadmap
     review, planning, design, expansion, implementation, review,
     refactor, cleanup, inward/outward communication) riding those
     tiers, scaled to the observed fleet.
   - `governance-vocabulary` — relax the ritual/ceremony terms to a
     flexible governance vocabulary (prose first; symbol renames only
     where a check-in-scale ceremony covers them).
   - `agent-live-view` (folds into `ux-hardening`) — an automatic
     on-screen view of all working subagents, integrated into the
     dashboard rather than disjoint from it.
   - `surface-evolution-loop` (extends `dancing-ui` + grade-interface)
     — evolutionary design/development for every operator-facing
     surface and every part of the megastructure, graded continually.
   - `machine-steered-backlog` — machine-gated governance where Hngh
     determines its own best-course continually (run-autonomous +
     rotate-queue grow a course-selection step behind the existing
     certificate gates).

No daemon, provider, watcher, scheduler, dashboard, or unbounded mutation is admitted by this roadmap stage.
