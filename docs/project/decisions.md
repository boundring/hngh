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
