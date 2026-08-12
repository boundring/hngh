# Autonomous development control

Status: DESIGN — Task A, 2026-08-12.

Source: `docs/project/decisions.md`.
Cross-links: `../core/clean-architecture-charter.md`,
`../core/component-map.md`, `../core/test-boundary.md`,
`../project/decisions.md`, `../project/backlog.md`.

## Decision

Hngh evaluates routine feature proposals, scope changes, capability requests,
failure dispositions, reviews, staging, commits, and pushes through explicit
policy and evidence. Operators guide policy, set deployment profiles, and
receive evidence. Operator perception is not the normal approval mechanism.

The evaluator is deterministic for structural facts. Local and alternate-model
reviewers may submit bounded, source-cited challenges. They do not create
authority, override a deterministic refusal, or execute an action.

A human-approval profile remains available for deployments that require it.
The intended Hngh policy profile is self-approval under a current,
hash-bound certificate. This design adds no executable capability.

## Source resolution

A proposal and authorization certificate carry a manifest of relative source
paths, content hashes, and source roles. Resolve uncertainty in this order:

1. Current operator policy and recorded project decisions.
2. Architecture, boundary, and test contracts.
3. Approved task plan and backlog admission record.
4. Fixture-backed source and tests, which establish existing behavior but do
   not grant future authority.
5. Research and external references, which supply supporting facts or options
   but do not override project policy.

Missing, conflicting, or changed source entries produce `:unknown` or
`:needs-escalation`. They refuse a mutation. A policy change must be documented
and evaluated again under a new source manifest; the evaluator does not select
the convenient source silently.

## Principle matrix

Every proposal is evaluated before implementation and again before mutation.
A missing principle result is a refusal.

| Principle | Required evidence | Refusal condition |
|---|---|---|
| Closed authority | Named purpose, caller, input, output, and failure contract | Unknown or implicit capability |
| Least authority | Declared capability set and capability diff | Undeclared authority or scope broadening |
| Dependency direction | Static source evidence | Inward outer or test dependency |
| Fail closed | Closed failure disposition | Missing, malformed, conflicting, or stale evidence |
| Evidence before claim | Fixture, command, or artifact hash | Unsupported claim or model opinion as proof |
| Atomic mutation | Base revision, manifest, and content hash | Any candidate mismatch |
| Reversibility | Reversion or containment fact | External effect without rollback/containment |
| No hidden execution | Component and import evidence | Import-time or implicit execution |
| Cost and route discipline | Route, budget, token, and expiry facts | Unknown/exhausted allowance |
| Source grounding | Source manifest and conclusion links | Missing, stale, or conflicting sources |

## Closed decisions

### Proposal classes

`feature`, `scope-broadening`, `capability-request`, `failure-disposition`,
`review-request`, `commit-request`, and `push-request` are closed classes.

A capability exceeding a task's declared set is a `scope-broadening`, not an
ordinary feature. Process, provider, network, filesystem, and mutation
capabilities require named containment and rollback evidence.

### Failure disposition

| Category | Default |
|---|---|
| Domain policy or invariant | Propagate to the test gate, unless a typed domain refusal exists |
| Application invariant | Propagate to the test gate |
| Port callback fault or malformed return | Normalize to refusal at that callback only |
| Atomic recording conflict | Normalize to conflict without retry |
| Insufficient or stale evidence | Refuse |
| Tool/environment fault | Refuse or escalate through named evidence policy |
| Review disagreement | `:needs-escalation` |
| Mutation precondition mismatch/failure | Stop and record evidence |

An unknown category refuses. Policy defines the disposition; a use case does
not decide it by catch-all condition handling.

### Authorization certificate

A certificate may authorize one action only: `:none`, `:prepare-candidate`,
`:stage`, `:commit`, or `:push`. It records repository identity, base revision,
ordered candidate paths, content hash, evidence hashes, principle verdicts,
review findings, source manifest, policy profile, and expiry.

The executor rechecks every certificate fact immediately before its named
action. A commit certificate never authorizes a push. No certificate implies no
mutation.

## Review ladder

1. Deterministic policy and evidence evaluation is required.
2. A local model critic may emit a closed, source-cited challenge.
3. A cheap alternate-provider critic may independently challenge where policy
   requires it.
4. A reserve reviewer is exceptional and requires an admitted escalation class,
   a strict budget, and an expiry.
5. A deterministic combiner accepts only current, hash-bound compatible
   findings. Disagreement refuses or escalates.

An unavailable, malformed, uncited, stale, or budget-ineligible reviewer result
cannot pass a principle. No reviewer may call a mutation executor.

## Promotion path

The control plane follows the existing inward promotion ladder:

1. Pure governance values and policies with fixtures.
2. Fake-backed application authorization use case.
3. Read-only evidence adapter.
4. Scratch-repository mutation adapter.
5. Bounded model-review adapters.
6. Explicit composition only after the lower contracts exist.

## Verification gates

Before a future mutation capability is admitted, its fixture suite proves
current-certificate success and refusal for changed content, unexpected paths,
stale base revision, expired certificate, malformed input, command failure, and
its disabled action classes. The fast suite stays local and deterministic.

## Explicit non-goals

- No automatic stage, commit, push, provider call, service, daemon, watcher,
  scheduler, filesystem persistence, or model review in this design task.
- No model-based replacement for deterministic policy checks.
- No implied authority from a branch, task name, prior certificate, or passing
  test suite.
- No automatic remote-model escalation from uncertainty alone.
- No claim that a record or evidence report authorizes a future action.
