# CI triage: run 34973375975, job 104394894339 ("test" / "Test local kernel")

Date: 2026-09-15T13:36Z. READ-ONLY triage; no repo changes made by this agent.

## Verbatim failure (from authenticated job log via `gh api .../jobs/104394894339/logs`)

```
python3 tests/scripts/test-loop-history-guard.py
loop-history guard: 114 code-surface commits checked, 13 named exemption(s), 0 violations
python3 tests/scripts/test-loop-history-guard-safeguards.py
  File ".../tests/scripts/test-loop-history-guard-safeguards.py", line 75, in main
    assert entry["patch-id"] == patch_id_of(sha), \
AssertionError: registered patch-id drift for 526cd3f
make: *** [Makefile:12: test] Error 1
##[error]Process completed with exit code 2.
```

Note: the main guard itself PASSES on CI (0 violations, 13 exemptions).
Only the safeguards self-check fails, on entry `526cd3f`.

## Failing check

`test-loop-history-guard-safeguards.py` step 3 ("standing table check:
reachable hashes, no patch-id drift"): for every `KNOWN_EXEMPTIONS` entry
it asserts `entry["patch-id"] == patch_id_of(sha)` where
`patch_id_of = git show <sha> | git patch-id --stable`.

## Why CI is red while local `make test` is green

- `526cd3fd` ("docs: portfolio surface", 2026-09-06) is the ONLY
  exemption whose diff contains a binary file
  (`docs/publication/hngh-memoir.epub`, 857902 bytes, `Bin` in stat).
- `git show | git patch-id --stable` hashes the rendered diff text.
  For binary paths git renders a base85 "GIT binary patch" hunk whose
  encoded bytes depend on the git build / binary-delta encoding, not on
  the blob content. So the computed patch-id is environment-unstable for
  commits touching binaries.
- Evidence of instability in this very session:
  - Local repo (git 2.55.0, full history): `5b6840dfb796a0baeb...` ==
    registered value; all 13 exemptions verified, zero drift;
    `make test` at clean HEAD f726b15e: 2894 checks, exit 0.
  - Fresh `git init` + full `fetch` + checkout of f726b15e (exact CI
    checkout recipe): the safeguards test FAILS with the identical
    `registered patch-id drift for 526cd3f` (exit 1). Reproduced, not
    inferred.
- This is NOT the earlier fetch-depth problem: CI log shows
  `fetch-depth: 0` behavior (full `+refs/heads/*` fetch, guard walked
  114 commits), git 2.55.0 both sides; the failure is the patch-id
  content itself.

## Prior-finding check (08:54Z alert: history-guard needs git history)

Partially superseded. The fetch-depth cure (commit f5e56275, workflow
line 25) is in place and works. The current failure is a different,
residual instability of the same test family: patch-id is not
reproducible across git builds when the exempted commit's diff includes
binary content.

## Root-cause class

Environment-unstable hash input: `git patch-id` over a diff containing
binary hunks is a function of the git build's binary-delta encoding, not
of the commit content. Repo data + test recipe are correct; the check is
not hermetic across git builds.

## Smallest fix

Repo/test-side (preferred, already drafted in
`docs/records/2026-09-15-ci-patch-id-drift.md`, landed as 53674dc by a
parallel agent):

1. Make `patch_id_of` hermetic: feed patch-id from a text-only diff,
   e.g. `git diff-tree -p --no-binary <sha> | git patch-id --stable`
   (binary content never enters the hash).
2. One-pass gate-cure: recompute and re-register every
   `KNOWN_EXEMPTIONS` patch-id under the new recipe, update
   `test-loop-history-guard-safeguards.py`.
3. Scope note: both files are kernel `tests/` surface -> certificate
   ceremony (propose -> issue-cert -> mutation-check), not a
   free-commit automation lane.

Workflow-side alternative (pin runner git version) rejected: fragile.

## Disposition

Diagnosis confirmed and independently reproduced. Cure is parked for the
ceremony lane; no stopgap needed (local gate green, ci-keeper and
test-automation pass). No repo mutation performed by this triage agent.

Evidence artifact of the repro: fresh init+fetch at `$JCODE_SCRATCH_DIR`/
during this session (exit 1, same assertion); clean-HEAD `make test`
exit 0.
