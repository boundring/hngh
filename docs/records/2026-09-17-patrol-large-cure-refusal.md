# 2026-09-17 — Patrol gate-cure LARGE pre-check (refuse before the append)

The gate-cure patrol (`automation/jobs/patrol.py`) declared ANY
loop-history-guard violating commit set post-hoc with no content
inspection: `check_gate_cure` -> `cure_red_gate` ->
`append_exemptions` registered hashes + patch-ids and drove the
ceremony for every red gate. The 2026-09-13 SMALL-matter amendment
(docs/project/decisions.md) requires LARGE matters — credentials,
systemd units, spend caps, deletions, the public surface — to never
auto-cure; until now that refusal existed only as the ceremony's own
verdict, i.e. after the guard table and decisions.md had already been
mutated.

Change (red-first, `automation/tests/test-patrol.py`):

- New `commit_numstat(kernel, sha)` — `git show --numstat --format=`
  rows, the only view where a gutting commit (additions==0,
  deletions>0, the ba6b390 shape) is visible.
- New `is_large_cure_violation(kernel, shas)` — returns a reason
  string when the violating set touches credential-like paths
  (.env/credential/secret/token/pem/AUTH_TOKEN), systemd units
  (.service/.timer/.socket), spend/cost/budget/cap configs under
  `automation/config/`, or contains a pure-deletion diff; "" when the
  set is SMALL.
- `check_gate_cure` runs the pre-check before `cure_red_gate` and
  files the existing `gate-cure-refused` park (no append, no
  decisions.md entry, no ceremony drive) when it fires.

Tests: new
test_large_cure_violation_classifier / test_gate_cure_refuses_credential_surface /
test_gate_cure_refuses_systemd_and_spend_surfaces /
test_gate_cure_refuses_when_any_sha_is_large (mock-subprocess, the
file's established pattern); proven RED against the pre-check-free
patrol (3 failures + 1 error), GREEN after. Full automation
`make test` rc=0 (ALL PASS, 79 suites). No kernel surface touched.

## 2026-09-17 — Gut-shape amendment: pure-deletion rule missed the real
## gut (live replay attached)

Gap (found by the a4d-large-surface-autocure audit): the
`additions == 0 and deletions > 0` rule does NOT match the real
gutting commit it was written for. `git show --numstat --format=
ba6b390` is `1/36 Makefile`, `1/386 README.md` — the gut kept one
vestigial line per file, so additions is 1, not 0. A replay of the
gut (one vestigial line kept) and the c4
delete-KNOWN_EXEMPTIONS-rows trigger (violations =
ba6b390+d2d8f51 with their original diffs) would both have been
auto-declared. The four original tests mocked only synthetic
(0, N, path) rows; no live replay against real history existed.

Fix (deletion-dominance rule, automation/jobs/patrol.py):
`is_large_cure_violation` now flags LARGE when a numstat row is a
pure deletion (additions==0, deletions>0 — unchanged) OR a
deletion-dominated rewrite: `deletions >= _GUT_MIN_DELETIONS` (20)
and `additions * _GUT_PURITY_RATIO <= deletions` (20:1 per file).
Design rationale: the absolute floor is what keeps honest small
edits SMALL (a 1+/1- doc fix has ratio 1 but is not a gut); a ratio
rather than a hard additions<=1 cap is what keeps the rule from
eroding as the vestige line count grows (2+/386- is still a gut);
revert-shaped commits (large additions — d2d8f51's 36+/1-, 386+/1-)
fail the ratio and stay SMALL.

Tests (red-first against a REAL temp-git fixture, not mocked
commit_numstat): new `tests/test-patrol.py::RealGitClassifier` —
setUp builds a real repo and commits the 1-addition gut on code
surface (asserts the numstat rows are exactly 1+/100-, 1+/60-);
test_gut_shape_one_addition_large_deletion_is_large was RED with
reason `''` against the additions==0 rule, GREEN after the fix;
test_revert_shape_large_addition_tiny_deletion_stays_small pins the
real revert numstat shape (100+/1-, 60+/1- — large additions, one
vestigial deletion per file) and stays SMALL;
test_tiny_doc_touch_stays_small pins a 1+/1- doc edit as SMALL.

Live replay of the production declared SHAs through the fixed
classifier (2026-09-17, this repo's history):

| sha | numstat | verdict | reason |
|---|---|---|---|
| ba6b390 | 1+/36- Makefile, 1+/386- README.md | LARGE-refuse | gut-shape diff 1+/36- Makefile |
| d2d8f51 | 36+/1-, 386+/1- | SMALL-declare | "" (revert shape fails ratio) |
| 04f0001 | 1+/0-, 13+/7-, 79+/0-, 56+/6- | SMALL-declare | "" |
| 29d2a27 | 65+/0-, 23+/3- | SMALL-declare | "" |
| 526cd3fd | 6+/0-, 19+/0-, 14535+/0-, 20+/1- | SMALL-declare | "" |
| e6e98f75 | 1+/1-, 5+/0- | SMALL-declare | "" |

The c4 trigger set (ba6b390+d2d8f51, original diffs) now refuses
with the ba6b390 gut-shape reason; before the fix both it and a
ba6b390 replay classified SMALL. Note the declared-table SHA list
already includes commits with large addition counts (526cd3fd's
14535+/0- book build); the ratio rule leaves those SMALL because
they add, not delete, surface.

Full automation `make test` rc=0 after the fix. No kernel surface
touched (constraint held: automation/jobs/patrol.py,
automation/tests/test-patrol.py, automation/CHANGELOG.md, this
record only).
