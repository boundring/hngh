# Hngh agent notes

## Start here

1. Read `docs/README.md`.
2. Read `docs/project/roadmap.md` and the record relevant to the task.
3. Inspect `git status --short` before editing.
4. Run the smallest named verification before reporting a result.

## Current boundary

Hngh is a side-effect-free local kernel. Do not start a daemon, service,
provider, watcher, scheduler, agent, or process. Do not write to `~/.hngh`.

The retired system is outside this repository in an operator-configured local
archive. It is evidence, not an implementation source. Verify it with
`HNGH_ARCHIVE_ROOT=/absolute/path/to/archive make check-archive`.

## Engineering rules

- Keep dependency direction inward and behavior fixture-backed.
- Write a failing test before production behavior.
- Unknown, malformed, duplicate, or unauthorized input fails closed.
- Do not change unrelated retirement-diff paths.
- Inspect the active policy sources, candidate state, and named verification
  before editing.
- Do not stage, commit, push, alter provider configuration, or enable a service
  unless a current policy certificate authorizes that exact action. Until the
  certificate executor exists, a transitional action requires a current explicit
  instruction naming the exact mutation and target.
- Record architecture-relevant work in `CHANGELOG.md` and `docs/records/`.
