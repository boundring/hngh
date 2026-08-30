# Lessons and fold-back — 2026-08-30

Status: RECORD. Evidence cited per claim; admits no runtime capability.

Source: the operator's 2026-08-30 doc suite (`~/Projects/etc/20260830`,
adversarially audited) plus direct reads of `docs/project/reports.md`,
the 2026-08-28 evening-selfdev plan, hngh-automation logs/digests, and
git history. This record folds the suite's verified corrections back
into the kernel docs and captures what the 33h+ unattended window
actually produced.

## 1. What the unattended window produced (2026-08-28T19:43Z → 2026-08-30T12:30Z)

- **One plan, executed end to end.** The operator-authored
  2026-08-28 evening-selfdev plan (8 steps, accepted 19:43:12Z) ran
  unattended through 13h18m to both gates green (progress rows
  `ad39f093`/`f92dc864` at 2026-08-29T09:01:17Z), landing seven
  hngh-automation commits (`585ccd0`…`2ea3db0`, CHANGELOG 2026-08-28).
  All 8 steps verified; no step parked.
- **Zero kernel commits after `667a36b`** (2026-08-28T19:46Z) through
  2026-08-30T12:30Z — 40h+ of kernel idle not from failure but from
  plan exhaustion: the machine cannot author plans (suite doc 07 §3,
  08 R2). The hourly workbeat re-announced the same lane identically
  on both mornings (rows `f27e3532` 08-29T09:00Z / `9b362832`
  08-30T09:00Z, "10 open lane(s); next=lane: hngh-autonomy-build") —
  motion without a plan.
- **Research: 12/12 lines crystallized.** Overnight 08-28→29 the
  30-min day-tier beat advanced lines at ~60–65 min per line
  (planned→expanding→contracting→crystallized; rows 22:03→23:03
  `logs-known-good-patterns`, 00:03→01:03 `remote-access-patterns`,
  02:03→03:03 `research-publishing-pipelines`, 04:03→05:03
  `unattended-session-budgets`, 06:03→07:03
  `virtual-assistant-ux`); per-beat wall 148–155 s (telemetry
  `research-beat` rows). Each line is one `model_call 4096` per
  transition over the local model chain — no search calls, no external
  references — so depth is bounded by the beat's prompt and prior
  material. The crystallize step wrote six docs into the kernel's
  `docs/research/`; they sat uncommitted for ~36h because landing
  kernel docs needs a ceremony and no plan remained to drive one
  (landed 2026-08-30, `1f04b5b`).
- **Failure classes in the window** (reports.md rows 2026-08-28T20:10Z
  → 2026-08-30T12:04Z): 2 stale-store ceremony-temp alerts; 3 review
  P0/P1 alerts (truncated spec write, lint heredoc concern,
  telemetry.db-shm tracked); 1 slow-unit (workbeat 1800 s cap); 2
  unparsable `readout.json` dash-selfreview alerts; 2 tree-skew
  dirty-tree alerts; 1 agent-stall (1967 min stale transcript); 1
  doc-suite checker false alarm (rc=1); 2 remote-posture degraded rows
  (deck unreachable); 2 daily budget digests showing overnight
  sessions=0, remote calls=0, cost $0 vs the operator's $10–20/day
  target. Every repairable class already has its fix landed in
  hngh-automation (atomic writers `760adb5`, eviction `5b79b86`,
  whitelist `1113810`, feed-regen re-read `dcb6221`, checker exemption
  via the 12:04Z progress row) — but every one of those fixes
  originated in a plan step or an operator session, never from the
  alert itself (R6's point, suite doc 08).

## 2. Lessons

1. **The plan queue is the throughput governor.** Gates, workers,
   beats, and reviews all ran green for 40h and produced nothing
   durable, because the one input they cannot synthesize — an accepted
   plan — ran out. Capacity work should target plan supply before
   execution speed.
2. **Alerts close their own loop only through plans.** The window's
   honest alerts were accurate and the fixes were real, but routing
   alert → draft plan step does not exist; the machine cannot act on
   its own observations without an operator-authored bridge.
3. **Research volume is cadence-bound, quality is grounding-bound.**
   The beat produced a crystallized line every ~65 min on cadence, but
   each line is single-model prior with no search or source capture;
   the crystallized→committed path also stalls without a ceremony
   driver in a plan.
4. **Budget sat idle.** The remote GLM leg (budgeted, key-file gated)
   recorded zero calls for two days — the token file is operator-only
   and was never placed (rows `f5929eaa`/`bed8edd3`), so the $10–20/day
   remote capacity never engaged.

## 3. Fold-back edits landed with this record

- `docs/design/autonomous-development-control.md`: the closed
  requirement-kind list was stale at 21 kinds; the validator
  (`src/domain/governance.lisp`) closes 24 — `:review` (rung 16) and
  `:remote-attestation`/`:federated-claim` (rung 11) added.
- `docs/project/roadmap.md` Now: "six fake-backed application use
  cases" corrected to seven (select-course, 2026-08-27); the frontier
  rung list stopped at rung 13 — rungs 14–18 (all landed 2026-08-25,
  already in root README and records) added.
- `docs/project/backlog.md`: the documentation-sync row gains evidence
  (the README-count guard landed as
  `tests/scripts/test-doc-numbers.py`; the roadmap rung prose drifted
  again and is corrected here); two new rows (night-agent plan
  authoring; alert→plan-candidate routing) carry the §2 lessons as
  candidate work for operator decision.
- Deliberately NOT folded back: live counts (kernel LOC, commit mix,
  cadence drop-ins, job counts) — the repo pins contracts, not day-set
  numbers; those live in the 2026-08-30 suite. Root README check
  counts were verified still true (2,855 checks, 19 verbs) and stand.
