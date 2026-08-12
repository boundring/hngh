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

## 2026-08-11 — Reference language is renderer-only

Canonical states, receipts, CLI flags, configuration, and use-case outcomes use
plain technical terms. Optional reference lexicons provide display copy with an
original fallback and provenance; they cannot carry control fields or change
behavior.
