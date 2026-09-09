slug: outcome-demotion-at-two-consecutive-failures
title: Consecutive bad-execution cancellation count gates model retention in session routing
category: devops

A session launcher demotes a model after two consecutive `bad-execution` cancellations on the same identity, advancing to the next model in the bench ladder. The pattern observed 2026-09-09: nine sessions each burned a full 8/day budget cap via unsloth/Ornith-1.0-35B (`rc=0 cancelled cause=bad-execution`) before any demotion fired because failfirst state never tracked per-model counters. The counter resets on success. This mechanism replaces the previous blind-ladder approach where burn capped total spend without discriminating which model was at fault.

context: docs/records/2026-09-09-stall-recovery-and-operator-surfaces.plan.md; automation/lib/launch-session.sh

---

slug: session-budget-burn-prevents-discretionary-plan-selection
title: Bad-execution burn exhausts session budgets and starves the queue of execution capacity
category: devops

When a single model produces repeated `bad-execution` cancellations, it consumes discrete session budget slots (default 8/day, raised to 200 temporarily during operator sweep). Without outcome demotion, every slot becomes dead time — no plans execute between failures, the queue grows, and the overnight cycle cannot reach any work. The stall recovery plan documented nine failed sessions burning through an entire day's worth of slots in a single hour. Outcome demotion prevents future instances of this cascade.

context: docs/records/2026-09-09-stall-recovery-and-operator-surfaces.plan.md; docs/research/2026-09-09-backlog-disposition-sweep.md

---

slug: backlog-disposition-sweep-reduces-accepted-plans-by-half
title: Evidence-gated disposition sweep classifies accepted plans as live/duplicate/obsolete to shrink the selector workload
category: process

A five-review classification sweep reduced accepted plan count from 67 to 28 live, parking 24 as duplicate and 16 as obsolete. The method uses alert history, automation/research-dispositions.tsv, git log evidence, cross-references from other plans, and dashboard plans.json state to justify each verdict. Duplicate patterns emerged around tree-skew alerts (one identity producing ~10 daily routed copies), system-network-down (same flag, same investigation), and gate-check-automation (redundant verification tasks). Obsolete patterns included stale ux-reviews, torch-artifact-class findings, and pre-ceremony review P1s whose underlying scripts now exist. Each parked plan gets `cause=` inline reasoning in its front-matter comment.

context: docs/research/2026-09-09-backlog-disposition-sweep.md; automation/scripts/overnight-cycle.sh

---

slug: high-risk-file-collision-in-nightly-cycle-orchestrator
title: Three plans writing overnight-cycle.sh cannot safely land in same beat — serialization required
category: devops

The file automation/scripts/overnight-cycle.sh is a shared orchestrator touched by three concurrent plan steps: (1) priority=high front-matter sort added to slot-0 selection, (2) trap handlers for graceful SIGTERM/SIGINT shutdown plus failfirst state migration out of /tmp, and (3) quota-model routing hook into select_model. All three are independent changes but share the same file; applying two or more in parallel risks corrupting the script control flow. The queue-dependency-inventory identified this as HIGH-risk and prescribed serialization order: selector change first, model routing second, lifecycle traps last. Files with append-only semantics like CHANGELOG.md are safe, while shared orchestrators (overnight-cycle.sh) and mutable JSON data files (dashboard/plans.json) create real collision hazards when applied simultaneously.

context: docs/design/work-visualization-direction.md; docs/research/2026-09-09-queue-dependency-inventory.md

---

slug: rehearsal-dream-runs-governance-loop-without-mutation
title: Rehearsal beats run full governance loop on scratch stores without executing mutation-check
category: architecture

A rehearsal beat creates runs on tmp-stores, proposes against ten-principle evaluator, issues prepare-candidate certificates, and runs make test in isolated git-archive tree. It stops before mutation-check which would commit real repository changes. Dreams file evidence rows with refusal text quoted verbatim but never write to real stores, never mutate plans, never start daemons. Invariant: a rehearsal verdict is never treated as certificate — future actions still pay full price at the real gate. Boundary keeps kernel side-effect-free via outer automation glue only.

context: docs/design/rehearsal-and-self-order.md; scripts/ceremony-drive; lib/hngh-record.sh

---

slug: voice-rules-as-binding-constraint-not-aesthetic-preference
title: No-exclamation-mark rule and no-marketing-register constraint govern all public documentation surfaces
category: design

Presentation direction codifies binding rules for all hngh public text: no exclamation marks anywhere in documentation; no marketing register where any sentence that could appear on cloud product landing page must be deleted and replaced with what thing actually does; wit lives in precision not jokes. Flavor references appear as texture — epigraphs, section spines, names — never cosplay. Rules apply uniformly across README, docs/README, architecture.md, plan files, CHANGELOG.md, and all publication surfaces (book.md, EPUB). Enforces single-author voice where dry observation replaces cheerleading and accuracy is only source of humor.

context: docs/design/presentation-direction.md; docs/project/plans/README.md

---

slug: mid-line-verification-block-triggers-long-acceptance-pending
title: Acceptance block stuck 12 hours because Verification line was embedded mid-line instead of own paragraph
category: process

Plan step Verification field formatted inline after step description rather than on dedicated indented line beneath it. Automated router tick validating plan front-matter requires Verification on its own indented line; when embedded mid-line validator reports step-no-verification and plan remains stuck in pending-acceptance state. Produced 12-hour stall where work understood and approved by operator but blocked from selector execution by formatting convention mismatch. Fix: every step must carry separate indented Verification line immediately after body.

context: docs/project/plans/README.md; automation/scripts/overnight-cycle.sh

---

slug: timezone-local-vs-utc-rendering-fabricates-missing-commits
title: Git dates displayed in local time rather than UTC create false missing-commit signals
category: bugfix

When git client or dashboard renders committed timestamps in local time zones while reference material uses UTC ISO format resulting display shows missing or future commits relative to other tools interpretation. False signal triggers phantom investigation cycles where sessions search for commits already there misread because one tool rendered wall-clock time and another showed epoch-based UTC. Fix is standardize on UTC for all machine-facing timestamps and document convention in autonomy rules. Honesty rules forbid fabricated status.

context: docs/project/backlog.md; docs/design/interface-grading.md; docs/design/command-center.md


Total lessons: 8
