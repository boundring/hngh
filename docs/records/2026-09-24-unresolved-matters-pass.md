# Unresolved matters pass: router bound, lane wiring, operator calls settled

Date: 2026-09-24 (landed 2026-09-25). Tier: automation free lane + docs.
Plan: unresolved-matters-pass (operator-approved 2026-09-24).

## The operator ask

Work the approved unresolved-matters-pass plan to landing: bind the
router, wire the lane residue (counter seam, cadence tiers, write-only
readers), settle the C-group calls, and land the whole pass as named
commits after the full automation gate is green. Mid-pass the operator
narrowed one session to "fix ONLY the research-review regression, then
halt" (honored; the regression fix landed with this pass).

## Router (A)

- A1/A3 (bound re-routes, router-bound pin) landed earlier in the pass:
  `automation/scripts/router-tick.py` enforces `HNGH_ROUTER_REROUTE_MAX`
  (default 3) and the router-bound park; pins live in
  `automation/tests/test-router-feed.py` / `test-router-tick.py`.
- A2 sweep routed residue: of 36 `2026-09-24-routed-*.plan.md` files,
  21 carry `cause=obsolete` (every non-newest chain member) and the 15
  newests stay accepted. Verified per chain
  (tree-skew-hngh, patrol-journal-error, overnight-plan-accept-gate,
  slow-unit-dropin, patrol-services).

## Lanes (B)

- B1 prior-adopted wire: the research beat's REVIEW prompts carry prior
  adopted dispositions (`automation/cadence/hour/33-research-beat.sh`).
- B2 counter seam: `automation/scripts/typed-challenges.py` runs a
  SECOND batched `ask_nouls` disconfirming-question batch; counter rows
  ride at p >= 0.7, capped at 20 total, principle column keeps the
  matrix name. Pinned by the new
  `automation/tests/test-typed-challenges.py` (monkeypatched
  `ask_nouls`; hermetic).
- B3 cadence collapse: tiers are now subhour|hour|calendar (3 tiers).
  `automation/jobs/cadence-tick.sh` picks calendar subdirs by firing
  instant (daily 05:00, weekly Mon 06:00, monthly 1st 06:00). The
  minute-simulation pin `automation/tests/test-cadence-collapse.sh`
  proves firing-equivalence for all 65 jobs across 8 old timers -> 3
  before the swap; then `make disable && make enable` was run and
  `systemctl --user list-timers 'hngh-cadence*'` shows exactly 3
  (subhour/hour/calendar; the 7 orphaned old-generation timers were
  disabled explicitly — the Makefile only knows the new names). Stale
  `cadence/day|1m|...` paths updated across tests
  (test-model-pin-routing, test-curator-beat, test-cap-block,
  test-email-dismiss-durability, test-breadcrumb-single-line) and docs
  (docs/getting-started.md).
- B4 write-only readers: torch ledger rows flipped live (digest-BENCH,
  digest-RESEARCH, email-qa.log), `email_qa_trend()` consumer in
  `automation/scripts/email-digest.py`, night-brief wired into both
  REVIEW prompts. Audit
  (`automation/cadence/calendar/daily/17-torch-audit.sh`) verifies
  18 live / 0 write-only / 0 unknown / 0 diverging rows; the
  STATE-OF-PROJECT verified block regenerated inside its sentinels and
  the hand narrative was truth-checked (audit path refs updated to the
  calendar tier).

### The review regression (found mid-pass, fixed)

Adding the night-brief text introduced `today's` — an apostrophe —
inside a `${night_brief:+...}` word in `33-research-beat.sh`. An
apostrophe is a syntactic quote opener for bash even nested in outer
double quotes; the stray span swallowed ~44 lines, so `supportive=` and
`opp_prompt=` never ran and the adversarial call fired on an empty
prompt (review-unparseable alert, no disposition). Fix: rephrase both
section headers without apostrophes. Whole-file `bash -n` passes when
the span closes downstream — quote-counting cannot see this class;
the failing tests did.

## Calls (C/D)

- C1 gitignore consolidation: `automation/.gitignore` ignores
  `dashboard/` with an explicit `!dashboard/<file>` whitelist; verified
  both directions with `git check-ignore` (whitelisted files clean,
  runtime JSON ignored).
- C2 gh OAuth scope (`gh auth refresh -s user`): PARKED with cause
  "auth flow needs the operator at the browser" (device-code flow
  timed out awaiting the operator; no loop).
- C3 nudgeGrowthTokens: NO CHANGE — settled at 250000.
- C4 bili: PARKED at operator call.
- D1 crumbs reader flip: stays BLOCKED. (a) Subject line
  `fail-20260924-crumbs-mirror-rows` appended to
  `automation/research-subjects.txt`. (b) The flip SLA recorded in the
  report queue (row `876900b4`, identity `crumbs-mirror:rows`):
  auto-park the flip with cause "parity unmet" if no clean parity day
  by 2026-10-01; halt: if the mismatch deficit grows past 3, file a
  report row and stop the writer side instead of waiting for parity.
  Fresh verify at recording time: verdict=ok (deficit closed
  transiently). (c) NO flip.

## Landing

Full `cd automation && make test` green, then four phase commits after
the machine ledger sync: router bound + residue sweep; lane wiring
(prior dispositions, counter seam, cadence tiers, write-only readers);
gitignore + research-subject line; this record + CHANGELOG.
