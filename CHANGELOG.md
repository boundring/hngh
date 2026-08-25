# Changelog

All notable changes to Hngh are documented here. Entries are dated by the
day they were recorded. Nothing has been released yet; development work
lives under Pre-release / early development until the first release.

## Pre-release / early development

### 2026-08-25

#### Added

- Added the operator reviewer transport (promotion rung 13):
  - `review RUN content-hash=HASH paths=PATH,... [reviewer=PATH]` admits
    an operator reviewer-transport file (endpoint, model, max-tokens,
    timeout, token-file; strict parsing, closed refusals) that replaces
    injected review ports with the real curl-backed provider transport;
    the provider token travels only in the one Authorization header.
  - `hngh.adapters.model:make-model-transports` now works against real
    OpenAI-compatible servers: stdin is a string stream (not a filename),
    the request envelope is a chat message with `enable_thinking:false`,
    and the model's completion document is extracted from the provider
    response envelope by a minimal JSON scanner (`model-response-content`;
    numbers/booleans/nulls consumed opaquely).
  - The rung-6 fixed review prompt carries an explicit advisory-reviewer
    instruction; output contract unchanged.
  - Verified live against the local Unsloth server with Ornith-1.0-35B
    (`status=complete`, closed findings document, `:current` review fact).

- Added the operator pinned-key registry and signature-verification
  transport (promotion rung 12, the "revocation policy refinement" named
  in the roadmap):
  - `hngh.domain` adds the pure `key-pin` value (plain bounded identifier
    plus absolute key path; option-like path components refuse) and the
    immutable `key-pin-registry` (duplicate identifiers refuse, defensive
    copies, `lookup-key-pin`) in `src/domain/attestation.lisp`.
  - `hngh.adapters.federation` adds `parse-pinned-keys` (strict
    `IDENTIFIER<TAB>ABSOLUTE-KEY-PATH` line parser over operator text;
    comments and blanks skipped, everything else refuses),
    `hex-decode` (the pure envelope signature codec), and
    `make-pinned-attestation-ports` (attestation ports that resolve keys
    from the registry and verify signatures through one bounded
    `openssl dgst -sha256 -verify` invocation on the injected process
    transport; no default transport).
  - `verify-attestation RUN FILE [pins=PATH]` admits the operator pins
    file — the trust anchor that replaces injected ports with the real
    pinned registry and process transport; a missing or malformed pins
    file is a malformed invocation. New `list-pins PATH` renders one
    tab-joined line per pinned key through `render-pin-list`.
  - Live proof (RSA-2048/SHA-256 throwaway keypair): a real signature
    verifies `status=verified key=live-key-1` exit 0; a tampered payload
    refuses `bad-signature`; an unpinned key refuses `unknown-peer-key`.

#### Changed

- Root README restated the self-governance claim honestly: the loop is
  the default lane for behavior changes, closed exceptions (the
  dependency guard refusing to certify a no-behavior commit) are by
  rule, and pre-loop history is recorded rather than rewritten as
  ceremony. Fixed the stale check-count line (now "a suite past 2,690
  checks; the run prints the current number") and expanded the
  `Where this is going` section with the node-lattice megastructure
  vision (small ledgered machines sharing learned facts, wake-on-demand,
  persistent tunnels without a watching daemon, evidence-first
  admission of low-powered peers).

#### Added

- Ed25519 signature-transport hardening (promotion rung 14): the pins
  file gains an optional closed ALGORITHM column
  (`rsa-sha256` default, `ed25519` admitted; unknown, empty, or extra
  columns refuse), the `key-pin` domain value carries the algorithm, and
  signature verification routes per pin — digest signatures via
  `openssl dgst -sha256 -verify`, raw Ed25519 signatures via
  `openssl pkeyutl -verify -pubin -inkey -rawin -sigfile -in`.
  `list-pins` renders each pin's resolved algorithm. Verified live end
  to end with a real Ed25519 keypair (`status=verified key=ed-key` exit
  0; tampered payload refuses `bad-signature`) and committed through the
  self-governed ceremony (chore export lane for `src/packages.lisp`,
  excluded by the dependency guard; candidate commit bound to the
  implementation and tests).

- Network claim method (promotion rung 15): `+federation-methods+` gains
  `:http-claim` (carrier-bundle and http-claim are the closed method
  set; anything else still refuses at request construction).
  `fetch-evidence RUN peer=ID [method=carrier-bundle|http-claim]
  [max-facts=N]` accepts the closed method option (unadmitted methods
  are malformed exit 2); the transport sees the method on the request,
  and the peer remains a plain identifier with endpoint resolution
  transport-owned — no default wire. Verified live over a real local
  HTTP server through an injected transport (`status=complete` with the
  closed claim states) and committed through the self-governed ceremony.

- Operator policy profiles (promotion rung 16): the domain gains the
  pure `evidence-profile` value (principle → permitted requirement
  kinds; duplicate principles and non-closed kinds refuse) and
  `evaluate-policy-proposal-under-profile`, which narrows a proposal's
  requirements to a listed principle's permitted kinds — a profile only
  narrows, never broadens. The requirement-kind vocabulary admits
  `:review`, so a profile can demand review evidence; `propose` gains
  `profile=PATH` (strict `PRINCIPLE<TAB>KIND` lines; missing or
  malformed files are malformed invocations). Committed through the
  self-governed ceremony (chore export lane for `src/packages.lisp`).

- Wake-on-demand (promotion rung 17): `wake-peer RUN PINS-FILE PEER`
  issues one explicit wake request for a pinned lattice peer behind an
  injected transport. The pins registry is the admission evidence; the
  transport receives `(PEER KEY-PATH)`; a zero exit issues, a nonzero
  exit refuses `wake-refused`, a throw faults `wake-fault`; an unpinned
  peer refuses `unknown-peer-key` before any transport call. No default
  transport — without injection the command refuses
  `no-wake-transport`. Committed through the self-governed ceremony
  (chore export lane for `src/packages.lisp`).

- Machine-checked self-governance (2026-08-25): the README's restated
  claim is now falsifiable by construction.
  `tests/scripts/test-loop-history-guard.py` walks every code-surface
  commit since the restatement `1915713` and fails the gate on any
  commit that is neither `hngh: candidate <hash>` nor labeled
  `(excluded from cert manifest by dependency guard)`. The carve-out is
  recorded as a decision entry in `docs/project/decisions.md`, with the
  one pre-guard violation (`915e0e3`, comment-only) named rather than
  rewritten. Committed through the self-governed ceremony.

- Bounded read-only worker task (promotion rung 18): the worker-rung
  first slice. `hngh.adapters.worker` supplies a closed `worker-request`
  (bounded task label plus optional bounded payload), `worker-ports`
  (one injected `execute-worker` callback, no default transport), and
  `run-worker-task`, which binds a `:worker` `:current` evidence fact
  on a zero exit and refuses/faults closed otherwise. `:worker` joins
  `+admitted-transports+` behind the `worker-task` tool label on the
  run loadout; `run-worker RUN task=LABEL [payload=TEXT]` is the
  operator surface. A worker self-report is evidence, never acceptance,
  and a worker never carries a mutation certificate. Committed through
  the self-governed ceremony (chore export lane for `src/packages.lisp`).

### 2026-08-24

#### Added

- Added the distributed attestation & evidence federation slice (promotion
  rung 11):
  - `hngh.domain` adds the pure `remote-attestation` envelope value and the
    closed structural checker `verify-attestation-shape` plus `utc-string-p`
    in `src/domain/attestation.lisp` (no clock, no network, no key store).
  - `hngh.adapters.federation` is a bounded federation adapter with two
    injected-port entry points: `gather-federated-evidence` reads an
    operator-carried carrier bundle through the `fetch-remote` callback and
    maps its claims into domain evidence facts with the closed
    evidence-state vocabulary (`:current` when locally re-hashable,
    `:unverifiable`, `:malformed`, `:missing`, `:conflicting`); and
    `verify-remote-attestation` runs the kernel shape gate, resolves the
    signing key against the operator-pinned list, checks the signature
    through `verify-signature`, and checks the expiry window against the
    injected `now`, binding a `:remote-attestation` fact only on a fully
    verified envelope. The closed refusal taxonomy names `unknown-peer-key`,
    `bad-signature`, `signature-fault`, `malformed-attestation`,
    `malformed-expiry`, `expired-attestation`, `attestation-clock-skew`,
    `transport-fault`, and `output-too-large`.
  - `hngh.domain:+admitted-transports+` is now
    `(:filesystem :model :terminal :federation)`;
    `hngh.domain:+evidence-requirement-kinds+` gains `:remote-attestation`
    and `:federated-claim`.
  - `hngh.application:admit-transport` admits `:federation` only under a
    loadout carrying the `remote-evidence` network label or the
    `carrier-bundle` tool label, else the closed
    `loadout-refuses-transport` refusal.
  - `hngh.main:dispatch-command` gains `fetch-evidence` and
    `verify-attestation`, threaded through `&key federation-ports
    attestation-ports` with no defaults: un-injected, the operations refuse
    `no-federation-transport` / `no-attestation-transport`, so plain
    `scripts/hngh` never touches a wire; both serve only a run holding a
    `:federation` admission receipt.
  - `hngh.presentation` adds the two outward renderers
    `render-federation-result` and `render-attestation-result`.
  - Test suite `tests/adapter/test-federation.lisp` and updated vocabulary
    coverage in `tests/domain/test-governance.lisp` (closed transport set)
    and `tests/domain/test-governance-properties.lisp` (requirement kinds).
- Added the bounded model and terminal worker transports (promotion rung
  10): `hngh.adapters.model:make-model-transports` returns the transport
  `complete` callback shape so the existing bounded review adapter can
  drive a real provider (advisory only, no default provider);
  `hngh.adapters.terminal` captures one bounded operator statement as a
  `:terminal` evidence fact with an in-process SHA-256 fingerprint
  (advisory only, no subprocess, no default input);
  `hngh.domain:+admitted-transports+` is now `(:filesystem :model :terminal)`
  and `hngh.application:admit-transport` reuses the run loadout for the two
  new kinds (`:model` needs a non-`local` route plus the `model-review`
  network label; `:terminal` needs the `terminal-input` tool label) with
  the closed `loadout-refuses-transport` refusal;
  `hngh.main:dispatch-command` gains the `review` and `terminal` operations,
  both fail-closed without injected ports
  (`no-review-transport`/`no-terminal-transport`) and both served only to a
  run holding the matching admission receipt;
  `hngh.presentation` adds the one outward renderer `render-operator-result`.
- Added the operator-facing command surface and transport admission (promotion rung 8):
  - `hngh.domain:+admitted-transports+` (`(:filesystem)`) in `src/domain/governance.lisp`.
  - `hngh.application:admit-transport` in `src/application/admit-transport.lisp` creating `:admission` receipts with facts `transport`, `scope`, `route`, `run`, and `timestamp`.
  - `hngh.adapters.filesystem` in `src/adapter/filesystem.lisp` recording canonical run-and-receipt lines under an explicit `--store=PATH` without domain imports.
  - `hngh.main:dispatch-command` exposing the 7 CLI operations (`create-run`, `admit-transport`, `arm-run`, `start-run`, `checkpoint`, `close-run`, `present`) with a closed exit code protocol (0 accepted, 1 refusal/conflict, 2 malformed, 3 fault).
  - `scripts/hngh` executable SBCL wrapper.
  - Test suites: `tests/application/test-admit-transport.lisp`, `tests/adapter/test-filesystem.lisp`, `tests/main/test-dispatch.lisp`.
  - Record: `docs/records/2026-08-24-command-surface-and-transport-admission.md`.
- Added the operator governance command surface for the dogfood loop
  (`scripts/hngh`, promotion rung 9):
  - `propose [key=value...]` forms a closed `policy-proposal` from operator
    fields and renders the deterministic `policy-verdict` (0 admitted,
    1 refused with labels, 2 malformed).
  - `issue-cert ACTION RUN [PATH...]` reads the stored run from `--store`,
    binds repository identity/base revision/candidate paths to it, and mints
    a candidate certificate under an admitted verdict (refuses runs without
    an admission receipt).
  - `mutation-check ACTION RUN [EVIDENCE...]` builds fresh fixture evidence
    and executes the certificate-bound mutation through injected ports, so
    the loop runs fully in-process with no subprocess (0 executed, 1
    mismatch/refused, 2 malformed, 3 transport fault).
  - `hngh.main:dispatch-command` gained a `:mutation-ports` injection key;
    test suite `tests/main/test-governance-dispatch.lisp` asserts no real
    process is ever spawned.
  - Record: `docs/records/2026-08-24-command-surface-dogfood.md`.
- Completed the first self-governed development loop (promotion rung 9):
  Hngh proposed, reviewed, certified, and committed its own documentation
  change (`propose`, `issue-cert`, `mutation-check` against live repository
  evidence), then pushed the certificate-bound commit to origin.
  Record: `docs/records/2026-08-24-first-self-governed-commit.md`.
- Completed the second self-governed development loop: Hngh proposed,
  certified, staged, gated, and committed its own adapter bug fixes
  (`process-run-at` value-order; certificate path sorting) under a real
  evidence certificate (`33b8d94 hngh: candidate 1befdda9...`), then pushed
  to origin. Record: `docs/records/2026-08-24-second-self-governed-commit.md`.
- Added exhaustive governance property tests (backlog item): totality
  over the 7 proposal classes x 21 evidence-requirement kinds (147
  combinations; absent-matrix-principle refuses rather than errors) and
  monotonicity of the deterministic evaluator (ignoring evidence never
  flips refused to admitted; single- and double-ignore exercised).
  suite total 2353 checks. Record:
  `docs/records/2026-08-24-governance-property-tests.md`.
- Recorded the 2026-08-24 prior-art research session:
  `docs/records/2026-08-24-prior-art-landscape.md` maps the closest prior
  art (Progent arXiv:2504.11703 closest, CaMeL arXiv:2503.18813,
  AgentSpec arXiv:2503.18666), the four deliberate divergences from
  in-toto/SLSA/DSSE (no PKI / hash self-certification, duplicate facts
  refuse, moment-of-action freshness recheck as a novel property, no
  multi-party machinery), the adopted invariants (monotonicity, deny with
  structured reason, totality over closed kinds, DSSE as a YAGNI-gated
  future export grammar), harness-landscape positioning (Claude Code,
  Codex CLI, mini-swe-agent, Aider, OpenHands/ACP), the no-public-
  governance-benchmark gap, and the strategy sequencing ending in
  federation as a scope-broadening proposal class.
- `docs/project/decisions.md` records the no-PKI / hash self-certification
  stance as a single-machine decision with an explicit revisit trigger:
  multi-machine evidence sharing.
- `docs/project/backlog.md` gains four entries: governance property tests
  (matrix totality over closed kinds plus monotonicity), a DSSE envelope
  export serializer (YAGNI-gated), a governance-benchmark research lane
  (AgentDojo / InjecAgent / R-Judge prior-art scan; tamper-evidence,
  approved equals executed, reconstruction-from-record metrics), and the
  dogfood loop as a future rung candidate (Hngh proposes, evaluates, and
  commits changes to itself via its own harness). Documentation only; no
  source or behavior change.


### 2026-08-19

#### Changed

- Root README `Why` and `Where this is going` rewritten to frame Hngh as a
  growing system harness: the Why contrasts Hngh's record-first posture with
  the throughput-first agent-harness mainstream (grounded in a 2026
  empirical study of 70 agent-harness projects and the 2026-07-28 stateless
  MCP update), and Where-this-is-going names the corridor: local and remote
  models, priced routes, pooled hardware, all behind the same bounded, recorded,
  human-closable cycle. Documentation only; no source or behavior change.

- Retired the `make check-archive` archive gate and the archive-boundary
  framing: the external retirement archive is historical evidence only, no
  active gate verifies it, and meaningful archive material is harvested
  into the operator's separate llm-wiki knowledge base. The archive itself
  is untouched. Makefile and documentation only; no source or behavior
  change.


### 2026-08-18

#### Added

- A read-only evidence adapter (promotion rung 4): a fixed, enumerable set of
  read-only local evidence commands — repository revision, whole-tree
  working-tree status, and file content hashing — gathered through an
  injected process transport and mapped to domain evidence facts and source
  manifest entries with closed states; unknown commands, malformed output,
  escaping targets, and duplicate evidence fail closed, and the adapter
  never decides policy or mutates anything.

- A fixture-backed mutation executor (promotion rung 5): `hngh.adapters.mutation`
  rechecks every certificate fact against fresh evidence and emits only the
  certificate-bound fixed Git action through an injected transport; stale facts,
  expiry, disabled actions, malformed evidence, command failures, and transport
  faults refuse without mutation.

- A fixture-backed bounded model-review adapter (promotion rung 6):
  `hngh.adapters.review` sends one closed review request (candidate paths, content
  hash, policy-context labels) through an injected reviewer transport and maps the
  model's structured output into sanitized, duplicate-free finding labels and
  citations plus one deterministic review evidence fact. Malformed JSON, unknown
  fields, unsafe citations, oversized or overlong findings, duplicate labels, and
  transport faults refuse closed; a failed review call becomes an `:unverifiable`
  fact. Reviewers advise, never decide; the adapter is pure (no provider defaults,
  no network, no subprocess calls).

- An operator-visible presentation layer (promotion rung 7):
  `hngh.presentation` renders application results, runs, receipts, evidence facts,
  policy verdicts, candidate certificates, and installed adapter results into
  plain factual strings without mutating canonical state or importing an adapter;
  refusals stay literal, and the optional reference lexicon applies display copy
  only at a named surface and can never carry canonical control.

- A composition root (promotion rung 7): `hngh.main` composes the five use cases
  into one `run-harness` with injected or fail-closed default port adapters
  (in-memory record store, per-harness identifier source, clock, and `unknown`
  admission, verification, and manifest evidence), wires the installed evidence,
  mutation, and review adapters through injected transports, keeps an
  operator-visible in-memory record root, and renders every result through
  `hngh.presentation`. It starts no background work by import and supplies no
  default model or terminal transport.

- Public read-only accessors on domain run and receipt values
  (`run-identifier`, `run-mission`, `run-role`, `run-loadout`, `receipt-kind`,
  `receipt-facts`) so presentation renders without touching canonical state,
  and a dependency-guard extension that rejects any inward package importing an
  adapter.

#### Changed

- Root README, documentation index, and roadmap now frame Hngh's intent and
  direction in plain language, recovered from the archived pre-refactor plans;
  added `docs/intent.md` as the human-facing vision document. Documentation
  only; no source or behavior change.


### 2026-08-17

#### Added

- Pure governance values for closed proposal, principle, failure, evidence, and
  verdict vocabulary; they remain non-authoritative policy data.

- A deterministic proposal-evidence-ledger policy: closed requirement kinds
  bind evidence facts to principles without making fact producers or adapters
  domain policy.

- A deterministic principle evaluator over the proposal ledger: ten
  matrix-ordered principle results and closed refusals for missing, stale,
  malformed, conflicting, or unverifiable evidence; `:admitted` only when every
  principle passes.

- A closed failure-disposition policy: each of the eight failure categories
  maps to one deterministic disposition, unknown categories refuse, and
  conditional rows resolve to their primary default.

- A non-mutating candidate authorization certificate: an immutable value
  binding one closed action plus the admitting verdict and recorded facts,
  minted by a pure mechanical issuer.

- The policy-gated `close-run` use case: a run reaches a terminal state only
  under an `:admitted` policy verdict, with closed transition refusals and one
  atomic run-and-receipt record.


### 2026-08-12

#### Added

- A read-only, fixture-tested Common Lisp parenthesis guard in the fast gate.

- A pure run domain with validated mission, role, loadout, lifecycle, and
  evidence values.

- A pure application create-run slice with explicit identifier, clock, and
  atomic recording capabilities.

- A pure application arm-run slice with explicit admission facts and atomic
  recording capabilities.

- A pure application start-run slice with one atomic transition recording
  capability.

- A pure application checkpoint slice with closed verification and manifest
  evidence callbacks plus one atomic transition recording capability.

- A policy-only autonomous-development-control design: source-grounded
  principle evaluation, closed proposal and authorization classes, bounded
  reviewer challenges, and certificate-gated future mutations.

- A read-only candidate evidence bundle with an explicit manifest, fixed local
  checks, whole-tree observation, hash-bound output, and closed refusals for
  unsafe or out-of-scope input.

#### Changed

- Routine design, review, and future mutation decisions move from
  approval-by-perception to source-grounded, fail-closed certificates; human
  approval is a deployment profile.

- Application callback failures now refuse at the invocation boundary while
  domain and application errors remain visible to the test gate.


### 2026-08-11

#### Added

- Compact, side-effect-free kernel baseline with explicit profile validation.

- Compact active documentation and cutover record.

- Clean Architecture charter, component map, test boundary, and
  presentation/reference-lexicon boundaries.

- Fixture guards for inward dependency direction and renderer-only lexicons.

#### Changed

- Retired the previous daemon, plugin, watcher, dashboard, mission-control,
  launcher, and unit architecture into an external local archive.
