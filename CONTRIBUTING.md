# Contributing to Hngh

## Design Principle

**Human directs and decides; AI assistants draft and implement.**

Hngh is developed using the same agentic tools it orchestrates at runtime. The
boundary between "using Hngh" and "developing Hngh" is deliberately blurred — this
is the dogfooding substrate principle. However, a human is always in the loop for
decisions, reviews, and approvals.

## Design Artifacts

All architectural decisions are documented in:
- `docs/design/architecture-decision-record.md` — locked decisions (D1–D11)
- `docs/design/components.md` — component specifications
- `docs/design/integrations.md` — integration and data flow design
- `docs/design/hngh-design-spec.md` — the single source of truth

Changes to architecture require updating these documents first, then implementing.

## Development Workflow

1. Pick a session from `docs/project/work-sessions.md`
2. Create a feature branch: `git checkout -b session/M0.X-short-name`
3. Implement, committing atomically per logical unit
4. Write a journal entry in `docs/journal/YYYY-MM-DD.md`
5. Update the changelog (`CHANGELOG.md`) — add a dated, categorized entry for
   any user-visible or architecture-relevant change
6. Push and open a PR
7. Review (human or AI-assisted)
8. Merge to `main`

## Capturing early ideas (design seeds)

Early / half-formed ideas (user riffs, session observations, speculative
directions) are captured as **design seeds** — lightweight, non-committal
records — so they are not lost to conversation and are available for a later,
proper evaluation. The convention:

- Write a short `docs/design/<topic>.md` file: **Status: Idea capture — NOT
  a build spec**, the idea in the originator's words, a rough (illustrative,
  non-committal) shape, **open questions** (not answered in the seed), a
  **review gate** (conditions under which it gets a proper evaluation), and
  attribution.
- Register it in `docs/project/backlog.md` under Open Design Questions with a
  pointer, so it is tracked rather than orphaned.
- A seed is **never folded into the current build path** until the review
  gate is met: prior art research, a fixtured prototype of the smallest
  useful primitive, and a clear motivated use case. Do not force seeds into
  unrelated work.

This keeps the development cycle rigorous: research + scaffold from
documentation first, no forced experimentation, pieces that suit each other,
and ideas either blossom under Hngh's later self-development work or are
deliberately dropped.

## Commit Convention

```
<type>(<scope>): <description>

<body — what and why>

<footer — refs, breaking changes>
```

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `build`, `ci`
Scope: component name (e.g., `event-bus`, `plugin-host`, `system-daemon`)

## Language Conventions

- **Common Lisp**: follow existing package structure; use `hngh.<component>` package names; package-level isolation enforced
- **C**: follow the system daemon's existing style; minimal, audit-friendly
- **Python**: follow PEP 8; subprocess plugins communicate via JSON-RPC

## Testing

Every component has unit tests. Integration tests for critical flows live in
`tests/integration/`. The end-to-end test (M0.10) must pass before any M1 work
begins.

## Journal

Every work session ends with a journal entry. This is part of hnghbeats — the
narrative record of Hngh's development. Journals are version-controlled and
human-readable.

## License

By contributing, you agree that your contributions are licensed under AGPL-3.0-or-later.