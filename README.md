# Hngh

## What Hngh is

Hngh turns development work into short, bounded cycles, plan, check, record, close, that an
automated agent can run while a human keeps the final say. Every cycle leaves a paper trail of
evidence; nothing changes the system without passing a check and being recorded. The kernel
(`hngh.domain` plus `hngh.application`) is side-effect-free: it does nothing on its own, owns no
background process, refuses anything unknown or unverified, and today is a library with tests,
not a finished tool.

Hngh's ambition is megastructure-scale: an environment that maintains and extends itself,
with local and remote models doing the work and the cost of that work kept visible. Its method
is paperwork. That is not a contradiction; paperwork is the building material.

## Why

Most open-source agent harnesses are built to move fast. Their winning trait is normally
throughput, how many tokens a model can burn in a loop, in a session, in an agent fan-out.
They optimize capability and autonomy, and they are honest about it: sandbox you, hand you a
long tool list, and let the loop run.

Consider a furnace. Fuel in, work out, hard to inspect from inside, and nobody plans to live
in it. The furnace is not wrong; a furnace gets hot, and that is useful. But it is a machine
you watch from outside, and when it fails you learn about it after the fact. Hngh is built
like a building instead: load-bearing rules, corridors between floors, and a fire door you
can point at. The point of a building is that it stays up, and that you can walk its full
length later, floor by floor, and see what each room was for.

That is why Hngh exists. Automation that acts without a record is a machine you can only
judge by what came back, not by what was decided on the way. When it goes wrong, and a model
eventually will, you cannot reconstruct the decision. A 2026
[empirical study of 70 public agent-harness projects](https://arxiv.org/abs/2604.18071)
(H. Wei, "Architectural Design Decisions in AI Agent Harnesses", arXiv:2604.18071, April
2026) puts it in soberer terms: intermediate isolation (sandboxing) is common, but
high-assurance audit is rare, and growing a harness does not reliably grow its governance.
Capability and accountability do not move in lockstep.

Hngh is built the other way around. It prizes the smallest property most harnesses defer:
that every decision is a fact you can walk back to. Automation should work like careful
humans do. Decide what is valid first, record what happened, keep a person's final say. Not
the agent that can do the most; the agent whose every step leaves a trace.

The kernel enforces that by refusing to guess at the outside world at all. It reads no clock,
no file, no network, no subprocess; the outside world plugs in later through explicit ports.
That asymmetry against the mainstream is deliberate, and it is what keeps Hngh small enough
to reason about as it grows into a harness.

## How it works

A run is one bounded work cycle with a clear lifecycle:

- created: defined, but has done nothing yet
- armed: given permission and evidence for one specific job
- running: the work happens
- checkpointed: verified progress is recorded
- closed: cancelled, evacuated, or finished; terminal states are permanent

Retry means a new run, never a silent continuation of an old one.

- Fail-closed: unknown, malformed, duplicate, or unverified input is refused, never guessed,
  never skipped.
- Evidence: receipts record what happened; they justify but never grant power.
- Certificates: permission for exactly one action (prepare, stage, commit, or push), bound to
  specific files and evidence, re-checked immediately before the action.
- Clean architecture: the core logic depends on nothing external; the outside world plugs in at
  the edges through explicit ports, and the read-only evidence adapter is the first such edge.

## Status

Hngh is a pure library with fixture tests (`make test` runs 8 reader-guard checks plus 1334
checks) and an operator command surface. Implemented:

- Pure domain values (profile, mission, role, loadout, run, receipt, score, afterlife) with a
  closed lifecycle.
- Five application use cases: create-run, arm-run, start-run, checkpoint, and close-run (the
  terminal close is policy-gated).
- Governance: proposal-evidence ledger, deterministic evaluation of ten principles, closed
  failure-disposition policy, non-mutating candidate authorization certificate.
- Read-only evidence adapter: a fixed command set (repository revision, working-tree status,
  file content hashing) gathers evidence facts and source manifest entries through an injected
  process transport; unknown commands, malformed output, escaping targets, and duplicate
  evidence fail closed.
- Mutation executor: `hngh.adapters.mutation` rechecks every certificate fact against fresh
  evidence, then sends only the certificate-bound fixed Git action through an injected process
  transport.
- Bounded model-review adapter: `hngh.adapters.review` turns a closed review request into one
  fixed prompt, and maps the structured output into sanitized finding labels and citations.
  Reviewers advise; they never decide.
- Operator command surface (`scripts/hngh`): `create-run`, `admit-transport`, `arm-run`,
  `start-run`, `checkpoint`, `close-run`, `present`, `propose`, `issue-cert`, and
  `mutation-check` with strict exit codes (0 accepted, 1 refusal or conflict, 2 malformed
  invocation, 3 transport fault). Persistence happens only under an explicit `--store=PATH`.
- Real evidence chain: certificates mint only from an operator-produced verdict file plus
  genuine repository evidence (`git` revision, content hashes, working-tree state), gathered
  through an injectable transport that validates the result.
- Read-only candidate evidence bundle (`make verify-candidate`).

Not yet: daemon, watcher, scheduler, real model or provider transport, and no ambient state.
Each will be admitted the same way everything else is: through a proposal, a check, and a
record. The megastructure can wait; it is built one verified stretch at a time.

## Verify

```sh
make test
python3 tests/scripts/test-verify-candidate.py
make verify-candidate CANDIDATE_MANIFEST=path/to/manifest
./scripts/hngh --help   # or run `scripts/hngh` with no arguments
```

The verify-candidate bundle requires an explicit, ordered manifest of regular
repository-relative files. It reports whole-tree state as evidence and performs no Git
mutation, provider call, service start, or archive read.

## Public posture

The project is AGPL-3.0-or-later ([LICENSE](LICENSE)). Governance and contribution rules are
in [GOVERNANCE.md](GOVERNANCE.md), [CONTRIBUTING.md](CONTRIBUTING.md) (DCO sign-off on every
commit), and [SECURITY.md](SECURITY.md) (private coordinated disclosure). Pre-release state is
tracked in [CHANGELOG.md](CHANGELOG.md).

## Where this is going

Hngh is not headed toward a busier agent. It is headed toward a wider corridor: a system
that routes many kinds of work, local and remote models, priced routes, and eventually pooled
hardware, through the same ledger, the same certificate, and the same human-closable cycle.
The megastructure is mostly paperwork. That is not a concession; that is the premise.

What changes at each step is the machine on the outside, never the rule the core holds. The
kernel stays the single spine the harness can always rebuild around, and the read-only
evidence adapter is the first edge: every external claim is verified against real
repository state before it can bind.

## Documentation

Start at [docs/README.md](docs/README.md). Records and the external retirement archive cover
the project's prior state; the active baseline lives here.