# Queue Dependency Inventory — 2026-09-09

**Accepted plans audited:** 22. Skipped: none — every `docs/project/plans/*.plan.md` whose front-matter first line contains `status=accepted` was processed. Plans with no unchecked steps (fully executed) were excluded from the "unchecked" count but remain in the dependency analysis.

## Table: Accepted Plans

| # | Slug (filename) | Steps | Unchecked | Risk | Accepted (UTC) | Touches (key scripts/files) | Declared Deps | Overlap Group |
|---|---|---|---|---|---|---|---|---|
| 1 | 2026-09-03-staging | 7 | 6 | normal | 2026-09-03T15:01:24Z | `jobs/model-bench.sh`, `scripts/generate-publication`, roadmap, backlog, docs/research/ | Depends on operator install (playwright+chromium/op); feeds model-demotion via stall-recovery S1 | model-demotion; publication-pipeline; operator-blocked |
| 2 | 2026-09-05-routed-supervision-replace-park-transcript-stalls | 1 | 1 | normal | 2026-09-06T01:01:30Z | `jobs/agent-supervision.py` (replace_stalled_bridge_run) | Reference: omp-impl-phase3-9d5ab9, transcript-stall fix 2026-09-04 | agent-supervision |
| 3 | 2026-09-06-routed-system-network-down | 1 | 1 | normal | 2026-09-06T14:01:17Z | Critical resource flag | — | infrastructure-alert |
| 4 | 2026-09-06-routed-tree-skew-hngh-2 | 1 | 1 | normal | 2026-09-06T14:01:17Z | Dirty tree whitelist, stalled edit handoff/commit | — | tree-skew; git-ops |
| 5 | 2026-09-06-worker-transport-wiring | 3 | 3 | normal | 2026-09-07T01:01:21Z | `src/main.lisp` (parse-worker-config, dispatch-run-worker), `tests/adapter/test-worker.lisp`, dogfood ceremony | Needs `dispatch-run-worker` injection point (rung 18); serves wake-mutation-lane recon | kernel-cl-change; worker-transport |
| 6 | 2026-09-08-operator-unblocks | 3 | 2 | normal | 2026-09-08T08:01:31Z | docs/records/2026-09-08-queue-drain-verification.md, smtp config | Completes 2026-09-03-capabilities S8/S9; unblocks 2026-09-03-staging all 7 steps | operator-unblock; capabilities-completion |
| 7 | 2026-09-09-automation-schedule-optimization | 5 | 4 | normal | 2026-09-09T06:01:51Z | `automation/scripts/overnight-cycle.sh`, `docs/project/plans/README.md`, `automation/dashboard/plans.json`, `accept-plans.py` | S3 depends on S2 landing; flags `priority=high` on omp-hngh-integration plan; unblocks omp-hngh-integration throughput | selector-priority; schedule-optimization |
| 8 | 2026-09-09-omp-hngh-integration | 11 | 11 | normal | 2026-09-09T15:01:13Z | `automation/mcp/hngh_mcp_server.py`, `.omp/mcp.json`, `scripts/omp-bridge`, `~/.omp/plugins/`, `.omp/skills/`, `~/.omp/agents/`, `~/.omp/rules/`, `dashboard/plans.json`, `CHANGELOG.md` | Operator-prioritized; S2 depends on S2 selector landing; depends on stalling recovery S1/S3 for throughput | omp-integration; mcp-plugin; dashboard-ui |
| 9 | 2026-09-09-overnight-continuity | 5 | 5 | normal | 2026-09-08T02:31:32Z | `scripts/generate-publication`, `scripts/ceremony-drive`, `docs/research/`, lessons/journal, queue/backlog, plans/README | Authoring follow-on plans to prevent empty queue | nightly-cycle; publication-pipeline; research-crystallize |
| 10 | 2026-09-09-presentation-pass-1 | 5 | 5 | normal | 2026-09-09T20:01:16Z | README, docs/README, docs/publication/book.md, EPUB, `scripts/generate-publication`, CHANGELOG, docs/design/presentation-direction.md | References docs/design/presentation-direction.md as arbiter | docs-polish; publication-pipeline |
| 11 | 2026-09-09-routed-agent-stall-omp-*f66646* | 1 | 1 | normal | 2026-09-09T20:01:16Z | Supervision state, handoff brief, replacement session spawn | Re-occurred 2026-09-09T18:00Z (dedup expired) | agent-stall |
| 12 | 2026-09-09-routed-dash-selfreview-ledger-sanity | 1 | 1 | normal | 2026-09-09T20:01:16Z | Docs automation self-review findings, ledger reconciliation | Dashboard self-review finding | dashboard-self-review |
| 13 | 2026-09-09-routed-dash-selfreview-summary | 1 | 1 | normal | 2026-09-09T20:01:16Z | Docs automation self-review summary alert | Dashboard self-review finding (sibling of #12) | dashboard-self-review |
| 14 | 2026-09-09-routed-overnight-bridge-refused-*action-reduction* | 1 | 1 | normal | 2026-09-09T01:01:49Z | Bridge run conflict (record-conflict labels) | Overnight bridge conflict on predecessor plan | bridge-refused |
| 15 | 2026-09-09-routed-overnight-bridge-refused-*impl-phase1* | 1 | 1 | normal | 2026-09-09T01:01:49Z | Bridge run conflict (record-conflict labels) | Overnight bridge conflict on predecessor plan | bridge-refused |
| 16 | 2026-09-09-routed-overnight-bridge-refused-*2026-08-31* | 1 | 1 | normal | 2026-09-09T20:01:16Z | Bridge run conflict (record-conflict labels) | Overnight bridge conflict on predecessor plan | bridge-refused |
| 17 | 2026-09-09-routed-slow-unit-dropin-33-research-beat.sh | 1 | 1 | normal | 2026-09-09T01:01:49Z | Research subjects indexing, slow-unit disposition | Alert: wall=28.3s median=0.1s ×9 | slow-unit; research-beat |
| 18 | 2026-09-09-routed-wake-mutation-lane-src-mutation | 1 | 1 | normal | 2026-09-09T20:01:16Z | Wake-mutation-lane boundary proposal, src mutation park alert | Certified boundary from 2026-09-03-staging S1 | wake-mutation |
| 19 | 2026-09-09-stall-recovery-and-operator-surfaces | 11 | 11 | normal | 2026-09-09T15:01:13Z | `automation/lib/launch-session.sh`, `failfirst` state, `scripts/notify-email.py`, `automation/lib/notify.sh`, `automation/dashboard/*.js`, `dashboard-server.py`, `overnight-cycle.sh`, `lib/model.sh`, `cadence/` probes, notify config | S3 blocks omp-hngh-integration and automation-schedule-optimization throughput; S10 shares demotion counter with S1; S9 wires quota models used by S1 | model-demotion; notification; lifecycle; operator-surfaces |
| 20 | 2026-09-09-work-graph-visualization | 4 | 4 | normal | 2026-09-09T20:45:18Z | `automation/jobs/plan-feed.py`, `dashboard/plans.json`, gantt.html, story view, CHANGELOG | Depends on plan-feed.py emitting edges into plans.json; consumes plans.json for gantt/story | dashboard-viz |
## Merge Candidates

Plans where scope overlaps or duplicates — same objective touched by multiple slugs.

### 1. Publication Pipeline (plans #1, #9, #10)
Three plans independently operate on `scripts/generate-publication` output:

- **staging S5**: `--site` run against throwaway temp dir, gap inventory vs research lines
- **overnight-continuity S2**: per-book metadata input (title/author/identifier/keywords), prove with real `generate-publication --ebook` run
- **presentation-pass-1 S4**: extend ebook mode to include 2026-09-09 records and presentation direction doc in spine, regenerate book.md + EPUB

**Overlapping step text:**
  - staging S5: "Run scripts/generate-publication --site with HNGH_PUB_ROOT pointed at a throwaway temp directory"
  - overnight-continuity S2: "prove with a real `generate-publication --ebook` run showing the input honored (run it, capture the OPF/NCX lines in the tick)"
  - presentation-pass-1 S4: "Extend scripts/generate-publication's ebook mode to include the 2026-09-09 records"

**Proposal:** Merge S5 (staging) + S2 (overnight-continuity) + S4 (presentation-pass-1) into one publication-pipeline run that validates both modes (`--site` + `--ebook`) and includes new records. Staging already has the gap inventory; overnight adds the metadata input proof; presentation adds record inclusion. Three separate ceremonies for essentially the same file could become one batched ceremony.

### 2. Dashboard Self-Review (plans #12, #13)
Both are single-step routed candidates from `dash-selfreview:*` alerts (#12 = ledger-sanity, #13 = summary). Same template:
```
- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
```
These two should be merged into one dashboard-selfreview plan covering all findings, since the fix is the same operation (reconcile/prune ledger rows) and the verification is identical.

### 3. Bridge-Refused Repetition (plans #14, #15, #16)
Three nearly-identical plans: each has exactly one step ("Stop the stalled session, write a handoff brief... start the replacement") and differs only in which predecessor plan couldn't open a bridge run. The underlying issue is a systemic bridge conflict (record-conflict labels), not three independent defects. These three should merge into one bridge-refusal recovery plan with three resolution entries.

### 4. Agent-Stall Recovery (plans #2, #11, #17)
- **#2** (supervision-replace-park-transcript-stalls): fix auto die+replace for transcript sessions, operator should die+replace manually or re-provision via bridge ×2
- **#11** (agent-stall-omp-f66646): stop stalled session, write handoff brief, start replacement
- **#17** (slow-unit-dropin-33-research-beat.sh): delve research subject, record disposition, fix/park

All handle agent/session stalls but at different layers: supervision policy (#2), session handoff (#11), performance alert (#17). They share the same operational pattern ("stop session → brief → replace/research") and could benefit from a shared automation script instead of one-off investigation per alert.

### 5. Operator Surfaces / Wake-Mutation (plans #5, #18)
- **worker-transport-wiring S3**: "Recon run against the mounted wake-mutation-lane lane card"
- **wake-mutation-lane-src-mutation**: "Delve: open research subject fail-... for wake-mutation-lane:src-mutation; record disposition; then fix or park"

Two plans touching the wake-mutation-lane boundary. The worker transport is the mechanism enabling wake-mutation recon; the wake-mutation plan is what happens after recon finds something actionable. These have a natural dependency order (#5 → #18) but overlap in objective (making wake-mutation work end-to-end).


## Simplification Candidates (Tech Debt)

Duplicated machinery noticed while reading the accepted plans.

### 1. Verify boilerplate — `make test green` on every step
Every single unchecked step across all 22 plans ends with its own `Verification:` paragraph that almost always includes "`make test` green". This is copied verbatim ~50+ times. **Proposal:** Extract a standard verification contract into `docs/project/plans/README.md` with one-line per-step verifications referencing the contract. Steps should read: "Verification: see plans/README contract; kernel `make test` green." Only steps with unique non-standard checks need full verification text. Reduces repetition by ~80%.

### 2. Autonomy rule copy-paste
Plans #1, #5, #6, #9, #19 each contain an "Autonomy rule" or "Governance" section with nearly identical content about certificate ceremony, kernel src/ forbidden, systemd/secrets boundaries. **Proposal:** One reference paragraph in `docs/project/plans/README.md`: "Autonomy: hngh docs land via certificate ceremony with green `make test`; kernel src/tests/Makefile/hngh.asd are FORBIDDEN to machine sessions — park them. Never touch provider/credential config, systemd unit state beyond installed units, tracked deletions outside the 48h prune, or secrets. hngh-automation commits are free once `make test` exits 0." Plans cite this instead of repeating it.

### 3. Overnight continuity template repetition
The `overnight-continuity.plan.md` pattern (gate baseline → grow beat → research beat → batched ceremony → wrap+author-next-plan) repeats verbatim across dated files from 2026-08-28 through 2026-09-09. Each is a distinct file but with the same 5-step skeleton. **Proposal:** One parameterized overnight-continuity plan with a single variable: the current research line being worked. The selector picks which line to work on each day rather than maintaining 20+ near-duplicate plan files.

### 4. Routed plan stub template
Nearly every routed candidate (#2–#4, #11–#18) follows the identical pattern:
```
## Steps
- [ ] <Task description>
      Verification: `make test` green in the owning repo
```
**Proposal:** A plan template file (`docs/project/plans/routed-candidate-template.md`) that automated routing fills in with alert text, routed-from identity, and one concrete step derived from the alert investigation output. Currently each routed plan is handwritten despite having only 1 line of variable content.

### 5. Ceremony-drive invocation repetition
Plans #1, #9, #10, and predecessors repeatedly describe the same ceremony process: "ONE certificate ceremony via scripts/ceremony-drive (fresh /tmp store; pre-flight candidates against the public-content gate first...)" with kernel `make test` green. This exact operational detail is repeated 10+ times across different plans. **Proposal:** Step descriptions reference `ceremony-drive` by name only; the operator-facing execution contract (fresh store, public-content gate, no src/ files) lives in README or a runbook.

## Ordering Conflicts

Accepted plans whose steps touch the same file — would conflict if run in parallel beats.

### `automation/dashboard/plans.json` — 4 plans write here
| Plans | What they do to it |
|-------|-------------------|
| #7 (automation-schedule-optimization) S1 | Read plans.json to mirror parked count; update parked set after sweep |
| #8 (omp-hngh-integration) S3/S10 | S3: plan-status subcommand reads plans.json for status emission; S10: extend it with queue+accepted plans+last ceremony commit |
| #19 (stall-recovery-and-operator-surfaces) S6 | dashboard-server.py serves system.json; peers parser fix touches system JSON parsing pipeline |
| #20 (work-graph-visualization) S1 | Extend plan-feed.py to emit steps arrays and edges list INTO plans.json alongside existing summary fields |

Conflict risk: medium. S1 (sweep) modifies parked count. S10 (extend) adds new fields. S1 (work-graph) appends structured data. If three parallel slots hit this simultaneously the JSON could be corrupted. Serialization already proposed in automation-schedule-optimization S5.

### `scripts/generate-publication` — 3 plans exercise this script
| Plans | What they modify/consume |
|-------|-------------------------|
| #1 (staging) S5 | Runs --site mode into temp dir; records gap inventory |
| #9 (overnight-continuity) S2 | Implements per-book metadata input (title/author/identifier/keywords), runs --ebook mode |
| #10 (presentation-pass-1) S4 | Extends ebook mode to include 2026-09-09 records in spine, regenerates book.md + EPUB |

Conflict risk: low-to-medium. Same binary, different modes (--site vs --ebook). But if overnight-continuity S2 is implementing the metadata input change while presentation-pass-1 S4 depends on that change for record inclusion, order matters. S2 before S4.

### `dashboard/*.js` — 2 plans touch dashboard JS
| Plans | What they do |
|-------|-------------|
| #19 (stall-recovery) S5 | Add spawn form, tile button, flag control to served dashboard (zero served-JS callers currently) |
| #20 (work-graph-visualization) S2 | Gantt upgrade: step rows, sub-bars, blocked-by edges, park-cause chips |

Conflict risk: medium. Both modify dashboard UI rendering. S5 adds controls; S2 upgrades gantt rendering. Shared DOM surface risks collisions if applied simultaneously.

### `dashboard-server.py` — 2 plans modify server
| Plans | What they do |
|-------|-------------|
| #19 (stall-recovery) S6 | Require shared token on POST endpoints (or bind non-GET to tailscale); fix peers parser; add uptime field |
| #20 (work-graph-visualization) S2 | Gantt HTML page rendered by the server |

Conflict risk: low. S6 modifies auth and data feed; S2 adds page rendering. Different code paths.

### `automation/scripts/overnight-cycle.sh` — 3 plans modify this core orchestrator
| Plans | What they modify |
|-------|-----------------|
| #7 (automation-schedule-optimization) S2 | Add priority=high front-matter sort to slot-0 selection |
| #19 (stall-recovery) S7/S9 | S7: trap SIGTERM/SIGINT for graceful shutdown; move failfirst state out of /tmp; S9: implement quota model routing in select_model path |
| #19 (stall-recovery) S10 | Route review/digest lane through lib/model.sh quota ladder |

Conflict risk: HIGH. All three touch the central orchestrator. #7 changes slot-0 selection. #19 S7 changes trap/shutdown behavior. #19 S9/S10 change model selection logic. These CANNOT safely land in the same beat without coordinating. Must serialize in order: #7 S2 first (selector change), then #19 S9 (model routing), then #19 S7 (lifecycle traps).

### `lib/model.sh` — 2 plans touch model selection
| Plans | What they modify |
|-------|-----------------|
| #19 (stall-recovery) S9/S10 | S9: read session-model-preference cadence param row in select_model; S10: route review/digest through quota ladder |
| #7 (automation-schedule-optimization) S4 | Throughput evidence review measures degraded-session rate at each FF_SPEED tier |

Conflict risk: medium. #19 actually writes model routing; #7 measures its impact. #4 can read #9's work but does not write it. Safe if #9 lands before #4 executes.

### `failfirst` state (`/tmp/hngh-failfirst` vs `automation/state/`) — 2 plans
| Plans | What they do |
|-------|-------------|
| #19 (stall-recovery) S7 | Move failfirst state from /tmp to persistent path |
| #19 (stall-recovery) S1 | launch-session.sh uses failfirst state for bad-execution counting |

Same plan internally: S7 must land before S1 becomes effective, but both are in the same plan so ordering is guaranteed. External risk: if another session still reads from /tmp during transition.

### `CHANGELOG.md` — 4 plans add entries
| Plans | What they add |
|-------|--------------|
| #8 (omp-hngh-integration) S11 | CHANGELOG entry for omp integration |
| #10 (presentation-pass-1) S5 | CHANGELOG entry for presentation pass |
| #20 (work-graph-visualization) S4 | CHANGELOG entry for work-graph feed |
| #9 (overnight-continuity) S5 | Lessons/journal updates ride in nightly cycle |

Conflict risk: low. CHANGELOG is append-only; git handles multiple concurrent appends cleanly.

### `docs/project/plans/README.md` — 2 plans document into it
| Plans | What they do |
|-------|-------------|
| #7 (automation-schedule-optimization) S2 | Document priority=high key under Contract section |
| #8 (omp-hngh-integration) S11 | Update README only if propose surface gained new behavior |

Conflict risk: low. Sequential operations on same doc. No hazard unless both try to edit concurrently.

### `docs/research/` directory — 4 plans author new research documents
| Plans | Documents created |
|-------|------------------|
| #1 (staging) S2/S4 | bench-probe-calibration.md, unsloth-recovery-local-lane.md |
| #9 (overnight-continuity) S3 | ctx-structured-briefs.md (+ rewrite of ctx-retrieval-vs-repetition.md) |
| #19 (stall-recovery) S1/S4 | model-outcome-demotion doc, notification-send-path proof |
| #20 (work-graph-visualization) S3 | Story view skeleton consuming work graph |

Conflict risk: low. Each creates a distinct file. No overlap in filenames.
