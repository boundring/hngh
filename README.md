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
throughput: how many tokens a model can burn in a loop, in a session, in an agent fan-out.
They optimize capability and autonomy, and they are honest about it: sandbox you, hand you a
long tool list, and let the loop run.

A furnace is a useful machine, and so is a busy agent. But a furnace is a machine you watch
from outside; when it fails you learn about it after the fact. When an agent acts without a
record, you can only judge it by what came back, never by what was decided on the way. A 2026
[empirical study of 70 public agent-harness projects](https://arxiv.org/abs/2604.18071)
(H. Wei, "Architectural Design Decisions in AI Agent Harnesses", April 2026) puts it
soberly: sandboxing is common, high-assurance audit is rare, and growing a harness does not
reliably grow its governance. Capability and accountability do not move in lockstep.

Hngh is built the other way around. It prizes the smallest property most harnesses defer:
that every decision is a fact you can walk back to. Decide what is valid first, record what
happened, keep a person's final say. The kernel enforces that by refusing to guess at the
outside world at all. It reads no clock, no file, no network, no subprocess; the outside
world plugs in later through explicit ports. Not the agent that can do the most; the agent
whose every step leaves a trace.

## How it works

A run is one bounded work cycle with a clear lifecycle: created, armed (given one job and
the evidence for it), running, checkpointed (verified progress), closed (cancelled,
evacuated, or finished). Terminal states are permanent. Retry means a new run, never a
silent continuation of an old one.

- Fail-closed: unknown, malformed, duplicate, or unverified input is refused, never guessed,
  never skipped.
- Evidence: receipts record what happened; they justify but never grant power.
- Certificates: permission for exactly one action (prepare, stage, commit, or push), bound to
  specific files and evidence, rechecked immediately before the action.
- Clean architecture: the core logic depends on nothing external; the outside world plugs in
  at the edges through explicit ports, and the read-only evidence adapter is the first edge.
- The harness governs its own repository. The past stays honest: commits that predate
  the loop are recorded as history, not rewritten as governance. The present bootstraps:
  behavior changes ride the loop — proposal → verdict → certificate → executor, under
  real evidence — and where the loop itself refuses a binding (the dependency guard
  will not certify a commit that changes no behavior), the exception is by rule, not by
  mood. The direction is one track: a change the loop can bind, the loop binds; a change
  it cannot, it declares. That sentence is machine-checked: `make test` runs a
  loop-history guard over every code-surface commit since the restatement, and a
  labeled exemption is the only way a change lands outside the loop.

## Status

Hngh is a pure library with fixture tests (`make test` runs 8 reader-guard checks plus a
suite past 2,814 checks — the count grows with every closed vocabulary, and the run prints
the current number) and an operator command surface. Implemented:

- Pure domain values (profile, mission, role, loadout, run, receipt, score, afterlife) with a
  closed lifecycle.
- Six application use cases: create-run, admit-transport, arm-run, start-run, checkpoint, and
  (policy-gated) close-run.
- Governance: proposal-evidence ledger, deterministic evaluation of ten principles, closed
  failure-disposition policy, non-mutating candidate authorization certificate, and
  exhaustive property tests (totality over the closed vocabularies; monotonicity: ignoring
  evidence never flips refused to admitted).
- Read-only evidence adapter through an injected process transport; unknown commands,
  malformed output, escaping targets, and duplicate evidence fail closed.
- Mutation executor: rechecks every candidate-certificate fact against fresh evidence, then
  sends only the certificate-bound fixed Git action; stale facts, expiry, disabled actions,
  and transport faults refuse without a mutation.
- Bounded model review adapter: one closed review request → one fixed prompt → sanitized,
  duplicate-free finding labels and citations; absent, malformed, unsafe, duplicate, or
  oversized output refuses; a failed call becomes an `:unverifiable` fact. Reviewers advise;
  they never decide, and no default provider transport exists.
- Operator command surface (`scripts/hngh`): `create-run`, `admit-transport`, `arm-run`,
  `start-run`, `checkpoint`, `close-run`, `present`, `review`, `terminal`, `propose`,
  `issue-cert`, `mutation-check`, `fetch-evidence`, `verify-attestation`, `list-pins`,
  `wake-peer`, `run-worker`;
  strict exit codes (0 accepted, 1 refused/conflict, 2 malformed, 3 transport fault);
  persistence only under an explicit `--store=PATH`.
- Real evidence chain: certificates mint only from an operator-produced verdict file plus
  genuine repository evidence (git revision, content hashes, working-tree state).
- Read-only candidate evidence bundle (`make verify-candidate`).
- Model and terminal transports behind loadout admission (rung 10): a bounded `:model`
  route for the review adapter and a single-statement `:terminal` evidence capture, both
  advisory with no default provider or input.
- Distributed attestation & evidence federation (rung 11): `hngh.adapters.federation`
  gathers carrier-bundle claims into evidence facts (`fetch-evidence`), verifies
  attestation envelopes through pinned-key/signature ports (`verify-attestation`), and
  admits `:federation` behind the `remote-evidence`/`carrier-bundle` labels.
- Operator pinned-key registry and signature-verification transport (rung 12): a pure
  `key-pin-registry` domain value, a strict pins-file parser, and attestation ports that
  verify one envelope signature through a single bounded
  `openssl dgst -sha256 -verify` invocation on the injected process transport —
  `verify-attestation ... pins=PATH` admits the operator's pins file as the trust anchor
  and `list-pins` renders it; anything unpinned refuses `unknown-peer-key`.
- Ed25519 signature-transport hardening (rung 14): the pins file gains an optional
  closed ALGORITHM column (`rsa-sha256` default, `ed25519` admitted); verification
  routes per pin — digest signatures through `openssl dgst -sha256 -verify`, raw
  Ed25519 signatures through `openssl pkeyutl -verify -rawin` — so `verify-attestation`
  accepts modern keys and `list-pins` renders each pin's algorithm. Verified live
  end to end with a real Ed25519 keypair (`status=verified`, tampered payload
  `bad-signature`).
- Network claim method (rung 15): `fetch-evidence` gains `method=carrier-bundle|http-claim`
  (default carrier-bundle); the `:http-claim` method fetches the same closed bundle
  document from a peer endpoint over HTTP. The peer stays a plain identifier on the
  request and endpoint resolution belongs to the injected transport — there is still
  no default wire, and an unadmitted method is malformed. Verified live over a real
  local HTTP server through an injected transport (`status=complete`, claims mapped
  with the closed state vocabulary).
- Operator policy profiles (rung 16): `propose` gains `profile=PATH` — a strict,
  operator-tunable `PRINCIPLE<TAB>KIND` file that narrows which requirement kinds a
  listed principle may carry (the `:review` kind is now admitted, so a profile can
  demand review evidence). A profile never broadens admission; a listed principle
  whose kinds are all dropped refuses as `missing-principle-result`.
- Wake-on-demand (rung 17): `wake-peer RUN PINS-FILE PEER` issues one explicit wake
  request for a pinned lattice peer behind an injected transport — the pins registry
  is the admission evidence (a peer is admitted by pinning its key) and the run must
  hold a `:federation` admission receipt. No default transport, no daemon: the
  operator's injected transport decides what "wake" means. Unpinned peers refuse
  `unknown-peer-key`; ambient tunnels and certificate-bound wake remain boundary
  amendments.
- Bounded read-only worker (rung 18): `run-worker RUN task=LABEL [payload=TEXT]` runs
  one closed worker task through an injected transport; `:worker` is admitted behind
  the `worker-task` tool label. A completed task binds a `:worker` evidence fact —
  a worker self-report is evidence, never acceptance, and a worker never carries a
  mutation certificate. No default transport.
- Continual-worker driver: `scripts/worker-driver --store=PATH OBJECTIVE TASK
  [PAYLOAD]` runs the one-shot worker cycle (create-run with the worker-task label →
  admit worker → run-worker → close) as a single explicit operator invocation.
  It is glue over the existing surface, adds no authority, and the periodic
  invocation belongs to the operator's scheduler, never a daemon.
- Full-screen dashboard TUI (`scripts/dashboard-tui`): a textual (rich)
  read-only TUI with an animated operative, an active-lanes panel, and
  live session tables, fed from the operator store through the same
  read-only renderer as `dashboard-readout`.
- Interface grading loop (`scripts/grade-interface` + `docs/project/ui-grades.md`):
  a deterministic first-finding grade for each interface, feeding every
  UI iteration — the seed of the federated UI/UX validation the
  assistant-interface design names.
- Operative evolution (`scripts/evolve-operative`): a generated operative
  (generations 1–4/5) with the animation spec in
  `docs/design/operative-frames.md` and the operative layer framed in
  `docs/design/assistant-interface.md`.
- Desktop OSD overlay (`scripts/osd-operative` + `osd-operative.qml`): a
  frameless, always-on-top Plasma 6 webview that floats the operative
  above the desktop, backed by `tests/scripts/test-osd-operative.py`.
- Backlog tooling: `scripts/backlog-lanes` parses `docs/project/backlog.md`
  into lane rows (json/text, status + date, in-queue mapping) so any
  surface can render an active-lanes view; `scripts/notify-agent` is a
  bounded KDE notification reaction agent (`org.freedesktop.Notifications`)
  that classifies job-search signals and appends hits to
  `docs/project/notify-log.md` — one-shot, no daemon, stdlib only.
- Research docs: `docs/project/integrations-marketplace.md` (where the
  governance pattern binds to CI/agent-harness/ops/security tooling) and
  `docs/project/system-harness-roadmap.md` (a fleet of nodes under one
  governance: resource pool, config manager, security manager).

Not yet: daemon, watcher, scheduler, and no ambient state. Each will be admitted the same way
everything else is: through a proposal, a check, and a record. The megastructure is built
one verified stretch at a time.

## Verify

```sh
make test
python3 tests/scripts/test-verify-candidate.py
make verify-candidate CANDIDATE_MANIFEST=path/to/manifest
```

The verify-candidate bundle requires an explicit, ordered manifest of regular repository-
relative files. It reports whole-tree state as evidence, refuses escaping/malformed/
unsafe/duplicate candidates, and performs no Git mutation, provider call, service start, or
archive read.

## Public posture

The project is AGPL-3.0-or-later ([LICENSE](LICENSE)). Governance and contribution rules are
in [GOVERNANCE.md](GOVERNANCE.md), [CONTRIBUTING.md](CONTRIBUTING.md) (DCO sign-off on every
commit), and [SECURITY.md](SECURITY.md) (private coordinated disclosure). Pre-release state is
tracked in [CHANGELOG.md](CHANGELOG.md).

## Where this is going

Hngh is not headed toward a busier agent. It is headed toward a wider corridor: a system that
routes many kinds of work, local and remote models, priced routes, and eventually pooled
hardware, through the same ledger, the same certificate, and the same human-closable cycle.
What changes at each step is the machine on the outside, never the rule the core holds; a
kernel stays the spine the harness can always rebuild around.

At full width, the corridor is a megastructure: not one machine, but a lattice of small
machines, each an Hngh node running the same narrow rulebook, each guarding its own
boundary — the bedroom corner, the hand-held that spends most of its life on a shelf, the
old laptop whose NIC is slower than its patience. None of them is large in anything except
evidence. A node learns what its own wall taught it, and the lesson is not buried in the
ledger where only that node will ever look; it is shared as a fact a neighbor can cite:
this bridge goes down at three in the morning, this tunnel has held for a year, this load
draws this power, this device woke when it was asked and was quiet otherwise. Wake a machine
before you need it. Keep the tunnels open without a watching daemon. Admit the new
low-powered friend the way any new peer is admitted: evidence first, then a place. One
machine never learns what a thousand machines each failed once; a mesh of small ledgered
machines is how a city covers a lawn, then the next lawn, then the planet — and never a
wall that does not say who raised it.

That lattice is a resource pool, not just a mesh: each node is an
addressable component with a status, a duty, a health readout, and a
capability set, surfaced in the dashboard as a row or panel — from a
static line to a full "dance-able" animated surface, the interface-level
grading in [ui-grades.md](docs/project/ui-grades.md). Declared per-node
configuration applies evidence-backed and reverses cleanly; key rotation,
secret hygiene, and patch-state are security-manager duties with the same
certificate-bound evidence chain. The direction is concrete
([system-harness-roadmap.md](docs/project/system-harness-roadmap.md)):
wide-area, low-powered machines are first-class citizens of the harness,
never second-class peers bolted on later.

## Documentation

Start at [docs/README.md](docs/README.md). Records and the external retirement archive cover
the project's prior state; the active baseline lives here.

## For the public

The project publishes a daily journal of its own construction — the
same ledger that governs its releases, written for people to read. Each
day's entry assembles the record, the queue, and the timeline into a
narrative you can follow as the megastructure grows outward. The
project's long-form memoir and the public site (journal, moderated
comments, leaderboards, and the dashboards this README describes) are
the same build pipeline as the code — every public byte is a committed,
checked artifact. The first entry is already here:
[2026-08-25](docs/journal/2026-08-25.md) — and the themed
readout renders live from the same data.

Screens of the dashboards live in `docs/media/` (linear/spiral/
circular/wave, themed); the `--dance` motion is best seen live.

## Contributors & attribution

Who builds Hngh and how it is attributed is in [CONTRIBUTORS.md](CONTRIBUTORS.md).
