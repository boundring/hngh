# Changelog

All notable changes to Hngh are documented here.

## [Unreleased]

### Added

- Compact, side-effect-free kernel baseline with explicit profile validation.
- Compact active documentation and cutover record.
- Clean Architecture charter, component map, test boundary, and
  presentation/reference-lexicon boundaries.
- Fixture guards for inward dependency direction and renderer-only lexicons.
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

### Changed

- Routine design, review, and future mutation decisions move from
  approval-by-perception to source-grounded, fail-closed certificates; human
  approval is a deployment profile.
- Application callback failures now refuse at the invocation boundary while
  domain and application errors remain visible to the test gate.
- Retired the previous daemon, plugin, watcher, dashboard, mission-control,
  launcher, and unit architecture into an external local archive.
- Root README, documentation index, and roadmap now frame Hngh's intent and
  direction in plain language, recovered from the archived pre-refactor plans;
  added `docs/intent.md` as the human-facing vision document. Documentation
  only; no source or behavior change.
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
