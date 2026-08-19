# Clean Architecture charter

## Purpose

Hngh is a local kernel for bounded, evidenced work runs. Its source dependencies
point inward toward stable policy. Details may call policy through explicit
ports; policy does not name a filesystem, process, provider, terminal, Git,
network transport, or user interface.

This charter freezes the boundary before persistence or an adapter exists. It
does not require a daemon, service, scheduler, watcher, or model route.

## Dependency law

```text
hngh.main -> hngh.presentation --\
                             +-> hngh.application -> hngh.domain
hngh.main -> hngh.adapters.* ----/
```

`hngh.main` may compose outer components. `hngh.presentation` and
`hngh.adapters.*` may depend on application ports and domain values.
`hngh.application` may depend on `hngh.domain`. `hngh.domain` depends on
Common Lisp only.

Dependency direction is a source-code rule, not a claim about runtime call
flow. An application use case may call an adapter through an application port
without importing that adapter.

## Forbidden dependencies

- Domain code must not import an adapter, presentation, filesystem, process,
  provider, transport, clock, environment, or UI package.
- Application code must not import a concrete adapter or presentation package.
- Presentation code must not make domain mutations or call a concrete adapter.
- An adapter must not decide authority, lifecycle validity, or policy.
- Test support must not be a production dependency.

The dependency fixture guard rejects an inward package that imports
`hngh.adapters.*` or `hngh.presentation`.

## Component promotion ladder

1. Define a pure domain value or policy and fixture-test valid and invalid
   inputs.
2. Add an application use case and an inward port only when the policy has a
   named outcome.
3. Add a fake-backed application test before any concrete detail.
4. Add one adapter with fixture-backed failure behavior and a restricted data
   boundary.
5. Add manual presentation that renders application output without mutation.
6. Consider an external action only after a current policy certificate validates
   its authority, evidence, rollback, containment, and exact action class. A
   human-approval deployment profile may add a human gate; it is not the
   internal control mechanism.

A later step does not excuse a missing earlier step. Unknown or malformed input
refuses advance.

## Composition rule

`hngh.main`, when introduced, is the only composition root. It constructs
concrete adapters, connects them to application ports, resolves an
operator-visible root, and starts no background work by import. Library,
domain, application, adapter, and presentation packages have no hidden startup
path.

## Current implementation

The active implementation contains `hngh.domain`: pure profile, mission, role,
loadout, run, and evidence values with a closed lifecycle. `hngh.application`
contains `create-run`, `arm-run`, `start-run`, `checkpoint`, and `close-run`
with capability-specific inward ports and closed application and evidence
values.
`checkpoint` advances only a running run after separate verification and manifest
callbacks return closed success values. `hngh:validate-profile` remains a
compatibility facade.
`hngh.adapters.evidence` is an installed read-only evidence adapter behind an
injected process transport; it maps a fixed command set to domain evidence
values and decides no policy. `hngh.adapters.mutation` is an installed
certificate-bound mutation adapter behind an injected process transport; it
rechecks current evidence and emits only fixed argv for the named action.
`hngh.adapters.review` is an installed bounded model-review adapter behind an
injected reviewer transport; it sends one closed prompt, sanitizes the
structured output into finding labels and citations, and maps the result to a
deterministic domain evidence fact — reviewers advise, never decide, and no
default provider transport exists.
`hngh.presentation` is installed as a renderer-only component: it renders
application results, domain runs and governance values, and adapter results
into plain factual strings, keeps refusals literal, applies the optional
reference lexicon only as display copy at a named surface, and imports no
adapter. `hngh.main` is installed as the composition root: `make-run-harness`
composes the five use cases over injected or fail-closed default port
adapters, coordinator functions wire the installed evidence, mutation, and
review adapters through injected transports, and `display` renders any
result through `hngh.presentation`. It starts no background work by import
and supplies no default model or terminal transport.
