# 2026-09-22 — research sweep self-heal (gate-flap cure)

## Problem

The automation gate red-gated hourly from 09-20 through 09-22 (alert
`81bccb06`, occurrence list x14, plus `73cd857c`): the
`research-tsv-path-sweep` `--check` stage of `make test` found raw
home-token rows in `research-dispositions.tsv`. Root cause (not the
sweep's): overnight agent sessions appended disposition rows DIRECTLY,
bypassing the sealed writer seams (`33-research-beat.sh` redact-at-write),
landing raw `/home/<user>/...` tokens in committed rows. Plan acceptance
(`accept-plans.py` runs both gates fresh, rc-blocks on
`automation-gate-red-rcN`) sat blocked until a manual back-redact
landed (fc74aa3b, 12:36Z — ~12h of blocked acceptance; earlier flap
phases 02:01-13:03Z, plus transient uncommitted churn phases 15/17Z
that self-scrubbed).

The sweep already shipped the cure: `--apply` rewrites HEAD blobs
through `redact_home` (the tilde-family fixpoint), refusing dirty
files. It had zero cadence callers — an orphaned tool.

## Change

- `automation/scripts/research-sweep-selfheal.sh` (new): runs
  `--check`; on rc=1 (leaks found) runs `--apply` and commits ONLY the
  paths it rewrote (parsed from `"<path>: rewrote from HEAD ..."`
  output, realpath-relative to `$KERNEL`), as `hngh-machine` with the
  `automation: sweep self-heal back-redacts raw home tokens` message,
  under the staged-index fail-closed guard (`git diff --cached
  --quiet`, the `research_commit` convention). Fail-soft: any error
  exits 0; the gate alert remains the backstop.
- `automation/cadence/hour/33-research-beat.sh`: one fail-soft call
  after the path-variable block (before `research_commit`'s
  definition), passing `KERNEL`/`JOB_NAME`.
- `automation/tests/test-research-sweep-selfheal.sh` (new): hermetic
  full-fixture mirror (sweep + scrub + breadcrumbs + the four research
  TSVs) because the sweep resolves its default scope against its own
  script dir. Cases: (a) committed raw rows -> back-redacted, exactly
  one commit confined to the swept path, crumb written, recheck green;
  (b) clean tree -> quiet no-op; (c) dirty working-tree leak -> no
  commit, churn untouched (fail-closed); (d) staged unrelated work ->
  staged-index guard refuses the commit, rewrite still applied.
- `automation/Makefile`: suite registered in the research block.

## Invariants

- Redact family unchanged: `redact_home` tilde fixpoint only; dash-form
  findings stay report-only (never rewritten).
- Never sweeps dirty/uncommitted churn (live-beat appends survive;
  `--apply`'s mid-flight re-check covers the append race).
- Never commits with staged operator work present.
- Never pushes (sweep tier owns push, per the beat's commit-per-op
  comment).

## Known ceilings (ponytail)

- Default-scope only: leaks in files outside the four TSVs +
  `docs/research/*.md` are invisible to the heal (same as the gate).
- A refused dirty leak stays red until the churn commits or scrubs —
  by design; the gate alert carries it.
- The leak still LANDS in git history first; the heal is
  redact-at-rest, not a writer-seam replacement.

## Verification

- New suite: ALL PASS (4 cases).
- Fresh gate crumbs: `hngh: 2934 checks passed` (17:43:14Z) and
  `hngh-automation: make test ok` (17:46:55Z) after the flap.
- Full automation gate run for this slice: recorded in the slice
  commit message.
