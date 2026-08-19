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
archive. It is evidence, not an implementation source, and no active gate
verifies it anymore; the archive verifier was retired on 2026-08-19. Meaningful
archive material is harvested into the operator's separate llm-wiki knowledge
base, not imported back into this repository. Treat prior-state records
(`docs/records/`) as the authoritative history of the refactor.

## Engineering rules

- Keep dependency direction inward and behavior fixture-backed.
- Write a failing test before production behavior.
- Unknown, malformed, duplicate, or unauthorized input fails closed.
- Do not change unrelated retirement-diff paths.
- Inspect the active policy sources, candidate state, and named verification
  before editing.
- Commit a work slice as soon as it is verified: the full gate (`make test`)
  passes, the change is confined to the task's stated scope, docs/records are
  updated, the first-commit message matches the slice, and the working tree
  carries no unrelated changes. Verified commits need no prior operator
  instruction, and may be pushed to the configured `origin` remote
  (`git@github.com:boundring/hngh.git`). Altering provider configuration or
  enabling a service still requires a current policy certificate or an
  explicit operator instruction naming the exact action and target.
- Record architecture-relevant work in `CHANGELOG.md` and `docs/records/`.
