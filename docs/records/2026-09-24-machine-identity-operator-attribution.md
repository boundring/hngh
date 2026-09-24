# 2026-09-24 - Machine identity flip: machine commits attribute the operator

## Decision

Operator decision (2026-09-24, continuing the 2026-09-23 attribution
rewrite, docs/records/2026-09-23-attribution-rewrite.md): machine-written
commits attribute the operator `boundring <boundring@gmail.com>`, like
the rest of history. The per-invocation identity-pin seam stays:
attribution never depends on ambient `.git/config`; only the pinned
identity values change from `hngh-machine <automation@hngh.local>`.

## What changed

- Seven automation pin sites flip `user.name`/`user.email` to the
  operator identity (same quoting, same position on the git command):
  - automation/cadence/day/01-lesson-harvest.sh
  - automation/cadence/day/14-plan-ledger-sync.sh
  - automation/cadence/day/17-torch-audit.sh
  - automation/cadence/hour/30-kernel-ledger-sync.sh
  - automation/cadence/hour/33-research-beat.sh
  - automation/jobs/config-backup.sh (identity-contract comment updated)
  - automation/scripts/research-sweep-selfheal.sh
- Kernel surface: scripts/ceremony-drive pin-identity-default values
  (GIT_AUTHOR_NAME/EMAIL, GIT_COMMITTER_NAME/EMAIL) become boundring /
  boundring@gmail.com. It lands only through the certificate ceremony as
  a `hngh: candidate <content-hash>` commit (find it with
  `git log --grep 'hngh: candidate'`; the hash is regenerated per
  ceremony run, so it is not recorded here).
- automation/tests/test-identity-seam.py: the guard now checks the
  pinned identity VALUE, not just pin presence (PIN_RE
  `user\.name=["']?boundring(?![\w-])`; a foreign or reverted pin flags
  fail-closed). strip_quoted inlines `user.name="..."` values before
  stripping quoted prose, so the real double-quoted shell pin shape
  stays visible while `-m "pinned user.name=boundring"` still strips
  wholesale. Fixtures: the four pinned fixtures move to the operator
  identity (jobs/pinned.sh exercises the unquote path) plus a new
  wrong-identity fixture (jobs/wrong-identity.sh) that must flag.
- tests/scripts/test-ceremony-drive-commit-identity.py: OPERATOR_NAME /
  OPERATOR_EMAIL constants ("boundring" / "boundring@gmail.com") replace
  the machine-identity constants; the ambient-leak test renames to
  test_ambient_leak_is_pinned_to_operator_identity. The explicit-env
  precedence test is unchanged (an explicit GIT_* override still wins).
- docs/project/decisions.md: the 2026-09-23 attribution-rewrite entry's
  machine-lane sentence records this flip.

## Observations

- The guard's reported line numbers for continuation-joined violations
  drift by the count of earlier `\`-continuations in the file
  (continuation_joined merges wrapped lines before the scan). Pre-existing
  scanner property; the violation line content itself is shown verbatim.
  Not changed here.

## Verification (slice 2026-09-24)

- python3 automation/tests/test-identity-seam.py: green, self-tests
  including the new wrong-identity fixture; red probe (a pin reverted to
  hngh-machine in cadence/day/14-plan-ledger-sync.sh) flags fail-closed
  ("non-operator-pinned git commit") and reverts clean.
- cd automation && make test: full automation gate green.
- Kernel-surface half is gated by
  python3 tests/scripts/test-ceremony-drive-commit-identity.py and the
  full `make test` run immediately before its ceremony commit; the
  ceremony's certificate-bound verdict is the binding gate.
