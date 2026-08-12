# Contributing to Hngh

## Scope

Hngh is rebuilt in small, verified slices. The operator approves scope,
budget, privileged work, release, and any change to a safety boundary.

Read `docs/README.md` before working. The external retirement archive is
historical evidence; it does not authorize restoring retired architecture.

## Workflow

1. State the named behavior and acceptance evidence.
2. Write a focused failing test before production code.
3. Implement the smallest behavior that passes.
4. Run the focused check, then `make test`.
5. Run `git diff --check`.
6. Update the matching record and `CHANGELOG.md` when architecture or public
   behavior changes.

## Boundaries

- The domain has no filesystem, process, network, provider, or UI dependency.
- Adapters need a named application port and a fixture-backed contract.
- `~/.hngh` is not a development fixture or implicit state root.
- Do not commit secrets, raw private transcripts, or provider credentials.

## License

Contributions are licensed under AGPL-3.0-or-later.
