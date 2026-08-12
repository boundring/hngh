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

## 2026-08-12 — Application callback and outcome boundary

`hngh.application` use cases handle a callback error or malformed callback
return only at that callback invocation. Domain and application failures remain
visible to the test gate. A successful application result contains the exact
run-and-receipt pair passed to the single atomic `record-run` callback; refused,
invalid, and conflict results contain neither. Recording is never retried unless
a later use-case contract explicitly admits it. `arm-run` advances only a
created run after authority, ledger, loadout, and exclusive-write facts are all
`:confirmed`; every other fact status refuses without recording.

Canonical states, receipts, CLI flags, configuration, and use-case outcomes use
plain technical terms. Optional reference lexicons provide display copy with an
original fallback and provenance; they cannot carry control fields or change
behavior.
