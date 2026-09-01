<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-01 — operator items: push-on-demand, email reports, cost discipline, local-model research, self-funding, scheduling

Authorization: operator-directed 2026-09-01, recorded faithfully in
docs/records/2026-09-01-operator-items-plan.md — (1) push-on-demand
(Hngh pushes commits to remote whenever appropriate, not
operator-gated); (2) delegated-session cost optimization via iterative
research into the roguelike development pattern (cheap sessions,
death-and-replacement, handoff briefs; local-model-first selection with
paid fallback, benchmark-gated); (3) continuous local-model research —
benchmarking and optimizing practical techniques for Hngh's own
development, on cadence; (4) procedural email reports to the operator
(progress + research digests; alerts immediately), replacing
token-costly browser-based Google-Messages notifications, OSS prior art
(ntfy, Apprise) welcome as future channels; (5) budget target <$10/day
and Hngh becoming self-funding via the publications pipeline
(scripts/generate-publication --ebook/--site consuming crystallized
docs/research/; backlog rows ebook-longform, public-surface,
royalty-pipeline, funding-rails); (6) long-run — Hngh schedules and
optimizes scheduling for relatively arbitrary requests, queueing and
completing them immediately or on an appropriate cycle, and a long-term
biographic/documentary pipeline where Hngh maintains notes and records
for operator writing about Hngh's development. Normal-risk autonomous
work is pre-authorized; critical-class work parks with operator-facing
alerts.

Sources: docs/project/plans/README.md (the contract this file obeys);
the 2026-08-30 evening-selfdev and 2026-08-31 overnight-continuity
plans (pattern: header authorization, sources, autonomy rule, paced
cadence, parked section); the 2026-09-01 routed plans on disk
(avoid-duplication evidence, enumerated below); docs/project/roadmap.md
(stage table, Next, the self-funding design-pressure paragraph);
docs/project/backlog.md rows publication-lines-contract,
ebook-book-inputs, ebook-longform, royalty-pipeline, funding-rails,
cadence-continuum, activity-cadence; docs/project/queue.md (rotation
state, queued→active→done via scripts/rotate-queue);
docs/project/master-plan.md §4 (grow↔research alternation, research
emits scoped parseable materials, never code);
docs/project/roguelike-agentic.md (death-and-replacement, handoff
briefs, steer-vs-die); docs/research/
2026-08-30-delegation-lane-parallelism-multi-lane-omp-bridge-sessions-and-queueing.md
(minimal DelegationQueue line; the overnight cycle as the single-lane
consumer); docs/research/2026-08-30-publication-pipeline-grounding.md
(15/15 grounding paths verified); hngh-automation jobs/session-cost.py,
jobs/model-bench.sh, logs/budget.md (read at authoring time);
scripts/generate-publication (HNGH_PUB_ROOT seam, --ebook/--site);
docs/records/2026-08-31-continuous-cycle-fix.md (§2 operator direction,
the continuous-cycle law); the operator explainer suite
~/Projects/etc/20260830 (exemplar format only; its numbers are not
imported).

Grounding notes (evidence over brief, checked at authoring time
2026-09-01 ~19:45Z):
- The 2026-09-01 connectivity slice (push-on-demand: remote creation,
  origin wiring, sweep push) and the notify-email slice were NOT yet
  visible to the author: hngh-automation CHANGELOG.md's newest entry is
  dated 2026-08-31, `git remote -v` in hngh-automation is empty, and
  scripts/notify-email.py does not exist there yet. Steps 1 and 3 are
  written to verify-on-arrival and park with an alert row if the slice
  still has not landed when they execute.
- Today's routed plans on disk (8 files, statuses as their front-matter
  reads): dash-selfreview feed-fresh + feed-valid + summary (accepted
  12:01Z), overnight:plan-accept-gate:kernel (accepted 12:01Z),
  review:hngh:P1 truncated execution note (accepted 12:01Z),
  slow-unit:dropin:20-workbeat.sh (accepted 02:01Z, executed — false
  positive fixed in hngh-automation 7caff48), ui-audit:name-completeness
  (accepted 02:01Z), tree-skew:hngh (accepted 19:01Z). All are
  alert-fix one-steppers; none covers any of the six operator
  directives. No step below duplicates them.
- scripts/generate-publication --ebook reads a hard-coded 7-file list
  and consumes no docs/research/ lines (backlog publication-lines-
  contract row; the 2026-08-30 publication grounding doc). Step 5
  verifies that finding live and records the gap; it does NOT wire
  research-lines — that decision belongs to the queued backlog row.
- jobs/model-bench.sh appends one JSON line per model to
  stats/model-bench-<date>.jsonl (three deterministic probes, python
  judge, reloads the primary model warm at end); jobs/session-cost.py
  emits one telemetry row per finished omp session
  (kind=session-cost, token/cost fields possibly null). Step 6 grounds
  in those formats as they exist on disk; claims beyond them stay
  "not established".

Autonomy rule (standing): hngh docs changes land via certificate
ceremony with a green `make test`; hngh kernel src/, tests/, Makefile,
hngh.asd changes are FORBIDDEN to machine sessions — park them with an
alert row instead. hngh-automation script work lands as plain commits
gated by hngh-automation `make test`. Never touch provider or
credential configuration, systemd unit lifecycle beyond an
already-installed unit, tracked deletions outside the 48h prune, or
secrets. Machine-owned dirty paths (docs/journal/ current day,
docs/project/reports.md, docs/project/ui-grades.md,
docs/design/ui-evolve/current-overlay.json, .omp/, untracked routed
plans and untracked research docs) are never ceremony candidates for a
plan step — the machine's own steps land those.

Paced-cadence contract: beats are bounded at ≤ ~60m wall each; strict
grow↔research alternation per master-plan §4 (a grow beat may not
follow a grow beat, a research beat never writes code); every step
names its own verification and is executable by a bounded delegated
session with no human present; this plan must not run empty — the
parked section names follow-on candidates and step 9 authors the next
plan so the queue stays fed (foldback lesson 1).

## Steps

- [ ] 1. GROW — push-on-demand verification slice. Check hngh-automation
      for the connectivity slice's arrival (its CHANGELOG's newest
      entry, `git remote -v`, origin wiring). If a remote exists,
      exercise push-on-demand: after the next plain hngh-automation
      commit (or the sweep), verify the push landed
      (`git status -sb` / `git branch -vv` shows the branch up to date
      with origin). If the remote still does not exist, file an alert
      row via scripts/report-queue naming the missing slice with the
      observed evidence, and park.
      Verification: a push from hngh-automation to its origin observed
      up to date, OR an alert row documenting the slice's absence
      (CHANGELOG newest entry date + empty `git remote -v` quoted);
      hngh-automation `make test` green.
- [ ] 2. RESEARCH — notification-channel survey. Compare candidate
      channels for operator reports: email (SMTP; the notify-email
      slice being landed 2026-09-01 — cite it when visible, mark "not
      established" until then), ntfy.sh hosted topics (curl POST, no
      daemon), Apprise CLI. Score each on token cost, latency, privacy
      (what leaves the machine), and operator reachability; ground the
      baseline in the browser-relay notification history in docs/
      records/ (browser-based Google-Messages notifications were
      token-costly) and in ntfy/Apprise OSS documentation. Conclude
      with one named next-channel recommendation as a priced,
      parseable decision; "not established" framing wherever the
      evidence is thin.
      Verification: docs/research/2026-09-01-notification-channel-survey.md
      exists with a per-channel cost/latency/privacy table, explicit
      "not established" markers where unverified, and a one-line
      recommendation; kernel `make test` green.
- [ ] 3. GROW — email digest wiring check + first live digest. If the
      notify-email slice has landed: run the digest composer in report
      mode (no send), verify its content against named sources
      (docs/project/queue.md rotation rows, docs/project/reports.md
      alert rows, dashboard/plans.json plan states), then send one
      live digest if the mail configuration is present. If the slice
      has not landed, file an alert row naming its absence and park.
      Verification: report-mode output spot-checked against ≥3 named
      source rows, plus either one live digest sent or the
      missing-slice/missing-config condition recorded in an alert row;
      hngh-automation `make test` green.
- [ ] 4. RESEARCH — delegated-session cost model + roguelike budget
      rule. From hngh-automation jobs/session-cost.py telemetry rows
      (cost_usd per session, by model) and logs/budget.md, quantify
      the current per-session cost distribution; propose the roguelike
      budget rule per the operator's directive: local-model-first
      selection with paid fallback (benchmark-gated, tied to step 6's
      design), MAX_SESSIONS_DAY tuning, death-and-replacement instead
      of steering dead sessions (docs/project/roguelike-agentic.md).
      Test the rule's arithmetic against the <$10/day target.
      Verification: docs/research/2026-09-01-session-cost-model.md
      exists citing concrete telemetry rows (dates, session
      identities, cost_usd) and states a budget rule whose stated
      arithmetic sums under $10/day; kernel `make test` green.
- [ ] 5. GROW — publication pipeline first artifact. Read scripts/
      generate-publication, then run its --ebook mode with HNGH_PUB_ROOT
      pointed at a throwaway temp directory (build artifacts are never
      committed). Record what the pipeline actually consumed (expected
      per the grounding notes: the hard-coded 7-file list, no
      docs/research/ lines) and what the ebook-longform /
      ebook-book-inputs backlog rows need next (the book-machine
      inputs: manuscript/outline/metadata set).
      Verification: an --ebook run completed into the temp dir with
      its output inventory recorded (or the failure captured verbatim
      as the finding); the next-needed-inputs note landed in a record
      or research doc; `git status` shows no committed publication
      artifacts; kernel `make test` green.
- [ ] 6. RESEARCH — continuous local-model benchmark loop design.
      Design the standing loop per the operator's directive: what to
      measure (probe pass rate over model-bench's three probes,
      tokens/s, task completion on plan steps), which cadence-continuum
      tier it runs on, and the thresholds at which the delegated lane
      goes local-first versus paying for a remote model. Ground in
      jobs/model-bench.sh's actual probe/judge code and
      stats/model-bench-<date>.jsonl line format, and the local model
      server surface (:11434) as cited in prior records; claims beyond
      what is on disk stay "not established".
      Verification: docs/research/2026-09-01-local-model-benchmark-loop.md
      exists with named metrics, one cadence tier, and concrete
      adopt-thresholds each tied to a cited jsonl field or record;
      kernel `make test` green.
- [ ] 7. GROW — first daily biographic capture row. Bootstrap directive
      6's documentary pipeline: author
      docs/records/2026-09-01-biographic-capture.md exercising the
      docs/records/README.md format and the operator suite's exemplar
      structure (~/Projects/etc/20260830), capturing today's
      development narrative with sources (the eight routed plans, this
      plan's authoring, the connectivity/notify-email slices as
      observed); record the cadence decision (a daily biographic
      capture row lands in docs/records/; docs/journal/ stays
      machine-owned and is cited, not rewritten).
      Verification: the record exists with Status: RECORD, every claim
      cites a source, it admits no runtime capability, and it does not
      modify docs/journal/; kernel `make test` green.
- [ ] 8. RESEARCH — arbitrary-request scheduling design. Design how an
      operator, an alert, or a plan files a "request" that the
      continuous queue picks up immediately or on a named cycle:
      map intake onto the queue.md rotation (scripts/rotate-queue,
      queued→active→done), the plans contract (a request that is a
      plan file is auto-accepted and executed per README), the
      cadence-continuum tiers (cadence-continuum and activity-cadence
      backlog rows), and the minimal-DelegationQueue line from
      docs/research/2026-08-30-delegation-lane-parallelism-*.md (the
      overnight cycle is the single-lane consumer). Docs only; the
      kernel/automation boundary follows the autonomy rule.
      Verification:
      docs/research/2026-09-01-arbitrary-request-scheduling.md exists
      covering intake surfaces (operator/alert/plan), the
      immediate-vs-cycled execution mapping, and the named boundary;
      kernel `make test` green.
- [ ] 9. GROW — wrap, lessons, author-next-plan (the plan-supply law).
      Land this plan's lessons into the foldback/lessons path, and
      author the next plan file (docs/project/plans/<date>-<slug>.
      plan.md, status=proposed) whose steps cover the parked
      follow-ons below and the newest executed evidence, so the queue
      never runs empty.
      Verification: the next plan file exists with contract-valid
      front-matter (first line `<!-- plan: status=proposed risk=normal
      accepted=- -->`) and every unchecked step carrying an indented
      Verification line; kernel `make test` green.

Parked (not in this plan, recorded for the operator; follow-on
candidates for the next plan's author):
- A model-bench live run as its own grow beat with a cost comparison
  against session-cost telemetry (step 6 designs it; executing it is a
  separate grow beat).
- The research-lines wiring decision for generate-publication
  (backlog publication-lines-contract row, queued — its decision, not
  this plan's).
- SMTP/ntfy credential and provider configuration, systemd unit
  changes, and any paid-fallback model-route token wiring —
  critical-class, parks with alerts.
- Kernel-side DelegationQueue internals (hngh src/tests/Makefile/
  hngh.asd) — forbidden by the autonomy rule; parks with alert rows.
