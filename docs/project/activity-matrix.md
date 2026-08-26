# Activity matrix — routine project activities on the cadence

The autonomy-continuum `activity-cadence` rung (backlog, operator
directive 2026-08-26): each routine project activity is mapped to a
cadence-continuum tier, the existing artifact it advances, its smallest
increment, and what the tick does when the next increment is undefined.

No daemon, provider, watcher, scheduler, or unbounded mutation is
admitted: each tier is an operator-installed timer invoking one
single-tick script, and the tick either performs the next increment or
files a report line instead of acting (never auto-generates busywork).

The matrix is a display/ledger artifact, never an authority: it only
names increments and artifacts; every real mutation still runs through
the existing certificate gates.

## Rows

| Activity | Cadence tier | Artifact advanced | Smallest increment | Skip condition (file a report instead of acting) |
|----------|--------------|-------------------|--------------------|--------------------------------------------------|
| Roadmap review | week | roadmap.md | Appraise the `## Now` frontier + `## Next` list; append a dated "review" note naming the frontier and the highest-value next candidate | No change since last review → `roadmap-review: unchanged` report |
| Planning | week | backlog.md / queue.md | Draft one candidate item for a queued lane (smallest useful outcome + evidence + dependencies) | No open lane wants a new candidate → `planning: nothing to draft` report |
| Design | month | docs/research/ | Write one design note capturing a decision+rationale for an open design question | No open design question → `design: none open` report |
| Roadmap expansion | month | roadmap.md (scanned via queue.md) | Add one new candidate to a backlog lane with evidence | No new candidate surfaced → `expansion: nothing new` report |
| Implementation | day | active-work.md | Advance one open work lane by one observable step (edit + its test), or file the step's status | No open lane is actionable today → `implementation: nothing due` report |
| Review | day | reports.md | Run the review increment for the lane just implemented (append a review verdict row) | Nothing newly implemented → `review: nothing to review` report |
| Refactor | day | active-work.md | Complete one bounded refactor step on a named surface (or record the skipped step) | No refactor step is defined → `refactor: none scheduled` report |
| Cleanup | day | active-work.md | Remove one obsolete/dead artifact or mark one done lane complete | Nothing obsolete → `cleanup: nothing to clean` report |
| Inward comms | day | checkin.md | Append one dated inward-communication line (state, open lanes, next step) | History already updated today → `inward: already noted` report |
| Outward comms | week | queue.md / reports.md | Append or file one dated outward-communication note (market/outreach observation) | No outward signal → `outward: nothing to communicate` report |

## Tier schedule

- **day** — the `01-activity-tick.sh` drop-in under `cadence/day/`,
  driven by the `hngh-cadence-day` systemd unit (daily).
- **week** — the `01-roadmap-review.sh` drop-in under `cadence/week/`
  (weekly, Monday).
- **month** — the `01-zoom-out.sh` drop-in under `cadence/month/`
  (monthly, 1st).

## Adoptable-by-peer rows

Every row is marked **adoptable-by-peer**: a fleet peer (a
`fleet-manager --json` node) may adopt a row. Adoption is recorded as a
dated `fleet.md` line via the existing append pattern — it is
display/ledger only, never a dispatch network. A peer that adopts a row
takes over performing-or-filing its increment for its cadence window;
the owning tick then treats the row as owned and files an
`owned-by <peer>` report instead of acting.

## Fail-closed

The tick exits 0 in every expected path and files an `alert` row on a
genuine fault. When a row's smallest increment is undefined (the skip
condition), the tick files a report naming the activity instead of
inventing work.