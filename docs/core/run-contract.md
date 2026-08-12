# Run contract

`hngh.domain` defines pure run policy. It depends on Common Lisp only. It has
no persistence, clock, environment lookup, path resolution, provider payload,
subprocess, port, adapter, CLI, service, or background process.

## Values

All public constructors use closed fields and reject malformed values.

| Value | Required fields |
|---|---|
| Profile | ordered, duplicate-free known mode keywords |
| Mission | objective, non-objectives, source references, acceptance criteria, writable scopes, verification, evacuation condition |
| Role template | name, capabilities, required review role, permitted loadout classes |
| Loadout | opaque route label, nonnegative context/token/cost/time limits, tool/network labels, writable scopes |
| Run | identifier plus a mission, role template, and loadout snapshot |
| Receipt | kind and observed facts |
| Score record | delivery, cost, headroom, turnaround, lesson reuse |
| Afterlife record | terminal cause, observed facts, salvage labels, rejected hypotheses, one lesson candidate |

Labels are duplicate-free lists of nonempty strings. Constructors defensively
copy caller-owned strings and lists; public string/list readers return defensive
copies. All struct slots are read-only. A run always starts in `created`.

## Lifecycle

| From | Legal targets |
|---|---|
| `created` | `armed`, `cancelled`, `dead` |
| `armed` | `running`, `cancelled`, `dead` |
| `running` | `checkpointed`, `cancelled`, `evacuated`, `dead` |
| `checkpointed` | `running`, `cancelled`, `evacuated`, `dead` |
| `cancelled` | `afterlife` |
| `evacuated` | `afterlife` |
| `dead` | `afterlife` |
| `afterlife` | `scored` |
| `scored` | `archived` |
| `archived` | none |

Every unlisted pair signals `invalid-run-transition`. `advance-run` returns a
new run and leaves its input run unchanged.

## Evidence is non-authoritative

Receipt, score, and afterlife records contain evidence only. They do not take a
run, state, actor, capability, or transition operation. They cannot start a run,
change lifecycle state, or grant authority.

## Next boundary

Application use cases may operate on these values only through explicit inward
ports and fakes. Filesystem persistence and concrete adapters remain out of
scope until those contracts are tested.
