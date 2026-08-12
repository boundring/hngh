# Task A autonomous control policy record

## Scope

Published the autonomous development control contract. This is policy and
documentation only. It adds no executable adapter, model route, stage, commit,
push, provider, service, daemon, watcher, scheduler, or persistence behavior.

## Decision

Routine feature, scope, capability, failure-disposition, review, and future
mutation decisions use source-grounded policy certificates. Operators guide
policy, deployment profiles, budgets, privileged-work posture, release posture,
and safety-boundary changes; operator perception is not the routine approval
mechanism. A human-approval profile remains available for deployments that need
it.

## Evidence

- `docs/design/autonomous-development-control.md` defines the source hierarchy,
  principle matrix, closed proposal/action vocabulary, failure dispositions,
  certificate facts, review ladder, promotion path, and non-goals.
- `docs/project/decisions.md`, `docs/core/clean-architecture-charter.md`,
  `AGENTS.md`, and `CONTRIBUTING.md` now require a current policy certificate
  for a future mutation and preserve an explicit transitional rule until an
  executor exists.
- `docs/project/backlog.md` requires each future proposal to carry a source
  manifest and principle matrix.
- `docs/README.md` exposes the control contract in the canonical read order.

## Verification

```text
make test
8 reader guard checks passed.
495 checks passed.
ASDF load completed.

Markdown relative-link check
Markdown relative links passed.

git diff --check HEAD
passed.
```

## Remaining unknowns

The certificate, source-manifest values, deterministic evaluator, review
adapters, and mutation executor do not exist yet. The read-only evidence report
exists, but it is not an authorization certificate and does not authorize a
mutation.
