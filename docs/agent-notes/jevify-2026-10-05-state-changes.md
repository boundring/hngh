# jevify - state-change audit (2026-10-05)

What was judged: Hngh's own state changes - the git commits of
2026-10-01..2026-10-05, the delta the loop wrote while the loop itself was
being built. Every commit is a choice the machine made about itself; this
run asks which of those choices carry knowledge worth keeping.

Rubric: frozen BEFORE data. Unit = one commit. Deterministic prefilter
removed 58 mechanical ledger-sync/counter-tick commits before any judging.
107 judged, 0 failures, 0 truncations. Bulk classification:
typesafe/jev-1.13.0 via judge_batch (job jdgb-1599d5f56e1586bd).
Rows marked **[override]**: model verdict contradicted diff evidence;
evidence wins per convention (see jevify-2026-10-03-subsystems.md).

Rubric restated:

- signal: operational-lesson | failure-cause | design-pressure |
  trajectory | housekeeping | other
- route: lesson-harvest | research-lines | cause-routing | metrics-only |
  none | other
- meta_value: 0-4 (0 = nothing learnable ... 4 = would change the loop
  itself)

Counts (107 judged):

- signal: operational-lesson 40, housekeeping 28, failure-cause 19,
  trajectory 12, design-pressure 8
- route: lesson-harvest 26, research-lines 25, metrics-only 20,
  cause-routing 13, none 12, other 11
- meta_value: mean 1.33; rounded dist 0:24, 1:38, 2:32, 3:13

## Verdict table

The 13 top-band rows (meta_value >= 2.5, the rounded-3 band) plus the 5
lowest-p knowledge-signal escalations (the escalated list held 55 rows;
these five carry the weakest signal confidence). Evidence lines come from
the diffs.

| commit | subject | signal (p) | route | meta_value | evidence |
|--------|---------|-----------|-------|-----------|----------|
| 275761f9 | automation: date-blind research-lane dedup; hermetic identity state everywhere | operational-lesson (0.53) | lesson-harvest | 3.13 | date-blind id-prefix dedup lands in lib/causes.sh; patrol.py, lib/report_queue.py, scripts/accept-plans.py all go hermetic; seven test files updated |
| 721bf926 | automation: review-prep scopes per-subtree commits, kills duplicate hngh/hngh-automation evidence | operational-lesson (0.53) | lesson-harvest | 2.99 | 04-review-prep.sh scopes per subtree; new tests/test-review-prep-sections.sh (113 lines) |
| 15637fd8 | automation: lesson harvest writes repo-relative guardrails path | operational-lesson (0.63) | lesson-harvest | 2.96 | one-line fix in 01-lesson-harvest.sh (1+/1-); the guardrails pointer stopped being machine-absolute |
| db6fb5b0 | automation: ux-review allows sanctioned typographic punctuation | operational-lesson (0.83) | lesson-harvest | 2.92 | 19-ux-review.sh admits sanctioned punctuation; new 90-line allowlist test |
| 8be256ed | automation: ledger prune splits alert horizon to 14d; self-heals report cursor | failure-cause (0.68) | cause-routing | 2.90 | 02-ledger-prune.sh splits alert horizon and self-heals the cursor; new test-ledger-prune-cursor.sh (77 lines) |
| 61dd68cb | automation: dash-selfreview index.html marker follows the real front page - failing-first PAGE_MARKERS regression test | failure-cause (0.63) | cause-routing | 2.90 | jobs/dashboard-self-review.py marker set follows the front-page rename; regression test lands failing-first |
| 886701a9 | automation: supervision never tracks harness __advisor side-transcripts | failure-cause (0.66) | cause-routing | 2.89 | jobs/agent-supervision.py excludes harness __advisor side-transcripts (7 lines + 37-line test) |
| 6d060966 | automation: router binds inert accepted carriers; park silences the source identity | operational-lesson (0.53) | cause-routing | 2.89 | scripts/router-tick.py binds inert accepted carriers; lib/report_queue.py park silences the source identity |
| a4b49be7 | dash-selfreview: reconcile ledger-sanity - archive files off the body glob, 451 orphaned bodies pruned | operational-lesson (0.62) | cause-routing | 2.87 | jobs/dashboard-self-review.py ledger check takes archive files off the body glob; 451 orphaned bodies pruned |
| 3b67094a | automation: unblock subhour tick and teach self-review recovery | operational-lesson (0.53) | lesson-harvest | 2.69 | subhour/50-research-overflow.sh unblocked; self-review learns recovery; new heartbeat test (125 lines) |
| d97cb79a | automation: digest mark loop walks oldest-first (mark_read overwrite watermark) | operational-lesson (0.88) | lesson-harvest | 2.66 | subhour/57-digest-send.sh mark loop walks oldest-first so mark_read stops overwriting the watermark |
| 557ba29f | automation: fail unsloth context pins closed and clamp to registry windows | failure-cause (0.51) | cause-routing | 2.66 | lib/model.sh fails unsloth context pins closed, clamps to registry windows; new test-unsloth-context-guard.sh |
| 50ee002c | automation: digest delivery auto-reads progress rows; wake context counts alerts | operational-lesson (0.95) | cause-routing | 2.51 | subhour/57-digest-send.sh auto-reads progress rows; overnight-cycle.sh wake context counts alerts |
| **d28e0ab1 [override]** | research: fail-20261002-Does-the-tree-skew-detection-code-exclud reviewed-parked | failure-cause (0.38) | research-lines | 0.60 | diff only adds a research-dispositions.tsv row and flips research-lines.tsv crystallized -> reviewed: research-loop bookkeeping, no failure semantics |
| **af2c08dc [override]** | automation: dashboard verdict override unified in verdictof - camp and header share one computation | design-pressure (0.40) | other | 2.04 | diff moves the open-items override into verdictOf (dashboard/app.js) so Camp and header share one computation, plus a p0 regression test: a trajectory refactor |
| 62cd0e30 | automation: control-room map actually renders - renderer stored on state, opaque scene, resize observer, queue_depth key | operational-lesson (0.41) | none | 1.40 | dashboard/map.js 8-line diff (renderer on state, opaque scene, resize observer) + 3 test lines |
| f05f1fdf | docs: dashboard deficiency tranche recorded - eight slices, evidence, scope | operational-lesson (0.41) | cause-routing | 0.74 | docs/records/2026-10-03-dashboard-deficiency-tranche.md (78 lines) + CHANGELOG row; no code changed |
| e306830d | docs: research corpus seeded - 12 evidence-anchored lanes, jevify verdicts landed | operational-lesson (0.42) | research-lines | 1.16 | seeds docs/research/01..12 lanes and two jevify notes; also the commit that `git rm`'d automation/--model (subsystems note row 17) |

## Overrides

- d28e0ab1: model said failure-cause (p=0.38); the diff is research-loop
  bookkeeping - one disposition row plus a state flip in
  research-lines.tsv. Corrected to research/metrics routing. The judge
  saw a "reviewed-parked" verdict and read failure into it; the diff
  contains no failure.
- af2c08dc: model said design-pressure (p=0.40); the diff is a trajectory
  refactor - one verdict computation instead of two, behavior unified on
  purpose. Corrected to trajectory.

## What the distribution says

40 of 107 commits are operational lessons - more than housekeeping (28)
and failure-cause (19) combined would need to be to catch up. Hngh's
learning signal lives in the day-to-day repairs, not in its ledgers:
the highest meta_value scores are all small hygiene fixes with wide blast
radius (dedup, watermarks, identity state), and the failure-cause rows
route to cause-routing already. The lesson-harvest seam - the place where
handoff rows become guardrails - is therefore worth more attention than
any new ledger. One caveat against over-reading: signal confidence is
weak across the board (55 of 107 escalated; 29 with p < 0.5), so this
note's own verdicts are evidence to check, not facts to file.
