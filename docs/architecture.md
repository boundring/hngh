# Architecture

Hngh begins as a compact, side-effect-free kernel.

## Current kernel

`hngh.domain` is an active Common Lisp-only library. It validates ordered
profile modes and creates pure mission, role, loadout, run, receipt, score, and
afterlife values. It does not read a clock, environment, path, provider payload,
or subprocess value.

A run always starts in `created`. Its closed lifecycle is:

```text
created -> armed -> running -> checkpointed
created -> cancelled | dead
armed -> cancelled | dead
running -> cancelled | evacuated | dead
checkpointed -> running | cancelled | evacuated | dead
cancelled | evacuated | dead -> afterlife -> scored -> archived
```

Every other transition refuses. Receipts, score records, and afterlife records
hold evidence only; they cannot change state or grant authority.

`hngh:validate-profile` remains a compatibility facade over the domain policy.
`hngh.application` currently contains the pure `create-run`, `arm-run`,
`start-run`, `checkpoint`, and `close-run` use cases with their inward port
contracts.
`checkpoint` admits only closed verification and manifest evidence through a
run-only request value. It has no persistence root, clock,
environment, provider payload, subprocess, service, or background process.

`hngh.adapters.evidence` is the first outer boundary: a read-only evidence
adapter with a fixed command set (repository revision, working-tree status,
file content hashing) and an injected process transport. It never decides
policy and cannot mutate anything.

`hngh.adapters.review` is a bounded model-review boundary: it turns a closed
review request into one fixed prompt, sends it through an injected reviewer
transport, and maps the structured output into sanitized findings and one
deterministic review evidence fact. Reviewers advise, never decide, and no
default provider transport exists.

## Planned outer boundaries

```text
hngh.main -> hngh.presentation / hngh.adapters.*
          -> hngh.application
          -> hngh.domain
```

The dependency direction, promotion ladder, and composition rule live in the
[Clean Architecture charter](core/clean-architecture-charter.md). The public
responsibilities and allowed dependencies live in the
[component map](core/component-map.md). Tests and presentation data follow the
[test boundary](core/test-boundary.md) and
[presentation boundary](design/presentation-boundary.md).
