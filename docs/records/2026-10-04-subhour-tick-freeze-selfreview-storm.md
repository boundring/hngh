# Subhour tick freeze: research-overflow sleep starved the minute tier

Date: 2026-10-04. Surface: `automation/cadence/subhour/50-research-overflow.sh`,
`automation/jobs/dashboard-self-review.py`, `automation/dashboard/app.js`.

## Symptom

`dash-selfreview` filed `feed-fresh:sessions.json` / `feed-fresh:operator-items.json`
"unacceptable-now — stale NNNs > 3x tier 60s" alerts in bursts (14:00-17:00Z
storm, again at 23:54Z). The console verdict stacked every historical failing
row into `dashboard self-review failing: ...` reasons and pinned the header at
"Needs attention" for hours after the feeds recovered.

## Root cause (two independent defects)

1. **In-tick sleep froze the every-minute tier.** `50-research-overflow.sh`
   staged its second 15-minute research beat with `sleep 900` INSIDE the
   subhour tick. While it slept (half of every 30 minutes), the whole
   `hngh-cadence-subhour.service` activation stayed "activating"; systemd
   skipped every trigger, so `10-sessions-feed.sh` and `05-operator-items.sh`
   did not run and the 60s-tier feeds froze for ~15 minutes per half hour.
   The hourly `00-dashboard-self-review.sh` flagged the freeze whenever its
   sample landed in a frozen window. Same collision class as the
   2026-09-24 tier collapse (a long beat blocking the tick); that collapse
   had already halved the beat with the 1800s entry stamp, but the sleep
   stayed.
2. **Client scanned resolved history.** `app.js selfReviewAlerts()` matched
   failing rows across the FULL reports.md ledger. A failing row means
   "last observed failing at ts" — the tick only re-files while failing —
   so alerts predating recovery stayed in the verdict forever. The producer
   made this worse: clean ticks were silent BY DESIGN ("all-clear ticks are
   silent"), so no row ever marked recovery, and `add_or_bump`'s blind bump
   would have kept a stale "N findings" text alive inside the bumped
   summary row anyway (bump folds ×N but never rewrites the text).

## Fixes

- `50-research-overflow.sh`: deleted the in-tick `sleep 900` + unconditional
  second beat. A self-gate stamp is the only pacer; the tick never blocks.
- Cadence amendment (same day, post-fix): the 2026-09-24 collapse response
  had halved the beat to a 1800s stamp while the sleep still blocked the
  tick -- load triage, not a cadence target. With the sleep gone the stamp
  is non-blocking, so the entry gate moved to 900s, restoring the
  pre-collapse EFFECTIVE 15-minute cadence (:00 :15 :30 :45) that the
  sleep+second-beat had synthesized. The collapse guard whitelist grew to
  300/600/900/1800 and the equivalence baseline records this job's old
  tier as 15m (what actually fired), not the 30m systemd trigger. Quota
  pacing stays with failfirst-research-overflow (FAILFIRST_TICK_S=900).
- `dashboard-self-review.py`: every tick files the summary row
  (heartbeat). Identity is now state-keyed (`dash-selfreview:summary:<n>`)
  and the heartbeat bumps only while the stored text matches the current
  one — a state change (3 findings -> 0) files a fresh row and lets the
  old one age out, because `report-queue add()` re-bumps through its own
  identity scan and `bump_row` preserves text.
- `app.js selfReviewAlerts()`: cuts the ledger at the newest
  `summary: 0 findings` row; alerts older than that are resolved history,
  not state.

## Verification

- `tests/test-research-accel2.sh` b1 rewritten to the single-beat contract;
  new b4 pins the stamp-only pacing (fresh stamp -> no beat; backdated ->
  beat). `tests/test-cadence-collapse.sh` green (firing-equivalent).
- New `tests/test-dashboard-selfreview-heartbeat.py` (4 cases): clean tick
  files and bumps one summary row; findings row + summary coexist; state
  change re-files instead of bumping; client cut rehearsal.
- Live: after the fix the subhour tick completes in minutes instead of
  wedging 15+, `dashboard/sessions.json` / `operator-items.json` refresh
  every tick, and the next hourly self-review sample files a clean summary
  that clears the console verdict reasons on reload.

## Tier retune (same day)

Post-fix measurement: a full subhour activation takes ~3-4 minutes, so the
minute-tier feeds refresh on that cadence. The 60s tier (180s stale
threshold) tripped on healthy feeds within minutes of the freeze fix
(staleness 185s observed). `FEED_TIERS` for sessions.json /
operator-items.json retuned 60 -> 300 (docstring aligned); threshold is
now 900s against a measured ~180-240s worst-case refresh.
