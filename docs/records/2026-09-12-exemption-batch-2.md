# Exemption batch 2 -- investigated, empty (2026-09-12)

## The flag

A CI-fix worker reported that commits `1269028`, `403eb95`, `09717fd`,
`da24588`, `c797336`, `8bac308` (and any later ones) touch `tests/` or
`scripts/` without the `hngh: candidate <hash>` label, and that the
loop-history guard would flag them on the next local run. The mission:
declare them post-hoc through the certificate ceremony, following the
2026-09-12 narrative-ledger precedent.

## Finding: false positive

Every named commit touches **`automation/` only** -- `automation/tests/`
-- which is the free-commit lane (commit-per-green rule), not the
kernel code surface. The guard's `CODE_SURFACE` is the repo-root
prefixes `src/`, `tests/`, `scripts/`, `Makefile`, `hngh.asd`;
`automation/tests/...` does not match any prefix. Flagged commits,
all author `boundring`, 2026-09-12:

| Hash     | Subject (abbreviated)                                              | Files touched (all `automation/`) |
|----------|--------------------------------------------------------------------|-----------------------------------|
| `1269028`| dashboard p0/p1-ui contract tests skip when dashboard/ absent       | automation/tests/test-dashboard-p0.py, test-dashboard-p1-ui.py |
| `403eb95`| router-feed test copies report-queue from the checkout              | automation/tests/test-router-feed.py |
| `09717fd`| tests copy report-queue from the checkout (CI runner)               | automation/tests/test-*.sh (6 files) |
| `da24588`| bctx-canary test pins HNGH_HOME to the checkout                     | automation/tests/test-bctx-canary.sh |
| `c797336`| bctx-canary env-override case pins HNGH_HOME too                    | automation/tests/test-bctx-canary.sh |
| `8bac308`| research-governor and ttsr-fit tests pin HNGH_HOME                  | automation/tests/test-research-governor.sh, test-ttsr-fit.sh |

Adjacent commits from the same CI-cure beat, same verdict:
`d317556` (test-context-ratio.py), `4edb3e3` (test-hngh-packages.py,
test-hngh-services.py). The brief's `4edb3e2` is a typo of `4edb3e3`.
HEAD `4ea6cc6` touches only `automation/research-*.tsv`.

Cross-check against `KNOWN_EXEMPTIONS`: every code-surface commit since
the previous exemption declaration (`2eb07fa`) is either
candidate-bound (`7456878`, `cec2bbd`, `d67f1fb`, `b865330`,
`3687c78`, `c8731f1`, `bb04776`) or already declared (`20700c9`,
`0e3b2c6`, `4fc4a0f`, `226de1d`). Nothing to declare.

## Guard state after

```
$ python3 tests/scripts/test-loop-history-guard.py
loop-history guard: 99 code-surface commits checked, 8 named exemption(s), 0 violations
```

No exemption entries were added; no ceremony ran. Registering
non-misses would erode the register's meaning -- a declaration requires
an actual miss.

## Standing policy note (unchanged, restated)

Future kernel-surface fixes go through the ceremony directly
(create-run -> propose -> issue-cert -> mutation-check -> push;
`scripts/ceremony-drive`): the reroute is the preference, declarations
are the fallback. Repo-root `scripts/` and `tests/` are ceremony
surface for machine commits; `automation/` is not.

## Verification

- Guard at HEAD: 0 violations (output above); per-hash probe confirms
  `touches_code() == False` for every flagged hash.
- `cd automation && make test` green (2026-09-12) -- the lane those
  commits belong to is green at HEAD.
- decisions.md entry "2026-09-12 -- Exemption batch 2 investigated:
  no violations exist" records the disposition.