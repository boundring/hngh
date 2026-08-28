# Architecture

Hngh begins as a compact, side-effect-free kernel.

It stays small on purpose: the quiet center holds the rules while the
lattice of small ledgered machines does the moving.

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
`hngh.application` currently contains the pure `create-run`, `admit-transport`,
`arm-run`, `start-run`, `checkpoint`, `close-run`, and `select-course` use cases with
their inward port contracts; `admit-transport` and `close-run` are policy-gated.
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

`hngh.presentation` is the operator-visible renderer boundary: it turns
application results, domain runs and governance values, and adapter results
into plain factual strings, keeps refusals literal, and never mutates a
canonical value. The optional reference lexicon supplies display copy only
at a named surface; it cannot carry canonical control. Presentation imports
no adapter.

`hngh.main` is the composition root. `make-run-harness` composes the six
use cases into one run harness over injected or fail-closed default port
adapters (an in-memory record store, a per-harness identifier source, and a
clock), the coordinator functions wire the installed evidence, mutation, and
review adapters through injected transports, and `display` renders any
result through `hngh.presentation`. It starts no background work by import.

The installed outer boundaries beyond evidence and review are: the mutation
executor (rung 5), the filesystem record store (rung 8), the bounded `:model`
and `:terminal` transports behind loadout admission (rung 10), the federation
and attestation adapter (rungs 11–12, 14–15), and the bounded `:worker`
transport (rung 18). None of them runs by default: every one sits behind an
injected transport or an explicit admission receipt.

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
[presentation boundary](design/presentation-boundary.md). Real model and
terminal transports are admitted only under a separately approved run
loadout (rung 10), and the operator reviewer transport (rung 13) is
admitted by an explicit operator reviewer file.
