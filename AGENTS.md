# hngh — agent notes

## Start of every task

1. Read `docs/README.md`, then the one core document matching the task.
2. Read the active hold in `docs/core/delivery.md` and the exact work package.
3. Inspect live lanes and claims before touching a shared file.
4. Read legacy material only when a task names it. Compatibility aliases exist for old links; they are not the working surface.

## Coordination and authority

- Hngh is durable; an agent session is a temporary lease. A session owns only its explicit write boundary.
- Record claims, evidence, terminal reason, and visible claim release. Never silently take over a stale lane.
- The operator decides scope, budget, privileged operations, release, and any weakened safety boundary.
- Do not print secret values from environment files, credentials, keys, or runtime state. Use by-name scripted access only.
- Do not commit or push without explicit operator approval. `origin` mirrors GitHub and Codeberg; a later approved push must reach both.

## Model and context economy

- Use local procedural routes first. Use known-price cheap remote workhorses only after admission.
- A high-capability or unknown-price route is reserve work: explicit task, compact no-tools packet, input/output bounds, budget reservation, and actual-use receipt.
- Treat provider/model/price/quota observations as data. Record `UNKNOWN`; never invent a route, price, or receipt.
- Retire a session after a completed phase, verified blocker, safety issue, or no-evidence state. A successor receives a compact factual handoff, never an inherited claim or transcript replay.
- Read `docs/core/session-operations.md` before launching, steering, or closing an agent session.

## Repository workflow

- Build: `make build`.
- Test: `make test`.
- The current delivery frontier is card 131, the context-component ledger. Read `docs/core/delivery.md` before selecting it or any dependent work.
- Documentation changes update the appropriate core record, `docs/records/` journal/manifest, and `CHANGELOG.md` when user-visible or architecture-relevant.
- Keep source changes small, fixture-backed, and within the named task. A test result is reported only when actually run.

## Documentation topology

| Need | Current location |
|---|---|
| project purpose and authority | `docs/core/charter.md` |
| architecture boundary | `docs/core/system-design.md` |
| session lifecycle and afterlife | `docs/core/session-operations.md` |
| work breakdown and active order | `docs/core/delivery.md` |
| records, backlog, archive rules | `docs/core/records-and-governance.md` |
| new ideas | `docs/records/backlog.md` |
| historical material | `docs/archive/2026-08-10-pre-consolidation/` |

All generated artifacts and session records name their producer: agent, actual model/provider, harness, and nonzero cost when known.
