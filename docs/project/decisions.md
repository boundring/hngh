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
