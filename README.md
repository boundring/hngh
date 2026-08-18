# Hngh

## What Hngh is

Hngh turns development work into short, bounded cycles — plan, check, record, close — that an
automated agent can run while a human keeps the final say. Every cycle leaves a paper trail of
evidence; nothing changes the system without passing a check and being recorded. The kernel
(`hngh.domain` plus `hngh.application`) is side-effect-free: it does nothing on its own, owns no
background process, refuses anything unknown or unverified, and today is a library with tests, not a finished tool.

## Why

Agent tools that act without records or boundaries are hard to trust. Hngh exists so automation
works like careful humans do: decide what is valid first, record what happened, and keep a
person's final say. Nothing runs in the background, and nothing changes files or systems silently.

## How it works

A run is one bounded work cycle with a clear lifecycle:

- created — defined, but has done nothing yet
- armed — given permission and evidence for one specific job
- running — the work happens
- checkpointed — verified progress is recorded
- closed — cancelled, evacuated, or finished; terminal states are permanent

Retry means a new run, never a silent continuation of an old one.

- Fail-closed: unknown, malformed, duplicate, or unverified input is refused — never guessed,
  never skipped.
- Evidence: receipts record what happened; they justify but never grant power.
- Certificates: permission for exactly one action (prepare, stage, commit, or push), bound to
  specific files and evidence, re-checked immediately before the action.
- Clean architecture: the core logic depends on nothing external; the outside world plugs in at
  the edges through explicit ports — the read-only evidence adapter is the first such edge.

## Status

Today the kernel is a pure library with fixture tests (`make test` runs 8 reader-guard checks
plus 1059 checks). Implemented:

- Pure domain values — profile, mission, role, loadout, run, receipt, score, afterlife — with a
  closed lifecycle.
- Five application use cases: create-run, arm-run, start-run, checkpoint, and close-run (the
  terminal close is policy-gated).
- Governance: proposal-evidence ledger, deterministic evaluation of ten principles, closed
  failure-disposition policy, non-mutating candidate authorization certificate.
- Read-only evidence adapter: a fixed command set (repository revision, working-tree status,
  file content hashing) gathers evidence facts and source manifest entries through an injected
  process transport; unknown commands, malformed output, escaping targets, and duplicate
  evidence fail closed. The kernel itself stays pure — no subprocess, clock, or environment
  access reaches domain or application code.
- Mutation executor: `hngh.adapters.mutation` rechecks every certificate fact against fresh
  evidence, then sends only the certificate-bound fixed Git action through an injected process
  transport; stale facts, expiry, disabled actions, command failures, and transport faults
  refuse without mutation.
- Bounded model-review adapter: `hngh.adapters.review` turns a closed review request (candidate
  paths, content hash, policy-context labels) into one fixed prompt, sends it through an
  injected reviewer transport, and maps the structured output into sanitized, duplicate-free
  finding labels and citations plus one deterministic review evidence fact. Malformed JSON,
  unknown fields, unsafe citations, oversized output, and transport faults refuse closed; a
  failed review call becomes an `:unverifiable` fact. Reviewers advise — they never decide —
  and the adapter supplies no default provider transport.
- Read-only candidate evidence bundle (`make verify-candidate`) and a read-only retirement-archive verifier (`make check-archive`).

Not yet: persistence, CLI, clock, environment access in the kernel, daemon, real model or
provider transport, or Pi worker.

## Verify

```sh
make test
python3 tests/scripts/test-verify-candidate.py
make verify-candidate CANDIDATE_MANIFEST=path/to/manifest
HNGH_ARCHIVE_ROOT=/absolute/path/to/retirement-archive make check-archive
```

`make verify-candidate` requires an explicit, sorted manifest of regular repository-relative
files. It reports whole-tree state as evidence but never uses it to infer candidate scope. It
refuses excluded (`.hermes/**`), ignored, unknown, escaping, malformed, or unsafe candidate
input, and performs no Git mutation, provider call, service start, or archive read.

`check-archive` verifies the configured local retirement archive. It has no default archive
location and does not write to the archive.

## Where this is going

- Bounded model-review adapters: implemented as the closed-prompt, fixture-backed adapter
  described above — reviewers advise, they never decide.
- Explicit composition and operator-visible presentation, only after the lower contracts
  exist; real model or terminal transports stay disabled until a separately approved run
  loadout admits them.
- Pi as the replaceable outer worker behind a port: read-only by default, while Hngh keeps
  authority, evidence, and termination. Pi and oh-my-pi are under consideration, not installed,
  not decided.
- Cost-first route policy: cheapest adequate route first; expensive routes only with a named
  reason and evidence; unknown cost refuses.

No daemon, provider, watcher, scheduler, or background process is admitted by this stage.

## Documentation

Start at [docs/README.md](docs/README.md) — it separates the active baseline from the external retirement archive in two document hops.
