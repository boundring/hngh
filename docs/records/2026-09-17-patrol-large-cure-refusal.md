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
