# Overnight review fixes (2026-09-26)

principle: machine lanes consume the declared registry channel, not whatever
PATH happens to shadow it -- config truth is declarative. A binary is
resolved where it is registered (`automation/config/hngh-packages.tsv` col 4)
or not at all.

Operator authority: 2026-09-26 session approving
`local://overnight-review-fixes-plan.md` (review of 2026-09-25 21:30 ->
2026-09-26 13:45 UTC: 22 commits, 10,147 crumbs).

## Findings and fixes

1. **Gate frozen by a date-bombed test seed** (fixed). `test-gate-refusals.sh`
   seeded telemetry with a literal `2026-09-25T00:00:00Z` timestamp;
   `quota_pace_blocked` (`lib/model.sh:531`) counts `ts like '<today>%'`, so
   the seed expired at UTC midnight, cks #1/#5 got `0 0` instead of `1 0`,
   `make test` went rc 2, and `accept-plans.py:514-521` blocked every routed
   plan admission overnight (`automation-gate-red-rc2`, 8+ plans queued at
   the 13:03 tick). Fix (commit `33567b7f`): seed with
   `$(date -u +%Y-%m-%d)T00:00:00Z` so the fixture is correct on any
   calendar day. The scary `FAIL handoffs/agent-handoffs.md bad-execution`
   log line was a red herring: seeded fixture output of the PASSING
   `test-viz-schema-patrol.py`.

2. **opencode binary split killed the dream lane** (fixed). pacman
   `opencode 2.0.16` (installed 2026-09-25, `/usr/bin/opencode`, no `--dir`)
   shadowed the registered npm `opencode-ai 1.18.32` on machine-lane PATH;
   every machine-lane launch died `Unrecognized flag: --dir` and the dream
   legs recorded `forethought-dream-skip`. Fix: registry-first resolution in
   `lib/launch-session.sh` (`awk` over `config/hngh-packages.tsv`, col 4,
   `~` expanded); no row or non-executable target falls back to PATH with a
   fail-visible breadcrumb. Contract test
   `tests/test-ocgo-launch.py::test_registry_pinned_opencode_beats_path_shadow`
   proves the PATH shadow loses. `--dir` stays: the registry channel is v1.
   A v2 cutover is a separate operator-approved slice (retarget the row,
   adapt flags, run in `cd "$ROOT"`).

3. **Typed-park at confidence 1.00 is correct, not a bug** (no change).
   `cadence/hour/33-research-beat.sh:999-1023`: the typed Choice decides
   `adopted|parked|killed` at conf >= 0.60. Parked-at-0.99/1.00 means the
   model confidently classified "keep the record, no action now" under
   strict-sufficiency semantics (`lib/typesafe.py`). The overnight
   local-model parks (os-adapters 0.92, dream-graph 1.00, audit-station
   0.99, steer-vs-kill 0.96) are semantically valid verdicts.

4. **Dash feed staleness self-healed** (no change). 13:00 UTC alerts showed
   `sessions.json`/`operator-items.json` ~971s stale vs the 60s tier; fresh
   (~31s) at review time. The `cadence/subhour/10-sessions-feed.sh` tick was
   firing; alerts and expired-candidate routing worked as designed.

5. **zai/glm-5.3 demote counter reached threshold** (evidence only).
   `state/model-demote.tsv` row `zai/glm-5.3 2 1`; zai served successfully
   via bili at 00:01/01:04 UTC -- but the demote counter is keyed to
   delegated-session outcomes (`lib/launch-session.sh:544-549` records
   `record_model_outcome <outcome_model> ok|bad-execution` per session
   end), not to model.sh chat serves. The last two zai/glm-5.3 delegated
   sessions ended bad-execution and none ran since, so `2 1` is
   stale-but-correct state; it clears on the next session-ending `ok`
   (`lib/model-demote.sh:13`). No hand-edit; observe.

## Research rulings (operator authority)

- `arc-20260925-debt-ledger` kill overturned (dispositions row appended,
  verdict `parked`, `admin:operator-review`): the kill premise claimed the
  ponytail-marker count was "~19 unverified approximation"; the count is
  mechanically verifiable: `grep -rn 'ponytail:' --include='*.sh'
  --include='*.py' --include='*.lisp' automation/ | wc -l` = **20** as of
  2026-09-26 (top files: lint-home-paths.py, ng/watch.py, lib/common.sh at 2
  each). `ponytail:` is a repo-native convention (omp ponytail mode).
- New subject `arc-20260926-descent-adoption-gate` appended to
  `research-subjects.txt`: wire the descent adoption gate per
  `docs/design/descent.md:129-147` (crystallized line -> backlog row with
  named consumer + one-alternation deadline, expired adoptions auto-revoke
  to a citable dead-letter). The prior `arc-20260925` line died in review
  for an empty crystallization, not a rejected thesis; its killed verdict
  stands as history.

## Observations (no action this slice)

- Overnight still executes 2026-09-09-vintage plans (rehearsal-lane,
  stall-recovery): queue state, not re-litigated here.
- `scripts/hngh-omp-update.sh` (~:73) reports the `opencode --version`
  of whatever PATH yields -- harmless now that launches are registry-pinned;
  noted for a future update-script pass.
