# Contributing to Hngh

## Scope

Hngh is rebuilt in small, verified slices. Operators guide policy, budgets,
privileged work, release posture, and safety-boundary changes. Routine scope and
mutation decisions use source-grounded policy certificates; a human-approval
profile remains available where a deployment requires it.

Read `docs/README.md` before working. The retired system's archive is
historical evidence; it does not authorize restoring retired architecture,
and no archive content is imported back into this repository.

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

## Contributor sign-off (DCO)

Every commit in a contribution must end with a `Signed-off-by:` trailer, for
example:

    Signed-off-by: Jane Doe <jane@example.com>

The trailer must match the author name and email in the git configuration.
It certifies that the contribution originates from the author or was
received openly, and that the author knows the license under which it is
submitted: the statements of the Developer Certificate of Origin, version
2.1 (https://developercertificate.org/). It does not transfer any rights
beyond what the license below already grants.

How to add it:

- When creating a commit: `git commit -s`.
- Rebasing a branch: `git rebase --signoff`.
- Do not rewrite closed history to retroactively add sign-offs; if a
  sign-off is missing, the change-set is held out and amended before it is
  admitted, not padded afterwards.

Enforcement (commit check):

- Admission and merge require the check on every commit of the change-set.
  Each commit message must carry a correct `Signed-off-by:` for its
  author. A commit without one is refused and returned for amendment,
  like any other missing evidence (fail closed).

The DCO does not replace the license. Inbound equals outbound: a
contribution is licensed under AGPL-3.0-or-later, the same license as the
repository (License below); no separate CLA is needed, and the sign-off is
not a license grant of its own.

Evidence and ethics first:

- Never include secrets, credentials, private transcripts, or raw dumps of
  private data in a commit, issue, or review. Such material is refused,
  not recycled.
- Unknown, malformed, or unverifiable input is refused, never guessed at,
  in the domain, in intake, and in reviews. Claims are accepted only with
  evidence (see Workflow).

## License

Contributions are licensed under AGPL-3.0-or-later.