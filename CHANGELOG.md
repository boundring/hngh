# Changelog

All notable changes to Hngh are documented here.

## [Unreleased]

### Added

- Compact, side-effect-free kernel baseline with explicit profile validation.
- Read-only archive receipt verification through `make check-archive`.
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

### Changed

- Routine design, review, and future mutation decisions move from
  approval-by-perception to source-grounded, fail-closed certificates; human
  approval is a deployment profile.
- Application callback failures now refuse at the invocation boundary while
  domain and application errors remain visible to the test gate.
- Retired the previous daemon, plugin, watcher, dashboard, mission-control,
  launcher, and unit architecture into an external local archive.
