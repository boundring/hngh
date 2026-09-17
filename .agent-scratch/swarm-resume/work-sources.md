# work-sources: upcoming-work data sources for dashboard 'upcoming work' views

Inspected 2026-09-15. Read-only inventory. Siblings: workq-rotate-shape.md
(queue.md shape, order_queue, ETA parsing), workq-staleness.md (feed staleness
tiers).

## 1. docs/project/queue.md (queue source of truth)

- Path: `docs/project/queue.md`, committed to the repo (freshness = git
  history; mutated only by `scripts/rotate-queue` queue-row-flip, atomically
  with the work commit).
- Shape: 4-field TSV, header `id<TAB>status<TAB>title<TAB>evidence`, one row
  per rotation item. Status vocabulary exactly `queued | active | done`
  (fail closed otherwise). Sample rows:
  ```
  wake-mutation-lane	done	Certificate-bound wake mutation lane	landed 2026-09-13 ...
  node-lattice-admission	queued	Node-lattice admission rung	backlog entry; README vision
  ```
  No ordering column: priority = file/insertion order. Done rows keep their
  evidence text (`rotated <date>` or a landing note).
- Extra sections: `## Next` (single bullet `- **<id>** - <why>`, parsed by
  `scripts/omp-bridge queue_next()`; currently `node-lattice-admission`) and
  `## ETA` (bullets `- <id> - <window text>`; em dash; `after <token>`
  dependency phrases; entries starting `DONE` excluded from future bars;
  last `## ETA` section wins per dashboard-readout `queue_etas()`). Sample:
  `bridge-operator-host — after node-lattice`.
- Count: ~29 rows, 11 done, rest queued; no `active` row right now.
- Consumers: dashboard-readout `queue_items` (file order; `order_queue` floats
  active rows), schedule-feed.py `oneoff_rows` (skips done, parses ETAs into
  `depends_on`), omp-bridge/plan-feed `queue_next`.

## 2. docs/project/roadmap.md (stage vocabulary)

- Path: `docs/project/roadmap.md`, committed; freshness = git + dated inline
  admissions (e.g. "ratified 2026-09-13").
- Shape: prose + one consolidated 7-stage table with columns
  `Stage | Scope | Exit criteria | State`; State vocabulary
  `done | landing | queued | later`. "Land stage 2" = stage exit criteria hold
  under the standing gates (not just code existing).
- Current states: 0 done, 1 done, 2 landing, 3 landing (absorbed former
  stage 4, number retired 2026-09-13), 5 queued, 6 queued, 7 later.
- Upcoming-work relevance: the "Now" section + stage landing states give the
  dashboard a coarse (stage-level) "what's next" signal; sequencing rules say
  stages 5/6 alternate via the Descent cycle grow/research beats.
- Sibling vocabulary: `## Next` in roadmap ("Now" bullets) is surfaced by
  `omp-bridge --orient` (roadmap Next) alongside queue_next.

## 3. docs/project/plans/*.plan.md (operational plan lifecycle, 283 files)

- Path: `docs/project/plans/<date>-<slug>.plan.md`; naming
  `YYYY-MM-DD-<slug>.plan.md` (+ `.ceremony-runbook.md` variants); also
  `README.md` (the contract) and `routed-candidate-template.md`.
- Schema: first HTML comment front-matter:
  `<!-- plan: status=proposed|accepted|executing|executed|parked
       risk=normal|critical accepted=<UTC ts or -> [priority=high]
       [routed-from=<ALERT_IDENTITY>] [cause=... disposed=...] -->`
  Steps under `## Steps` as `- [ ]` / `- [x]` checkboxes, each with an
  indented `Verification:` line. `routed-*` plans are auto-authored by
  `scripts/router-tick.py` from alert identities and carry an
  `## Occurrences` section.
- Counts (grep of status= across all .plan.md): parked 124, executed 83,
  proposed 79, accepted 5, done 2, complete 1, superseded 1. So ~87
  actionable-open (proposed+accepted) vs ~91 closed (executed+done+complete),
  124 parked. Open work is dominated by `proposed` routed candidates.
- Selection/freshness: the cycle (`overnight-cycle.sh`) executes the next
  unchecked step of the OLDEST accepted plan (priority=high sorts ahead; ties
  by filename order); proposed normal-risk plans auto-accept when
  verifications are runnable and gates are green, with the accepted timestamp
  written into front-matter. Status is machine-read back via front-matter and
  hngh-automation `dashboard/plans.json` (+ `omp-bridge --plan-status <slug>`).
  Freshness signals: `accepted=<ts>` in front-matter, checkbox states,
  disposition stamps on parked routed plans (`disposed=2026-09-15T05:00:26Z`).
- Sample (recent routed plan, 2026-09-15):
  ```
  <!-- plan: status=parked risk=normal accepted=- routed-from=slow-unit:dropin:59-unsloth-observe.sh cause=obsolete disposed=2026-09-15T05:00:26Z ... -->
  ## Steps
  - [ ] Delve: open research subject fail-20260915-... ; record disposition; then fix or park
        Verification: research subject ... present in research-subjects.txt ...
  ```

## 4. automation/cadence/ + automation/cadence-params.tsv (scheduled beats)

- `automation/cadence/` holds tier dirs: `1m 5m 10m 30m hour day week month`
  (+ README.md), each a numbered shell-step sequence. The 30m tier feeds the
  dashboard directly: `05-readout.sh` (writes readout.json, atomic tmp+mv),
  `10-system-feed.sh`, `15-schedule-feed.sh`, `25-research-feed.sh`,
  `35-plan-feed.py` (plans.json). Day tier: activity-tick, ledger-prune,
  gate-check, review-prep, plan-ledger-sync (14-plan-ledger-sync.sh), etc.
  Freshness = script mtimes + the feed files each writes, guarded by
  workq-staleness.md tiers (readout.json tier 1800s x3; patrol windows).
- `automation/cadence-params.tsv`: 4-field TSV
  `key<TAB>value<TAB>provenance<TAB>note`, one row per loop tunable
  (e.g. `heartbeat-minutes 60 cadence/hour/31-heartbeat.sh ...`), env-var
  overrides named per row. It parameterizes beat schedules (timers, caps,
  thresholds) rather than listing beat instances; the beat instances are the
  numbered files in the tier dirs. Freshness = git + dated provenance text
  in column 3.
- Upcoming-work relevance: cadence dirs answer "what runs next on the
  machine"; queue.md/ETA answers "what rotation item next"; plans/ answers
  "what accepted steps are in flight"; roadmap answers "which stage is
  landing". A dashboard upcoming-work view would join: queue_items +
  queue_etas (readout.json spine), plans.json accepted/pending, and the
  cadence tier files for scheduled beats.

## 5. Cross-source consistency notes

- All four sources are committed files: freshness is ultimately git commit
  time; the derived feeds (readout.json, plans.json) lag by the 30m cadence
  tick and carry staleness rules per workq-staleness.md.
- The designated "next" is never a field: it is `## Next` in queue.md,
  oldest-accepted-plan selection in plans/, and roadmap stage `landing`
  states.
- hist-windows-queue.md sibling was not present in .agent-scratch/swarm-resume/
  at inspection time.
