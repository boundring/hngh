# Contributing to Hngh

## Authority and scope

Human directs and decides. Agents and contributors may research, design, implement, and verify only within their named work package and write boundary. The operator approves scope, budget, privileged action, release, and any safety-boundary change.

Start with [`docs/README.md`](docs/README.md). The five documents under `docs/core/` are the current project rules. Material in `docs/archive/` is preserved history and does not grant execution authority.

## Workflow

1. Read the active hold and work order in `docs/core/delivery.md`.
2. Check claims, lanes, dependencies, and the exact write boundary.
3. Create or accept a bounded work package with a verifier and acceptance evidence.
4. Implement the smallest coherent change. Do not modify unrelated dirty files.
5. Run the named focused verification. Report the actual command and result.
6. Record the result in `docs/records/` and update `CHANGELOG.md` for user-visible or architecture-relevant changes.
7. Release the claim visibly. Do not commit or push without operator approval.

## Ideas and designs

Capture a new idea in `docs/records/backlog.md`, not in a new free-standing design file. A backlog entry names the problem, smallest useful outcome, evidence/source, risk/cost/privacy note, dependency, and review trigger.

A design becomes a work package only after its owner, source set, acceptance evidence, and stop condition are explicit. Keep speculative material out of the default agent context.

## Engineering conventions

- Common Lisp follows existing package boundaries and focused fixtures.
- C remains minimal and audit-friendly at the privileged boundary.
- Python follows the project style and makes subprocess contracts explicit.
- Secrets, raw transcripts, and private operational evidence do not enter public Git.
- Agent/model/provider/harness attribution accompanies generated session records and material cost where known.

## License

By contributing, you agree that your contributions are licensed under AGPL-3.0-or-later.
