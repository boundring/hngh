# Decisions

## 2026-08-11 — Clean-slate kernel

The former daemon, plugin, watcher, dashboard, and mission-control system is
retired. The active product begins with a compact, side-effect-free kernel.

## 2026-08-11 — Archive is evidence, not a dependency

The retirement archive lives outside the repository. `make check-archive`
checks its immutable receipts when the local archive is available. Active
source must not import, launch, or configure archived components.

## 2026-08-11 — Fail closed by default

Unknown or malformed profile modes and duplicate entries refuse validation.
Future lifecycle and adapter work keeps the same rule.

## 2026-08-11 — Dependency direction precedes details

The domain depends on Common Lisp only. Application code depends inward on the
domain and reaches details through ports. Adapters and presentation remain outer
components. `hngh.main` is the only future composition root.

## 2026-08-11 — Run lifecycle is closed and evidence is non-authoritative

`hngh.domain` owns pure run policy and values. A new run is `created`; only the
following transitions are legal:

| From | To |
|---|---|
| `created` | `armed`, `cancelled`, `dead` |
| `armed` | `running`, `cancelled`, `dead` |
| `running` | `checkpointed`, `cancelled`, `evacuated`, `dead` |
| `checkpointed` | `running`, `cancelled`, `evacuated`, `dead` |
| `cancelled`, `evacuated`, `dead` | `afterlife` |
| `afterlife` | `scored` |
| `scored` | `archived` |

Every other pair refuses. Receipt, score, and afterlife values are evidence;
they do not receive a run, state, actor, capability, or transition operation and
cannot create authority. The domain accepts no path, environment, clock,
subprocess, or provider payload.

## 2026-08-12 — Autonomous policy certificate

Routine feature, scope, capability, failure-disposition, review, staging,
commit, and push decisions are policy-driven. Operators guide policy, select
deployment profiles, and receive evidence; their perception is not the routine
approval mechanism. Each proposal is evaluated against closed principles and a
source manifest. Missing, conflicting, malformed, stale, or unverifiable
evidence refuses.

A current certificate binds one action class to its repository identity, base
revision, ordered candidate manifest, content hash, evidence hashes, principle
verdicts, reviewer findings, source manifest, policy profile, and expiry. It
must be rechecked immediately before the named action. A commit certificate does
not authorize a push. A human-approval profile remains available for deployments
that need it, while policy-authorized self-approval is Hngh's intended routine
path.

Deterministic policy evidence is authoritative for structural facts. Local and
alternate-provider model reviewers may issue closed, source-cited challenges;
they cannot override deterministic refusal, mint a certificate, or mutate a
repository.

## 2026-08-12 — Deterministic proposal evidence ledger

The pure evaluator receives one immutable `policy-proposal`, not an untyped bag
of evidence labels. A proposal records its closed class; problem; smallest
useful outcome; named purpose, caller, input, output, and failure contract;
declared capability set and capability diff; source manifest; risk note;
dependency; evidence trigger; and an ordered ledger of evidence requirements.

Each immutable `evidence-requirement` binds one closed principle to one closed
requirement kind, its required fingerprints, and supplied immutable evidence
facts. The requirement-kind vocabulary, rather than the intentionally open
evidence-fact kind, defines evaluator meaning. A requirement is complete only
when every required fingerprint is supplied exactly once by a current fact.
Missing, duplicate, stale, malformed, conflicting, or unverifiable facts
refuse. A reviewer result remains a fact that cannot pass a principle unless a
later policy explicitly admits its requirement kind.

This ledger is policy data only. It contains no certificate action, repository
authority, provider execution detail, port, callback, filesystem, Git, process,
clock, environment, or network field. External verification produces facts in a
later adapter; the evaluator only consumes immutable values.

## 2026-08-17 — Deterministic principle evaluation

`evaluate-policy-proposal` consumes one immutable `policy-proposal` and returns
a `policy-verdict` with exactly ten principle results in matrix order, one per
closed principle: `closed-authority`, `least-authority`,
`dependency-direction`, `fail-closed`, `evidence-before-claim`,
`atomic-mutation`, `reversibility`, `no-hidden-execution`,
`cost-and-route-discipline`, and `source-grounding`. The order is fixed by the
matrix, never by requirement order in the proposal.

A principle with no evidence requirement is a refusal: a `:refused` principle
result with no fingerprints and the reason label `missing-principle-result`; a
missing principle result is a refusal. A single evidence requirement passes
only when every required fingerprint is supplied exactly once by a `:current`
fact. Missing, stale, malformed, conflicting, or unverifiable facts refuse
with the labels `missing-evidence`, `stale-evidence`, `malformed-evidence`,
`conflicting-evidence`, and `unverifiable-evidence`. A fact supplied under one
principle never satisfies a requirement of another principle. The verdict is
`:admitted` only when every principle result is `:passed`; otherwise
`:refused` with the deduplicated union of refusal labels in matrix order.

Evaluation is deterministic, side-effect-free, and independent of requirement
order. The pure evaluator never emits `:needs-escalation`; that state remains
reserved for later reviewer and failure-disposition policy. Extra `:current`
facts beyond a requirement's required fingerprints do not refuse: the closed
refusal vocabulary names only missing, duplicate, stale, malformed,
conflicting, and unverifiable facts.

## 2026-08-17 — Closed failure-disposition policy

`evaluate-failure-disposition` maps each of the eight closed failure categories
to exactly one closed disposition. Domain and application invariants propagate
to the test gate; port-callback faults and malformed returns normalize to a
refusal at that callback only; atomic recording conflicts normalize to conflict
without retry; insufficient or stale evidence refuses; tool and environment
faults refuse; review disagreement escalates; and mutation precondition
mismatches stop and record evidence.

The two conditionally worded table rows resolve to their primary default in
the pure policy: a domain-policy-or-invariant failure propagates to the test
gate (a typed domain refusal refines this at a later layer), and a tool or
environment fault refuses (named evidence-policy escalation is a later
refinement). An unknown category refuses. The policy is pure and
deterministic; a use case never decides a disposition by catch-all condition
handling.

## 2026-08-17 — Non-mutating candidate authorization certificate

`issue-candidate-certificate` mints an immutable `candidate-certificate` from
an `:admitted` policy verdict. The certificate authorizes one action only
(`:none`, `:prepare-candidate`, `:stage`, `:commit`, or `:push`) and records
repository identity, base revision, ordered candidate paths, content hash,
evidence hashes, the admitting principle verdict, review findings, source
manifest, policy profile, and expiry.

The pure issuer is mechanical: it binds one closed action and the supplied
facts into the immutable value. Action-admission policy (for example a commit
certificate never authorizing a push) is enforced later by the executor, not
by the domain issuer. Missing, unknown, malformed, or duplicate facts refuse.
The certificate contains no action, callback, port, filesystem, Git, process,
clock, or network execution.

## 2026-08-17 — Policy-gated run close

`close-run` advances a run to a terminal state (`:cancelled`, `:evacuated`, or
`:dead`) only under the admitted policy proposal and evidence process. The
request carries the run, a closed terminal target, and a policy proposal; the
use case evaluates the proposal deterministically and refuses the close with
the verdict reason labels unless the verdict is `:admitted`. An illegal target
for the run's state refuses with the closed `invalid-transition` label, and
recording stays one atomic run-and-receipt callback.

`close-run` issues no certificate: the hash-bound certificate vocabulary
serves the future mutation executor, not run-state transitions. Action-admission
policy (such as a commit certificate never authorizing a push) remains with
that executor.

## 2026-08-18 — Read-only evidence adapter

`hngh.adapters.evidence` gathers fixed read-only local evidence through an
injected process transport (composition supplies the real `process-run`
callback) and maps the results to domain evidence facts and source manifest
entries with closed states. The command set is fixed and enumerable:
repository revision, whole-tree working-tree status, and file content
hashing. A request names one command plus relative, duplicate-free targets
and a source role; no caller-supplied command string is ever built.

The adapter fails closed on unknown commands, malformed or unparseable
command output, escaping, absolute, home-relative, or option-like targets,
duplicate evidence, and thrown or malformed transport returns. Command
failures are recorded as evidence with closed states: a missing file is
`:missing`, an unreadable or unverifiable command result is
`:unverifiable`, and a successful fixed command yields `:current` facts.
The adapter never decides policy, never reads a requirement ledger, and
never mutates anything; all subprocess and filesystem access stays behind
its transport callback so tests use fixture responses. The mutation
executor remains its first consumer.

## 2026-08-12 — Recover partial delegated lanes before retrying

A delegated lane that stops after writing code, including on a syntax or
compilation failure, leaves a recovery candidate rather than disposable state.
The next worker first reads the brief, inspects the actual worktree, and
identifies the smallest canonical repair. It preserves valid fixtures and
coverage, reconciles overlapping partial definitions, and does not reset,
stash, or replace the lane without an explicit decision.

Recovery ends only after the whole affected gate passes again and a fresh
reviewer checks the frozen candidate. A clean compilation alone is not
recovery: missing refusal cases, defensive-copy proofs, or scope boundaries
remain failures. This keeps a failed delegation from becoming either silent
data loss or an unreviewed reimplementation.

## 2026-08-12 — Application callback and outcome boundary

`hngh.application` use cases handle a callback error or malformed callback
return only at that callback invocation. Domain and application failures remain
visible to the test gate. A successful application result contains the exact
run-and-receipt pair passed to the single atomic `record-run` callback; refused,
invalid, and conflict results contain neither. Recording is never retried unless
a later use-case contract explicitly admits it. `arm-run` advances only a
created run after authority, ledger, loadout, and exclusive-write facts are all
`:confirmed`; every other fact status refuses without recording. `start-run`
advances only an armed run to `:running` through its one-slot atomic
recording port; an invalid transition refuses without recording. `checkpoint`
advances only a running run to `:checkpointed` after the tool executor returns
`:passed` verification and the repository inspector returns a `:complete`
manifest. Both callbacks receive only a closed request containing the domain
run. Any failed, unknown, incomplete, malformed, or callback-faulted evidence
refuses without recording. A checkpoint record conflict does not retry.

Canonical states, receipts, CLI flags, configuration, and use-case outcomes use
plain technical terms. Optional reference lexicons provide display copy with an
original fallback and provenance; they cannot carry control fields or change
behavior.
