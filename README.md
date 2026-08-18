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
  the edges through explicit ports.

## Status

Today the kernel is a pure library with fixture tests (`make test` runs 8 reader-guard checks
plus 717 checks). Implemented:

- Pure domain values — profile, mission, role, loadout, run, receipt, score, afterlife — with a
  closed lifecycle.
- Five application use cases: create-run, arm-run, start-run, checkpoint, and close-run (the
  terminal close is policy-gated).
- Governance: proposal-evidence ledger, deterministic evaluation of ten principles, closed
  failure-disposition policy, non-mutating candidate authorization certificate.
- Read-only candidate evidence bundle (`make verify-candidate`) and a read-only retirement-archive verifier (`make check-archive`).

Not yet: any adapter, persistence, CLI, clock, environment access, subprocess, daemon, model or
provider call, Pi worker, or mutation executor — the kernel decides what is valid but cannot yet
touch the outside world.

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

- Read-only evidence adapter: fixed local evidence commands feed the proposal ledger — evidence
  before claims.
- Mutation executor: re-checks every certificate fact immediately before its named action; it
  refuses changed content, unexpected paths, stale bases, expired certificates, malformed input,
  command failure, and disabled action classes.
- Bounded model-review adapters, only after the lower contracts exist — reviewers advise, they
  never decide.
- Pi as the replaceable outer worker behind a port: read-only by default, while Hngh keeps
  authority, evidence, and termination. Pi and oh-my-pi are under consideration, not installed,
  not decided.
- Cost-first route policy: cheapest adequate route first; expensive routes only with a named
  reason and evidence; unknown cost refuses.

No daemon, provider, watcher, scheduler, or background process is admitted by this stage.

## Documentation

Start at [docs/README.md](docs/README.md) — it separates the active baseline from the external retirement archive in two document hops.
