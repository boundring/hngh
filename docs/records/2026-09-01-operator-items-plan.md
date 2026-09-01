# Operator items plan — 2026-09-01

Status: RECORD. Evidence cited per claim; admits no runtime capability.

Scope: the operator's 2026-09-01 direction (six items, restated
faithfully below), its encoding as the queued plan
docs/project/plans/2026-09-01-operator-items.plan.md, and the
avoid-duplication check against the routed plans already queued that
day.

## 1. Operator direction (2026-09-01, recorded faithfully)

1. **Push-on-demand.** Hngh must push commits to remote whenever
   appropriate, not operator-gated. (Being implemented in
   hngh-automation 2026-09-01; see §3.)
2. **Delegated-session costs.** Optimize and limit via further
   iterative research into the roguelike development pattern — cheap
   sessions, death-and-replacement, handoff briefs;
   local-model-first selection with paid fallback, benchmark-gated.
3. **Continuous local-model research.** Benchmarking and optimizing
   practical techniques for Hngh's own development, on cadence.
4. **Procedural email reports to the operator** (progress + research
   digests; alerts immediately), replacing token-costly browser-based
   Google-Messages notifications; OSS prior art (ntfy, Apprise)
   welcome as future channels.
5. **Budget target <$10/day**, and Hngh becoming self-funding
   (publications pipeline: scripts/generate-publication --ebook/--site
   consuming crystallized docs/research/; backlog rows ebook-longform,
   public-surface, royalty-pipeline, funding-rails).
6. **Long-run.** Hngh schedules and optimizes scheduling for
   relatively arbitrary requests, queueing and completing them
   immediately or on an appropriate cycle; and a long-term
   biographic/documentary pipeline where Hngh maintains notes and
   records for operator writing about Hngh's development.

## 2. The plan

docs/project/plans/2026-09-01-operator-items.plan.md was authored
2026-09-01 ~19:45Z: status=proposed risk=normal accepted=-, nine steps
under strict grow↔research alternation (grow beats at steps 1, 3, 5,
7, 9; research beats at steps 2, 4, 6, 8), each step carrying an
indented Verification line per the plans README contract. Normal-risk
autonomous work pre-authorized; critical-class work (credential/
provider configuration, systemd lifecycle, kernel src/) parks. The
plan queues behind the routed plans already accepted that day — the
cycle executes the oldest accepted plan's next unchecked step; jumping
the queue is not attempted.

## 3. What was and was not visible at authoring time (~19:45Z)

- Kernel HEAD was 6cbdc9c; the working tree carried the machine's
  owned dirty paths (docs/journal/2026-08-31.md, docs/project/
  reports.md, ui-grades, current-overlay.json, queue.md) and eight
  untracked routed plan files — all machine-owned, untouched by the
  plan's authoring.
- The 2026-09-01 connectivity slice and notify-email slice were NOT
  yet visible: hngh-automation CHANGELOG.md's newest entry is dated
  2026-08-31 (machine plan acceptance, plan-feed fixes), `git remote
  -v` in hngh-automation is empty, and scripts/notify-email.py does
  not exist there. The plan's steps 1 and 3 verify-on-arrival and park
  with an alert row if the slices still have not landed when they
  execute.
- Present and grounded: hngh-automation jobs/session-cost.py (one
  telemetry row per finished omp session, kind=session-cost),
  jobs/model-bench.sh (three deterministic probes, python judge, one
  JSON line per model per day in stats/model-bench-<date>.jsonl),
  logs/budget.md, hngh scripts/generate-publication (HNGH_PUB_ROOT
  seam; --ebook reads a hard-coded 7-file list per the backlog
  publication-lines-contract row).

## 4. Avoid-duplication evidence

Eight routed plan files dated 2026-09-01 were on disk at authoring
time (front-matter statuses as read): dash-selfreview feed-fresh /
feed-valid / summary (accepted 2026-09-01T12:01:27Z), overnight
plan-accept-gate kernel (12:01:27Z), review P1 truncated execution
note (12:01:27Z), slow-unit dropin:20-workbeat.sh (accepted 02:01:23Z,
executed — false positive fixed at hngh-automation 7caff48), ui-audit
name-completeness (02:01:23Z), tree-skew hngh (accepted
2026-09-01T19:01:23Z). All are alert-fix one-steppers routed by
scripts/router-tick.py; none covers any of the six operator
directives, so the operator-items plan duplicates none of them.

## Sources

- docs/project/plans/README.md (the plan contract).
- The eight 2026-09-01 routed plan files on disk (front-matter read
  2026-09-01 ~19:45Z).
- hngh-automation: CHANGELOG.md (newest entry 2026-08-31), `git remote
  -v` (empty), jobs/session-cost.py, jobs/model-bench.sh, logs/budget.md.
- hngh: scripts/generate-publication, docs/project/roadmap.md,
  docs/project/backlog.md, docs/project/queue.md,
  docs/project/master-plan.md §4, docs/project/roguelike-agentic.md,
  docs/research/2026-08-30-delegation-lane-parallelism-*.md,
  docs/research/2026-08-30-publication-pipeline-grounding.md,
  docs/records/2026-08-31-continuous-cycle-fix.md §2.
