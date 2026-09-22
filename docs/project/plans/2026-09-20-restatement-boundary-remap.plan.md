<!-- plan: status=accepted risk=normal accepted=2026-09-22T13:03:06Z -->
# Remap loop-history guard RESTATEMENT boundary across 2026-09-20 filter-repo rewrite

Proposed via `omp-bridge --propose` (omp session propose surface;
see docs/project/plans/README.md).

## Problem

`tests/scripts/test-loop-history-guard.py:344` fails: `git log
1915713..HEAD` exits 128. Commit `1915713` (the 2026-08-25 restatement
boundary) was orphaned by the operator-directed 2026-09-20
filter-repo secret scrub (`origin/main bd5f1d61 -> b7ee5f1f`; see
`docs/records/2026-09-20-git-history-secret-scrub.md`). All 29
`KNOWN_EXEMPTIONS` hashes dangle the same way, so the standing
reachability self-check also fails.

## Change (only file: tests/scripts/test-loop-history-guard.py)

- `RESTATEMENT = "1915713"` -> `"c257bf6e"`: post-rewrite equivalent,
  matched by identical subject + author date (`docs: restate
  governance claim honestly, ...`, 2026-08-25 12:30:33 -0400) and
  confirmed by identical guard-recipe patch-id
  (`d9c0592bcb06312883d1c6d989c5ae7f19597b70` both sides).
- Remap all 29 `KNOWN_EXEMPTIONS` keys old->new by the same
  patch-id identity (guard recipe: `git diff-tree -p --full-index
  --root <sha> | git patch-id --stable`), cross-checked by
  subject + author date. Old history read from the pre-rewrite
  backup bundle
  `~/.hngh-automation/store/history-backup/hngh-pre-rewrite-bd5f1d61*.bundle`.
- Refresh the 2 registered patch-ids the rewrite legitimately changed
  (secret value lived inside the patched content):
  `526cd3f` entry `df45cd42...` -> `eddb55a8...`,
  `514bdc00` entry `a9cdae6a...` -> `9988955c...`.
  The other 27 registered patch-ids are byte-identical post-rewrite.
- Update stale in-file prose hash references (docstring + reason
  strings) to the new keys.

## Verification

- Failing-first: `python3 tests/scripts/test-loop-history-guard.py`
  exits 1 pre-fix (`CalledProcessError ... '1915713..HEAD' ... exit
  status 128`).
- Post-fix: guard prints `... 0 violations` and exits 0.

## Acceptance

- [x] Reproduction evidence captured before the fix.
- [x] Test passes after fix (`loop-history guard: 143 code-surface commits
  checked, 27 named exemption(s), 0 violations`, exit 0; registered
  patch-id drift 0/28).
- [x] Ceremony PARKED with verbatim refusal (evidence gate runs
  `make test`; `tests/scripts/test-loop-history-guard-safeguards.py:56`
  fails: `git commit-tree ef803bd1...` exits 128 because that fixture
  tree object was pruned by the same 2026-09-20 filter-repo rewrite +
  gc. That file is outside this slice's edit scope, so the lane stops
  here per instructions).

## Ceremony log (verbatim)

- `python3 scripts/omp-bridge --ceremony "Remap loop-history guard
  RESTATEMENT boundary across 2026-09-20 filter-repo rewrite"
  docs/project/plans/2026-09-20-restatement-boundary-remap.plan.md
  tests/scripts/test-loop-history-guard.py`
- ceremony-drive: `ceremony-drive: evidence refused: candidate evidence
  failed`, bridge: `omp-bridge: ceremony refused (exit 1)`
- `python3 scripts/verify-candidate.py --manifest /tmp/cand-manifest.txt`
  (sorted manifest): full `make test` output ending in the safeguards
  `CalledProcessError ... 'commit-tree' ... exit status 128`,
  then `:refused candidate evidence failed`
