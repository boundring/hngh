# workq-staleness: staleness rules for generated/unread counts and feed timestamps

Date: 2026-09-15. Read-only survey of the hngh automation checkout.
Siblings: workq-report-shape.md (report-queue JSON shape), rp-overview.md
(overview rendering). This artifact covers: how "stale" is defined across
the dashboard feeds, unread counts, and the badge thresholds, and what the
current live timestamps look like.

## 1. Feed mtime staleness (the canonical ts-age rule)

Two independent probes use "age of file mtime vs a tier multiple":

### dashboard-self-review (automation/jobs/dashboard-self-review.py)
- `STALE_MULT = 3` (line 46). Feed is stale when `mtime age > STALE_MULT x tier`.
- `FEED_TIERS` (lines 52-58): sessions.json 60s, operator-items.json 60s,
  time-ledger.json 300s, readout.json 1800s.
  => effective stale thresholds: sessions/operator-items >180s,
  time-ledger >900s, readout >5400s (90 min).
- Missing file = finding (`feed-fresh:<name>`), unparsable = `feed-valid`
  finding; readout.json requires spine keys `timeline`, `queue`, `verdict`.
- Verdict vocabulary: `unacceptable-now` (stale 3x, invalid feed, missing
  page marker) vs `acceptable-for-now`.
- Ledger drift guard: `LEDGER_DRIFT_MAX = 50` (|report-queue rows - body
  files|); drift downgraded to transient when repo HEAD is older than
  `LEDGER_SKEW_MAX_AGE = 7200s` (unknown age fails closed, never downgrade).

### patrol (automation/jobs/patrol.py, check_feed_freshness ~:148)
- `FEEDS = [("plans.json", 3600), ("operator-items.json", 600), ...]`
  (line 53) -- absolute stale windows, not a multiple: plans.json >1h,
  operator-items.json >10m => `feed-stale` fail with `age=Xs > Ys`.
- These windows are looser than self-review's 3x-tier for operator-items
  (600s vs 180s): patrol tolerates more than the 30m self-review tick.
- Note the intentional 2x gap for readout.json: self-review expects 30m
  tier x3 = 90min; cadence/30m/05-readout.sh header says it flags
  readout.json stale beyond 3x its own tier -- same constant, no conflict.

## 2. Browser-side staleness (automation/dashboard/app.js)

- `REFRESH_MS = 10000` (10s poll); `STALE_MS = 5*60*1000` (line 14):
  a `generated` timestamp older than 5 min => stale beacon
  (`setBeacon(false)` -> `beacon warn`; unreachable -> `beacon danger`).
- data.json fallback path (app.js:705-713): when data.json `generated`
  is >5 min old the header shows `data.json stale (>5 min) -- generated <ago>`
  in a `.stale-note`, and readout.json spine is used instead.
- Age chips (app.js:114): `s < 3600 ? 'fresh' : s < 86400 ? 'aging' : 'stale'`
  -- i.e. <1h fresh, <24h aging, >=24h stale (CSS class, informational).

## 3. Unread counts (report queue)

- Client-derived (app.js fetchQueue, ~:343-397): rows parsed from the
  ledger mirror `dashboard/reports.md` (5 pipe columns; oldest first).
  `report-cursor` holds the last-read row id; unread = rows strictly after
  the cursor in file order. Unknown cursor id fails OPEN (all rows unread),
  never silently hides rows. Header shows `N unread reports` or `all read`;
  last 10 unread rendered newest-first with per-row `mark read`
  (POST /report-queue/mark-read, token-guarded).
- No time-based staleness on unread rows themselves -- unread-ness is
  purely cursor position, not age.

## 4. Upcoming-work staleness (queue / readout)

There is no separate "upcoming work" surface; it is the readout spine:
`readout.json` = {timeline, queue, etas, sessions, roster, generated,
verdict}. Live sample (2026-09-15T09:30:09-04:00 generated): queue items
`wake-mutation-lane` (done), `node-lattice-admission`, `bridge-operator-host`,
`key-rotation-freshness` (queued) with free-text `etas` (e.g. "next
rotation", "after node-lattice") -- no per-item timestamps, so upcoming
items carry no staleness state of their own; staleness is inherited from
the readout.json file timestamp via the rules in sections 1-2:
- dashboard UI: readout/data older than 5 min => stale badge/note;
- self-review: readout.json mtime >90 min => unacceptable-now finding;
- patrol: does not watch readout.json (plans.json/operator-items/sessions
  tiers only).

## 5. Related constants worth knowing (adjacent surfaces)

- graph-view (automation/jobs/graph-data.py `_session_state`): session
  >10 min without activity => state `stale`; legs: age >2h => stale.
- resume-pass.sh:151: open operator items with `first_seen` >48h counted
  as "stale".
- oversight-tick.sh: ceremony `record.lisp` untouched 30min+ => `stale-store`
  alert (86400s dedup window).
- patrol gate crumbs: no crumb in 26h => `gate-stale`.

## 6. Current live state (checked 2026-09-15T13:55Z)

- report-queue --json `generated` 2026-09-15T13:55:30Z, newest row
  13:50:01Z (fresh, ~5 min old).
- readout.json generated 2026-09-15T09:30:09-04:00 (~13:30Z), within the
  90-min self-review window; the readout tier producer fires on the 30m
  cadence.
- config-backup progress rows recur every 30 min; router dedup alerts use
  a 1h "still live" suppression with day counts.

## 7. Rule summary (proposed canonical statement)

A feed/panel is STALE when: (a) file feed mtime age > STALE_MULT(3) x its
cadence tier (self-review, server-side, finding-generating); or (b) served
`generated` timestamp age > 5 min (browser badge, cosmetic); or (c) patrol's
per-feed absolute window exceeded (plans 1h, operator-items 10m, sessions
per FEEDS). Unread counts never expire by time -- they advance only via the
reading cursor and fail open to all-unread on unknown cursor. Upcoming-work
items (readout queue) inherit staleness only from their producer file; a
per-item `queued-at` ts plus a tier-based badge would be the natural
extension if per-item staleness is wanted.
